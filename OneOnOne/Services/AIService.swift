//
//  AIService.swift
//  OneOnOne
//
//  AI service for generating insights, summaries, and reminders
//  Supports multiple backends: Ollama, OpenWebUI, MLX Toolkit, TinyChat
//
//  Created by Jordan Koch on 2026-02-02.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//
//  THIRD-PARTY INTEGRATIONS:
//  - TinyChat by Jason Cox (https://github.com/jasonacox/tinychat)
//  - OpenWebUI Community (https://github.com/open-webui/open-webui)
//

import Foundation
import SwiftUI

/// AI-powered insights and suggestions service with multi-backend support
@MainActor
class AIService: ObservableObject {
    static let shared = AIService()

    // MARK: - Published Properties

    @Published var isProcessing = false
    @Published var selectedProvider: AIProvider = .ollama
    @Published var lastError: String?

    // Backend availability
    @Published var isOllamaAvailable = false
    @Published var isOpenWebUIAvailable = false
    @Published var isMLXAvailable = false
    @Published var isTinyChatAvailable = false

    // MARK: - Configuration

    @Published var ollamaEndpoint = "http://localhost:11434"
    @Published var ollamaModel = "llama3.2"
    @Published var openWebUIEndpoint = "http://localhost:3000"
    @Published var openWebUIModel = "llama3.2"
    @Published var mlxEndpoint = "http://localhost:8800"
    @Published var mlxModel = "mlx-community/Llama-3.2-3B-Instruct-4bit"
    @Published var tinyChatEndpoint = "http://localhost:8000"

    // MARK: - MLX Daemon (for local MLX inference)

    #if os(macOS)
    private var daemonProcess: Process?
    private var inputPipe: Pipe?
    private var outputPipe: Pipe?
    private var isDaemonRunning = false
    #endif

    // MARK: - Initialization

    private init() {
        loadConfiguration()
        Task {
            await checkBackendAvailability()
        }
    }

    // MARK: - Backend Availability

    func checkBackendAvailability() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.checkOllama() }
            group.addTask { await self.checkOpenWebUI() }
            group.addTask { await self.checkMLX() }
            group.addTask { await self.checkTinyChat() }
        }

        // Auto-select first available provider
        if !isProviderAvailable(selectedProvider) {
            if isOllamaAvailable {
                selectedProvider = .ollama
            } else if isOpenWebUIAvailable {
                selectedProvider = .openWebUI
            } else if isMLXAvailable {
                selectedProvider = .mlxToolkit
            } else if isTinyChatAvailable {
                selectedProvider = .tinyChat
            }
        }
    }

    func isProviderAvailable(_ provider: AIProvider) -> Bool {
        switch provider {
        case .ollama: return isOllamaAvailable
        case .openWebUI: return isOpenWebUIAvailable
        case .mlxToolkit: return isMLXAvailable
        case .tinyChat: return isTinyChatAvailable
        }
    }

    private func checkOllama() async {
        guard let url = URL(string: "\(ollamaEndpoint)/api/tags") else {
            isOllamaAvailable = false
            return
        }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 5
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                isOllamaAvailable = false
                return
            }

            // Verify the configured model is available
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let models = json["models"] as? [[String: Any]] {
                let modelNames = models.compactMap { $0["name"] as? String }
                let configuredModel = ollamaModel.lowercased()
                let modelFound = modelNames.contains { name in
                    let lower = name.lowercased()
                    return lower == configuredModel || lower.hasPrefix(configuredModel + ":")
                }
                if !modelFound {
                    print("AIService: Ollama available but model '\(ollamaModel)' not found. Available: \(modelNames.joined(separator: ", "))")
                }
            }

            isOllamaAvailable = true
        } catch {
            isOllamaAvailable = false
        }
    }

    private func checkOpenWebUI() async {
        guard let url = URL(string: "\(openWebUIEndpoint)/api/models") else {
            isOpenWebUIAvailable = false
            return
        }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 5
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                // 401/403 means OpenWebUI is running but requires auth — still available
                let reachable = (200...299).contains(httpResponse.statusCode)
                    || httpResponse.statusCode == 401
                    || httpResponse.statusCode == 403
                isOpenWebUIAvailable = reachable
            } else {
                isOpenWebUIAvailable = false
            }
        } catch {
            isOpenWebUIAvailable = false
        }
    }

    private func checkMLX() async {
        // Check if MLX HTTP server is running
        guard let url = URL(string: "\(mlxEndpoint)/v1/models") else {
            isMLXAvailable = false
            return
        }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 5
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse,
               (200...299).contains(httpResponse.statusCode) {
                isMLXAvailable = true
            } else {
                isMLXAvailable = false
            }
        } catch {
            isMLXAvailable = false
        }
    }

    private func checkTinyChat() async {
        // TinyChat serves a web UI at root and may use /v1/models or just /
        // Try /v1/models first, then fall back to root
        let endpoints = ["\(tinyChatEndpoint)/v1/models", tinyChatEndpoint]

        for endpoint in endpoints {
            guard let url = URL(string: endpoint) else { continue }

            do {
                var request = URLRequest(url: url)
                request.timeoutInterval = 5
                let (_, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse,
                   (200...499).contains(httpResponse.statusCode) {
                    // Any non-connection-error response means the service is running
                    isTinyChatAvailable = true
                    return
                }
            } catch {
                continue
            }
        }

        isTinyChatAvailable = false
    }

    // MARK: - AI Features

    /// Generates a meeting summary from notes
    func generateMeetingSummary(notes: String, attendees: [String]) async throws -> String {
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
        let prompt = """
        You are a helpful assistant that identifies action items from meeting notes.

        Meeting notes:
        \(notes)

        Please list all action items mentioned or implied in these notes. Format each action item on its own line starting with "- ".

        Action items:
        """

        let response = try await generate(prompt: prompt)

        return response
            .components(separatedBy: "\n")
            .filter { $0.hasPrefix("- ") || $0.hasPrefix("* ") }
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "-* ")) }
    }

    /// Generates conversation starters based on history
    func suggestConversationTopics(for person: Person, recentMeetings: [Meeting]) async throws -> [String] {
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

    // MARK: - Core Generation

    private func generate(prompt: String, maxTokens: Int = 1024) async throws -> String {
        isProcessing = true
        lastError = nil

        defer { isProcessing = false }

        // Check if selected provider is available
        if !isProviderAvailable(selectedProvider) {
            // Try to find an available provider
            await checkBackendAvailability()

            if !isProviderAvailable(selectedProvider) {
                throw AIServiceError.noBackendAvailable
            }
        }

        do {
            switch selectedProvider {
            case .ollama:
                return try await callOllama(prompt: prompt, maxTokens: maxTokens)
            case .openWebUI:
                return try await callOpenWebUI(prompt: prompt, maxTokens: maxTokens)
            case .mlxToolkit:
                return try await callMLX(prompt: prompt, maxTokens: maxTokens)
            case .tinyChat:
                return try await callTinyChat(prompt: prompt, maxTokens: maxTokens)
            }
        } catch {
            lastError = error.localizedDescription
            throw error
        }
    }

    // MARK: - Ollama

    private func callOllama(prompt: String, maxTokens: Int) async throws -> String {
        guard let url = URL(string: "\(ollamaEndpoint)/api/generate") else {
            throw AIServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120

        let body: [String: Any] = [
            "model": ollamaModel,
            "prompt": prompt,
            "stream": false,
            "options": [
                "num_predict": maxTokens,
                "temperature": 0.7
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, httpResponse) = try await URLSession.shared.data(for: request)

        // Check HTTP status code
        if let http = httpResponse as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIServiceError.generationFailed("Ollama HTTP \(http.statusCode): \(String(body.prefix(200)))")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AIServiceError.invalidResponse
        }

        // Check for Ollama error responses (e.g. model not found)
        if let error = json["error"] as? String {
            throw AIServiceError.generationFailed("Ollama: \(error)")
        }

        guard let response = json["response"] as? String else {
            let keys = json.keys.joined(separator: ", ")
            throw AIServiceError.generationFailed("Ollama response missing 'response' field. Keys: \(keys)")
        }

        return response.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - OpenWebUI

    private func callOpenWebUI(prompt: String, maxTokens: Int) async throws -> String {
        guard let url = URL(string: "\(openWebUIEndpoint)/api/chat/completions") else {
            throw AIServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120

        let messages: [[String: String]] = [
            ["role": "system", "content": "You are a helpful assistant for managing 1:1 meetings and team relationships."],
            ["role": "user", "content": prompt]
        ]

        let body: [String: Any] = [
            "model": openWebUIModel,
            "messages": messages,
            "max_tokens": maxTokens,
            "temperature": 0.7,
            "stream": false
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)

        struct OpenWebUIResponse: Codable {
            struct Choice: Codable {
                struct Message: Codable {
                    let content: String
                }
                let message: Message
            }
            let choices: [Choice]
        }

        let response = try JSONDecoder().decode(OpenWebUIResponse.self, from: data)
        return response.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    // MARK: - MLX Toolkit

    private func callMLX(prompt: String, maxTokens: Int) async throws -> String {
        // MLX Toolkit exposes an OpenAI-compatible API
        guard let url = URL(string: "\(mlxEndpoint)/v1/chat/completions") else {
            throw AIServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120

        let messages: [[String: String]] = [
            ["role": "system", "content": "You are a helpful assistant for managing 1:1 meetings and team relationships."],
            ["role": "user", "content": prompt]
        ]

        let body: [String: Any] = [
            "model": mlxModel,
            "messages": messages,
            "max_tokens": maxTokens,
            "temperature": 0.7,
            "stream": false
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)

        struct MLXResponse: Codable {
            struct Choice: Codable {
                struct Message: Codable {
                    let content: String
                }
                let message: Message
            }
            let choices: [Choice]
        }

        let response = try JSONDecoder().decode(MLXResponse.self, from: data)
        return response.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    // MARK: - TinyChat
    // TinyChat by Jason Cox: https://github.com/jasonacox/tinychat

    private func callTinyChat(prompt: String, maxTokens: Int) async throws -> String {
        // TinyChat uses OpenAI-compatible API
        guard let url = URL(string: "\(tinyChatEndpoint)/v1/chat/completions") else {
            throw AIServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120

        let messages: [[String: String]] = [
            ["role": "system", "content": "You are a helpful assistant for managing 1:1 meetings and team relationships."],
            ["role": "user", "content": prompt]
        ]

        let body: [String: Any] = [
            "messages": messages,
            "max_tokens": maxTokens,
            "temperature": 0.7,
            "stream": false
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)

        struct TinyChatResponse: Codable {
            struct Choice: Codable {
                struct Message: Codable {
                    let content: String
                }
                let message: Message
            }
            let choices: [Choice]
        }

        let response = try JSONDecoder().decode(TinyChatResponse.self, from: data)
        return response.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    // MARK: - Configuration

    func loadConfiguration() {
        if let endpoint = UserDefaults.standard.string(forKey: "ollamaEndpoint") {
            ollamaEndpoint = endpoint
        }
        if let model = UserDefaults.standard.string(forKey: "ollamaModel") {
            ollamaModel = model
        }
        if let endpoint = UserDefaults.standard.string(forKey: "openWebUIEndpoint") {
            openWebUIEndpoint = endpoint
        }
        if let model = UserDefaults.standard.string(forKey: "openWebUIModel") {
            openWebUIModel = model
        }
        if let endpoint = UserDefaults.standard.string(forKey: "mlxEndpoint") {
            mlxEndpoint = endpoint
        }
        if let model = UserDefaults.standard.string(forKey: "mlxModel") {
            mlxModel = model
        }
        if let endpoint = UserDefaults.standard.string(forKey: "tinyChatEndpoint") {
            tinyChatEndpoint = endpoint
        }
        if let provider = UserDefaults.standard.string(forKey: "aiProvider"),
           let aiProvider = AIProvider(rawValue: provider) {
            selectedProvider = aiProvider
        }
    }

    func saveConfiguration() {
        UserDefaults.standard.set(ollamaEndpoint, forKey: "ollamaEndpoint")
        UserDefaults.standard.set(ollamaModel, forKey: "ollamaModel")
        UserDefaults.standard.set(openWebUIEndpoint, forKey: "openWebUIEndpoint")
        UserDefaults.standard.set(openWebUIModel, forKey: "openWebUIModel")
        UserDefaults.standard.set(mlxEndpoint, forKey: "mlxEndpoint")
        UserDefaults.standard.set(mlxModel, forKey: "mlxModel")
        UserDefaults.standard.set(tinyChatEndpoint, forKey: "tinyChatEndpoint")
        UserDefaults.standard.set(selectedProvider.rawValue, forKey: "aiProvider")
    }
}

// MARK: - AI Provider Enum

enum AIProvider: String, CaseIterable, Identifiable {
    case ollama = "Ollama"
    case openWebUI = "OpenWebUI"
    case mlxToolkit = "MLX Toolkit"
    case tinyChat = "TinyChat"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .ollama: return "server.rack"
        case .openWebUI: return "globe"
        case .mlxToolkit: return "cpu"
        case .tinyChat: return "bubble.left.and.bubble.right.fill"
        }
    }

    var description: String {
        switch self {
        case .ollama: return "Local Ollama server"
        case .openWebUI: return "OpenWebUI self-hosted platform"
        case .mlxToolkit: return "Apple MLX local inference"
        case .tinyChat: return "TinyChat by Jason Cox"
        }
    }

    var attribution: String? {
        switch self {
        case .tinyChat: return "https://github.com/jasonacox/tinychat"
        case .openWebUI: return "https://github.com/open-webui/open-webui"
        default: return nil
        }
    }
}

// MARK: - Errors

enum AIServiceError: LocalizedError {
    case invalidURL
    case invalidResponse
    case noBackendAvailable
    case generationFailed(String)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from AI service"
        case .noBackendAvailable:
            return "No AI backend available. Please configure Ollama, OpenWebUI, MLX Toolkit, or TinyChat."
        case .generationFailed(let message):
            return "AI generation failed: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Settings View

struct AISettingsView: View {
    @ObservedObject var aiService = AIService.shared
    @State private var isChecking = false
    @State private var ollamaModels: [String] = []
    @State private var isFetchingModels = false

    var body: some View {
        Form {
            Section(header: Text("AI Provider")) {
                Picker("Provider", selection: $aiService.selectedProvider) {
                    ForEach(AIProvider.allCases) { provider in
                        HStack {
                            Image(systemName: provider.icon)
                            Text(provider.rawValue)
                            if aiService.isProviderAvailable(provider) {
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                        .tag(provider)
                    }
                }
                .onChange(of: aiService.selectedProvider) { _, _ in
                    aiService.saveConfiguration()
                }

                Text(aiService.selectedProvider.description)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let attribution = aiService.selectedProvider.attribution {
                    Link(attribution, destination: URL(string: attribution)!)
                        .font(.caption2)
                }
            }

            Section(header: Text("Backend Status")) {
                StatusRow(name: "Ollama", icon: "server.rack", isAvailable: aiService.isOllamaAvailable)
                StatusRow(name: "OpenWebUI", icon: "globe", isAvailable: aiService.isOpenWebUIAvailable)
                StatusRow(name: "MLX Toolkit", icon: "cpu", isAvailable: aiService.isMLXAvailable)
                StatusRow(name: "TinyChat", icon: "bubble.left.and.bubble.right.fill", isAvailable: aiService.isTinyChatAvailable)

                Button("Refresh Status") {
                    isChecking = true
                    Task {
                        await aiService.checkBackendAvailability()
                        await fetchOllamaModels()
                        isChecking = false
                    }
                }
                .disabled(isChecking)
            }

            Section(header: Text("Ollama")) {
                TextField("Endpoint", text: $aiService.ollamaEndpoint)
                    .textContentType(.URL)

                if ollamaModels.isEmpty {
                    HStack {
                        TextField("Model", text: $aiService.ollamaModel)
                        Button {
                            Task { await fetchOllamaModels() }
                        } label: {
                            Image(systemName: isFetchingModels ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                        }
                        .buttonStyle(.plain)
                        .disabled(isFetchingModels)
                    }
                } else {
                    Picker("Model", selection: $aiService.ollamaModel) {
                        ForEach(ollamaModels, id: \.self) { model in
                            Text(model).tag(model)
                        }
                        // Include current model if not in list (e.g. manually typed)
                        if !ollamaModels.contains(aiService.ollamaModel) {
                            Text("\(aiService.ollamaModel) (not found)")
                                .foregroundColor(.red)
                                .tag(aiService.ollamaModel)
                        }
                    }

                    if !ollamaModels.contains(aiService.ollamaModel) {
                        Text("Model '\(aiService.ollamaModel)' is not installed in Ollama. Select an available model above.")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            .onChange(of: aiService.ollamaEndpoint) { _, _ in
                aiService.saveConfiguration()
                Task { await fetchOllamaModels() }
            }
            .onChange(of: aiService.ollamaModel) { _, _ in aiService.saveConfiguration() }

            Section(header: Text("OpenWebUI")) {
                TextField("Endpoint", text: $aiService.openWebUIEndpoint)
                    .textContentType(.URL)
                TextField("Model", text: $aiService.openWebUIModel)
            }
            .onChange(of: aiService.openWebUIEndpoint) { _, _ in aiService.saveConfiguration() }
            .onChange(of: aiService.openWebUIModel) { _, _ in aiService.saveConfiguration() }

            Section(header: Text("MLX Toolkit")) {
                TextField("Endpoint", text: $aiService.mlxEndpoint)
                    .textContentType(.URL)
                TextField("Model", text: $aiService.mlxModel)
            }
            .onChange(of: aiService.mlxEndpoint) { _, _ in aiService.saveConfiguration() }
            .onChange(of: aiService.mlxModel) { _, _ in aiService.saveConfiguration() }

            Section(header: Text("TinyChat")) {
                TextField("Endpoint", text: $aiService.tinyChatEndpoint)
                    .textContentType(.URL)
            }
            .onChange(of: aiService.tinyChatEndpoint) { _, _ in aiService.saveConfiguration() }

            Section(header: Text("Credits")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Third-Party Integrations:")
                        .font(.headline)

                    Link("TinyChat by Jason Cox", destination: URL(string: "https://github.com/jasonacox/tinychat")!)
                    Link("OpenWebUI Community", destination: URL(string: "https://github.com/open-webui/open-webui")!)
                }
                .font(.caption)
            }
        }
        #if os(macOS)
        .formStyle(.grouped)
        #endif
        .onAppear {
            Task { await fetchOllamaModels() }
        }
    }

    private func fetchOllamaModels() async {
        guard let url = URL(string: "\(aiService.ollamaEndpoint)/api/tags") else { return }
        isFetchingModels = true
        defer { isFetchingModels = false }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 5
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return }

            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let models = json["models"] as? [[String: Any]] {
                let names = models.compactMap { $0["name"] as? String }.sorted()
                await MainActor.run {
                    ollamaModels = names
                }
            }
        } catch {
            print("AISettings: Failed to fetch Ollama models: \(error.localizedDescription)")
        }
    }
}

private struct StatusRow: View {
    let name: String
    let icon: String
    let isAvailable: Bool

    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 20)
            Text(name)
            Spacer()
            if isAvailable {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Available")
                    .foregroundColor(.green)
            } else {
                Image(systemName: "xmark.circle")
                    .foregroundColor(.secondary)
                Text("Unavailable")
                    .foregroundColor(.secondary)
            }
        }
    }
}
