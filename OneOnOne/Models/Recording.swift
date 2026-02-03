//
//  Recording.swift
//  OneOnOne
//
//  Voice recording and transcription model
//  Created by Jordan Koch on 2026-02-02.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation

struct Recording: Identifiable, Codable {
    let id: UUID
    var meetingId: UUID
    var fileName: String
    var filePath: String
    var duration: TimeInterval
    var fileSize: Int64 // bytes
    var transcription: Transcription?
    var hasConsent: Bool
    var consentNote: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        meetingId: UUID,
        fileName: String,
        filePath: String,
        duration: TimeInterval = 0,
        fileSize: Int64 = 0,
        hasConsent: Bool = false,
        consentNote: String? = nil
    ) {
        self.id = id
        self.meetingId = meetingId
        self.fileName = fileName
        self.filePath = filePath
        self.duration = duration
        self.fileSize = fileSize
        self.transcription = nil
        self.hasConsent = hasConsent
        self.consentNote = consentNote
        self.createdAt = Date()
    }

    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }

    var fileURL: URL? {
        URL(fileURLWithPath: filePath)
    }
}

// MARK: - Transcription

struct Transcription: Identifiable, Codable {
    let id: UUID
    var text: String
    var segments: [TranscriptSegment]
    var language: String
    var model: String // e.g., "whisper-large-v3"
    var processingTime: TimeInterval
    var extractedActionItems: [String]
    var extractedDecisions: [String]
    var summary: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        text: String,
        segments: [TranscriptSegment] = [],
        language: String = "en",
        model: String = "whisper",
        processingTime: TimeInterval = 0,
        extractedActionItems: [String] = [],
        extractedDecisions: [String] = [],
        summary: String? = nil
    ) {
        self.id = id
        self.text = text
        self.segments = segments
        self.language = language
        self.model = model
        self.processingTime = processingTime
        self.extractedActionItems = extractedActionItems
        self.extractedDecisions = extractedDecisions
        self.summary = summary
        self.createdAt = Date()
    }

    var wordCount: Int {
        text.split(separator: " ").count
    }
}

struct TranscriptSegment: Identifiable, Codable {
    let id: UUID
    var text: String
    var startTime: TimeInterval
    var endTime: TimeInterval
    var speakerId: String? // For speaker diarization
    var confidence: Double // 0.0 to 1.0

    init(
        id: UUID = UUID(),
        text: String,
        startTime: TimeInterval,
        endTime: TimeInterval,
        speakerId: String? = nil,
        confidence: Double = 1.0
    ) {
        self.id = id
        self.text = text
        self.startTime = startTime
        self.endTime = endTime
        self.speakerId = speakerId
        self.confidence = confidence
    }

    var formattedTimeRange: String {
        let start = formatTime(startTime)
        let end = formatTime(endTime)
        return "\(start) - \(end)"
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Transcription Status

enum TranscriptionStatus: String, Codable {
    case pending = "Pending"
    case processing = "Processing"
    case completed = "Completed"
    case failed = "Failed"

    var icon: String {
        switch self {
        case .pending: return "clock"
        case .processing: return "waveform"
        case .completed: return "checkmark.circle"
        case .failed: return "xmark.circle"
        }
    }

    var color: String {
        switch self {
        case .pending: return "#888888"
        case .processing: return "#3BDAFC"
        case .completed: return "#4DE094"
        case .failed: return "#FF4444"
        }
    }
}
