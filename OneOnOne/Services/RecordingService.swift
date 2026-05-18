//
//  RecordingService.swift
//  OneOnOne
//
//  Voice recording and transcription service
//  Created by Jordan Koch on 2026-02-02.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation

#if os(macOS)
import AVFoundation

@MainActor
class RecordingService: NSObject, ObservableObject {
    static let shared = RecordingService()

    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var audioLevel: Float = 0
    @Published var currentRecording: Recording?
    @Published var isTranscribing = false
    @Published var transcriptionProgress: Double = 0

    private var audioRecorder: AVAudioRecorder?
    private var recordingTimer: Timer?
    private var levelTimer: Timer?
    private var recordingStartTime: Date?

    private let recordingsDirectory: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("OneOnOne/Recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private override init() {
        super.init()
    }

    // MARK: - Recording

    func startRecording(for meetingId: UUID, hasConsent: Bool, consentNote: String? = nil) throws {
        guard !isRecording else { return }

        let fileName = "meeting_\(meetingId.uuidString)_\(Date().timeIntervalSince1970).m4a"
        let fileURL = recordingsDirectory.appendingPathComponent(fileName)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
        audioRecorder?.isMeteringEnabled = true
        audioRecorder?.delegate = self

        guard audioRecorder?.record() == true else {
            throw RecordingError.failedToStart
        }

        isRecording = true
        recordingStartTime = Date()
        recordingDuration = 0

        currentRecording = Recording(
            meetingId: meetingId,
            fileName: fileName,
            filePath: fileURL.path,
            hasConsent: hasConsent,
            consentNote: consentNote
        )

        // Start duration timer
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let start = self.recordingStartTime else { return }
                self.recordingDuration = Date().timeIntervalSince(start)
            }
        }

        // Start level meter
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateAudioLevel()
            }
        }
    }

    func stopRecording() -> Recording? {
        guard isRecording, let recorder = audioRecorder else { return nil }

        recorder.stop()
        isRecording = false

        recordingTimer?.invalidate()
        recordingTimer = nil
        levelTimer?.invalidate()
        levelTimer = nil

        guard var recording = currentRecording else { return nil }

        recording.duration = recordingDuration
        if let attrs = try? FileManager.default.attributesOfItem(atPath: recording.filePath),
           let size = attrs[.size] as? Int64 {
            recording.fileSize = size
        }

        currentRecording = nil
        recordingDuration = 0
        audioLevel = 0

        return recording
    }

    func pauseRecording() {
        audioRecorder?.pause()
    }

    func resumeRecording() {
        audioRecorder?.record()
    }

    private func updateAudioLevel() {
        guard let recorder = audioRecorder, recorder.isRecording else {
            audioLevel = 0
            return
        }

        recorder.updateMeters()
        let db = recorder.averagePower(forChannel: 0)
        // Convert dB to linear scale (0-1)
        audioLevel = max(0, min(1, (db + 60) / 60))
    }

    // MARK: - Transcription

    func transcribe(recording: Recording) async throws -> Transcription {
        guard FileManager.default.fileExists(atPath: recording.filePath) else {
            throw RecordingError.fileNotFound
        }

        isTranscribing = true
        transcriptionProgress = 0

        defer {
            Task { @MainActor in
                self.isTranscribing = false
                self.transcriptionProgress = 0
            }
        }

        // Use Whisper via Python for transcription
        let transcription = try await transcribeWithWhisper(filePath: recording.filePath)

        return transcription
    }

    private func transcribeWithWhisper(filePath: String) async throws -> Transcription {
        // Get whisper script path
        guard let scriptPath = getWhisperScriptPath() else {
            throw RecordingError.whisperNotAvailable
        }

        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        let pythonPath = "/Applications/Xcode.app/Contents/Developer/Library/Frameworks/Python3.framework/Versions/3.9/bin/python3.9"

        process.executableURL = URL(fileURLWithPath: pythonPath)
        process.arguments = [scriptPath, filePath]
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        var env = ProcessInfo.processInfo.environment
        let userSitePackages = "/Users/\(NSUserName())/Library/Python/3.9/lib/python/site-packages"
        env["PYTHONPATH"] = userSitePackages
        process.environment = env

        let startTime = Date()

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()

        guard process.terminationStatus == 0,
              let output = String(data: outputData, encoding: .utf8) else {
            throw RecordingError.transcriptionFailed
        }

        // Parse JSON output
        guard let jsonData = output.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let text = json["text"] as? String else {
            throw RecordingError.transcriptionFailed
        }

        var segments: [TranscriptSegment] = []
        if let segmentsJson = json["segments"] as? [[String: Any]] {
            for segmentJson in segmentsJson {
                if let segmentText = segmentJson["text"] as? String,
                   let start = segmentJson["start"] as? Double,
                   let end = segmentJson["end"] as? Double {
                    segments.append(TranscriptSegment(
                        text: segmentText,
                        startTime: start,
                        endTime: end,
                        confidence: segmentJson["confidence"] as? Double ?? 1.0
                    ))
                }
            }
        }

        let processingTime = Date().timeIntervalSince(startTime)

        return Transcription(
            text: text,
            segments: segments,
            language: json["language"] as? String ?? "en",
            model: "whisper",
            processingTime: processingTime
        )
    }

    private func getWhisperScriptPath() -> String? {
        // Try bundle first
        if let bundlePath = Bundle.main.path(forResource: "whisper_transcribe", ofType: "py") {
            return bundlePath
        }

        // Fall back to development path
        let devPath = "/Volumes/Data/xcode/OneOnOne/Python/whisper_transcribe.py"
        if FileManager.default.fileExists(atPath: devPath) {
            return devPath
        }

        return nil
    }

    // MARK: - File Management

    func deleteRecording(_ recording: Recording) {
        try? FileManager.default.removeItem(atPath: recording.filePath)
    }

    func getRecordingURL(_ recording: Recording) -> URL? {
        return URL(fileURLWithPath: recording.filePath)
    }

    func getAllRecordings() -> [URL] {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: recordingsDirectory,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return contents.filter { $0.pathExtension == "m4a" }
    }
}

// MARK: - AVAudioRecorderDelegate

extension RecordingService: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            if !flag {
                print("Recording did not finish successfully")
            }
        }
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in
            print("Recording encode error: \(error?.localizedDescription ?? "unknown")")
            self.isRecording = false
        }
    }
}

// MARK: - Errors

enum RecordingError: LocalizedError {
    case failedToStart
    case fileNotFound
    case whisperNotAvailable
    case transcriptionFailed

    var errorDescription: String? {
        switch self {
        case .failedToStart:
            return "Failed to start recording"
        case .fileNotFound:
            return "Recording file not found"
        case .whisperNotAvailable:
            return "Whisper transcription not available"
        case .transcriptionFailed:
            return "Transcription failed"
        }
    }
}
#endif  // os(macOS)
