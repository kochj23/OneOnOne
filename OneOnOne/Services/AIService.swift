//
//  AIService.swift
//  OneOnOne
//
//  AI service for generating insights, summaries, and reminders
//  Uses local MLX models via Python daemon
//  Created by Jordan Koch on 2026-02-02.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation

#if os(macOS)
/// AI-powered insights and suggestions service (macOS only - requires Python/MLX)
actor AIService {
    static let shared = AIService()

    // MARK: - Properties

    private var daemonProcess: Process?
    private var inputPipe: Pipe?
    private var outputPipe: Pipe?
    private var isDaemonRunning = false
    private var loadedModelPath: String?

    // Default model path (can be configured)
    private let defaultModelPath = "~/.mlx/models/Llama-3.2-3B-Instruct-4bit"

    private init() {}

    // MARK: - Daemon Management

    /// Starts the AI daemon process
    func startDaemon() async throws {
        guard !isDaemonRunning else { return }

        // Get daemon script path
        guard let scriptPath = getDaemonScriptPath() else {
            throw AIServiceError.daemonNotFound
        }

        let process = Process()
        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        // Use Xcode's Python
        let pythonPath = "/Applications/Xcode.app/Contents/Developer/Library/Frameworks/Python3.framework/Versions/3.9/bin/python3.9"

        guard FileManager.default.fileExists(atPath: pythonPath) else {
            throw AIServiceError.pythonNotFound
        }

        process.executableURL = URL(fileURLWithPath: pythonPath)
        process.arguments = [scriptPath]
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        // Set PYTHONPATH for user packages
        var env = ProcessInfo.processInfo.environment
        let userSitePackages = "/Users/\(NSUserName())/Library/Python/3.9/lib/python/site-packages"
        env["PYTHONPATH"] = userSitePackages
        process.environment = env
        process.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser

        self.daemonProcess = process
        self.inputPipe = inputPipe
        self.outputPipe = outputPipe

        try process.run()

        // Wait for ready signal
        let response = try await readResponse()
        guard response["type"] as? String == "ready" else {
            throw AIServiceError.daemonStartFailed
        }

        isDaemonRunning = true
        print("AI daemon started successfully")
    }

    /// Stops the AI daemon
    func stopDaemon() async {
        guard let process = daemonProcess, process.isRunning else { return }

        // Send shutdown command
        try? await sendCommand(["type": "shutdown"])

        try? await Task.sleep(nanoseconds: 500_000_000)

        if process.isRunning {
            process.terminate()
        }

        daemonProcess = nil
        inputPipe = nil
        outputPipe = nil
        isDaemonRunning = false
        loadedModelPath = nil
    }

    /// Loads an AI model
    func loadModel(path: String? = nil) async throws {
        let modelPath = path ?? defaultModelPath
        let expandedPath = (modelPath as NSString).expandingTildeInPath

        // Check if already loaded
        if loadedModelPath == expandedPath {
            return
        }

        if !isDaemonRunning {
            try await startDaemon()
        }

        try await sendCommand([
            "type": "load_model",
            "model_path": expandedPath
        ])

        // Wait for load response
        while true {
            let response = try await readResponse()
            if response["type"] as? String == "debug" {
                continue
            }
            if response["success"] as? Bool == true {
                loadedModelPath = expandedPath
                print("AI model loaded: \(expandedPath)")
                return
            } else {
                throw AIServiceError.modelLoadFailed(response["error"] as? String ?? "Unknown error")
            }
        }
    }

    // MARK: - AI Features

    /// Generates a meeting summary from notes
    func generateMeetingSummary(notes: String, attendees: [String]) async throws -> String {
        try await loadModel()

        let prompt = """
        You are a helpful assistant that summarizes meeting notes concisely.

        Meeting attendees: \(attendees.joined(separator: ", "))

        Meeting notes:
        \(notes)

        Please provide a brief summary (2-3 paragraphs) of the key points discussed, decisions made, and action items identified.

        Summary:
        """

        return try await generate(prompt: prompt)
    }

    /// Extracts action items from meeting notes
    func extractActionItems(from notes: String) async throws -> [String] {
        try await loadModel()

        let prompt = """
        You are a helpful assistant that identifies action items from meeting notes.

        Meeting notes:
        \(notes)

        Please list all action items mentioned or implied in these notes. Format each action item on its own line starting with "- ".

        Action items:
        """

        let response = try await generate(prompt: prompt)

        // Parse action items from response
        return response
            .components(separatedBy: "\n")
            .filter { $0.hasPrefix("- ") || $0.hasPrefix("* ") }
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "-* ")) }
    }

    /// Generates conversation starters based on history
    func suggestConversationTopics(for person: Person, recentMeetings: [Meeting]) async throws -> [String] {
        try await loadModel()

        let meetingContext = recentMeetings.prefix(3).map { meeting in
            "- \(meeting.date.formatted(date: .abbreviated, time: .omitted)): \(meeting.title)"
        }.joined(separator: "\n")

        let prompt = """
        You are a helpful assistant preparing for a 1:1 meeting.

        Person: \(person.name)
        Title: \(person.title ?? "Unknown")

        Recent meetings:
        \(meetingContext)

        Suggest 3-5 conversation topics or questions to ask in the next 1:1. Consider:
        - Following up on previous discussions
        - Career development
        - Current challenges
        - Wins and recognition

        Format each suggestion on its own line starting with "- ".

        Suggestions:
        """

        let response = try await generate(prompt: prompt)

        return response
            .components(separatedBy: "\n")
            .filter { $0.hasPrefix("- ") || $0.hasPrefix("* ") }
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "-* ")) }
    }

    /// Generates a weekly recap of meetings and action items
    func generateWeeklyRecap(meetings: [Meeting], openActionItems: [ActionItem]) async throws -> String {
        try await loadModel()

        let meetingList = meetings.map { meeting in
            "- \(meeting.date.formatted(date: .abbreviated, time: .shortened)): \(meeting.title) (\(meeting.meetingType.rawValue))"
        }.joined(separator: "\n")

        let actionList = openActionItems.prefix(10).map { item in
            "- \(item.title) [\(item.priority.rawValue)]"
        }.joined(separator: "\n")

        let prompt = """
        You are a helpful assistant creating a weekly recap.

        Meetings this week:
        \(meetingList)

        Open action items:
        \(actionList)

        Please provide a brief weekly recap including:
        1. Summary of meetings held
        2. Key themes or topics discussed
        3. Priority action items to focus on
        4. Any patterns or insights noticed

        Weekly Recap:
        """

        return try await generate(prompt: prompt)
    }

    /// Suggests follow-up questions based on meeting notes
    func suggestFollowUps(meetingNotes: String) async throws -> [String] {
        try await loadModel()

        let prompt = """
        You are a helpful assistant identifying follow-up items from meeting notes.

        Meeting notes:
        \(meetingNotes)

        List topics or questions that should be followed up on in a future meeting. Format each on its own line starting with "- ".

        Follow-ups:
        """

        let response = try await generate(prompt: prompt)

        return response
            .components(separatedBy: "\n")
            .filter { $0.hasPrefix("- ") || $0.hasPrefix("* ") }
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "-* ")) }
    }

    /// Analyzes goal progress and provides recommendations
    func analyzeGoalProgress(goal: Goal, relatedMeetings: [Meeting]) async throws -> String {
        try await loadModel()

        let milestoneStatus = goal.milestones.map { milestone in
            "- \(milestone.title): \(milestone.isCompleted ? "Complete" : "Pending")"
        }.joined(separator: "\n")

        let prompt = """
        You are a helpful assistant analyzing goal progress.

        Goal: \(goal.title)
        Description: \(goal.description ?? "No description")
        Category: \(goal.category.rawValue)
        Status: \(goal.status.rawValue)
        Progress: \(Int(goal.progress * 100))%

        Milestones:
        \(milestoneStatus)

        Discussed in \(relatedMeetings.count) meetings.

        Please provide:
        1. Assessment of current progress
        2. Potential blockers or risks
        3. Recommendations for next steps
        4. Suggested timeline adjustments if needed

        Analysis:
        """

        return try await generate(prompt: prompt)
    }

    // MARK: - Private Methods

    private func generate(prompt: String, maxTokens: Int = 1024) async throws -> String {
        try await sendCommand([
            "type": "generate",
            "prompt": prompt,
            "max_tokens": maxTokens,
            "temperature": 0.7
        ])

        var fullResponse = ""

        while true {
            let response = try await readResponse()
            let type = response["type"] as? String

            if type == "token", let token = response["token"] as? String {
                fullResponse += token
            } else if type == "complete" || type == "done" {
                break
            } else if let error = response["error"] as? String {
                throw AIServiceError.generationFailed(error)
            }
        }

        return fullResponse.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func sendCommand(_ command: [String: Any]) async throws {
        guard let inputPipe = inputPipe else {
            throw AIServiceError.daemonNotRunning
        }

        let jsonData = try JSONSerialization.data(withJSONObject: command)
        var commandString = String(data: jsonData, encoding: .utf8) ?? ""
        commandString += "\n"

        guard let data = commandString.data(using: .utf8) else {
            throw AIServiceError.encodingFailed
        }

        inputPipe.fileHandleForWriting.write(data)
    }

    private func readResponse() async throws -> [String: Any] {
        guard let outputPipe = outputPipe else {
            throw AIServiceError.daemonNotRunning
        }

        let handle = outputPipe.fileHandleForReading
        var line = Data()

        while true {
            let byte = handle.readData(ofLength: 1)
            if byte.isEmpty {
                throw AIServiceError.daemonClosed
            }
            if byte.first == UInt8(ascii: "\n") {
                break
            }
            line.append(byte)
        }

        guard let json = try JSONSerialization.jsonObject(with: line) as? [String: Any] else {
            throw AIServiceError.invalidResponse
        }

        return json
    }

    private func getDaemonScriptPath() -> String? {
        // Try bundle first
        if let bundlePath = Bundle.main.path(forResource: "ai_daemon", ofType: "py") {
            return bundlePath
        }

        // Fall back to development path
        let devPath = "/Volumes/Data/xcode/OneOnOne/Python/ai_daemon.py"
        if FileManager.default.fileExists(atPath: devPath) {
            return devPath
        }

        return nil
    }
}

// MARK: - Errors

enum AIServiceError: LocalizedError {
    case daemonNotFound
    case daemonNotRunning
    case daemonStartFailed
    case daemonClosed
    case pythonNotFound
    case modelLoadFailed(String)
    case generationFailed(String)
    case encodingFailed
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .daemonNotFound:
            return "AI daemon script not found"
        case .daemonNotRunning:
            return "AI daemon is not running"
        case .daemonStartFailed:
            return "Failed to start AI daemon"
        case .daemonClosed:
            return "AI daemon closed unexpectedly"
        case .pythonNotFound:
            return "Python 3.9 not found"
        case .modelLoadFailed(let error):
            return "Failed to load AI model: \(error)"
        case .generationFailed(let error):
            return "AI generation failed: \(error)"
        case .encodingFailed:
            return "Failed to encode command"
        case .invalidResponse:
            return "Invalid response from AI daemon"
        }
    }
}
#endif  // os(macOS)
