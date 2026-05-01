//
//  RecordingModelTests.swift
//  OneOnOneTests
//
//  Unit tests for Recording, Transcription, TranscriptSegment
//  Created by Jordan Koch on 2026-05-01.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import XCTest
@testable import OneOnOne

final class RecordingModelTests: XCTestCase {

    // MARK: - Recording

    func testRecordingInit() {
        let meetingId = UUID()
        let recording = Recording(
            meetingId: meetingId,
            fileName: "meeting_2026.m4a",
            filePath: "/tmp/recordings/meeting_2026.m4a",
            duration: 1830,
            fileSize: 5_242_880,
            hasConsent: true,
            consentNote: "All participants agreed"
        )

        XCTAssertEqual(recording.meetingId, meetingId)
        XCTAssertEqual(recording.fileName, "meeting_2026.m4a")
        XCTAssertEqual(recording.duration, 1830)
        XCTAssertEqual(recording.fileSize, 5_242_880)
        XCTAssertTrue(recording.hasConsent)
        XCTAssertEqual(recording.consentNote, "All participants agreed")
        XCTAssertNil(recording.transcription)
    }

    // MARK: - Formatted Duration

    func testFormattedDurationMinutesSeconds() {
        let recording = Recording(meetingId: UUID(), fileName: "test.m4a", filePath: "/tmp/test.m4a", duration: 185)
        XCTAssertEqual(recording.formattedDuration, "3:05")
    }

    func testFormattedDurationWithHours() {
        let recording = Recording(meetingId: UUID(), fileName: "test.m4a", filePath: "/tmp/test.m4a", duration: 3725)
        XCTAssertEqual(recording.formattedDuration, "1:02:05")
    }

    func testFormattedDurationZero() {
        let recording = Recording(meetingId: UUID(), fileName: "test.m4a", filePath: "/tmp/test.m4a")
        XCTAssertEqual(recording.formattedDuration, "0:00")
    }

    // MARK: - File Size

    func testFormattedFileSizeMB() {
        let recording = Recording(meetingId: UUID(), fileName: "test.m4a", filePath: "/tmp/test.m4a", fileSize: 10_485_760)
        let formatted = recording.formattedFileSize
        XCTAssertTrue(formatted.contains("MB") || formatted.contains("10"), "10MB file should format with MB: got \(formatted)")
    }

    func testFormattedFileSizeKB() {
        let recording = Recording(meetingId: UUID(), fileName: "test.m4a", filePath: "/tmp/test.m4a", fileSize: 512_000)
        let formatted = recording.formattedFileSize
        XCTAssertTrue(formatted.contains("KB") || formatted.contains("500"), "500KB file should format appropriately: got \(formatted)")
    }

    // MARK: - File URL

    func testFileURL() {
        let recording = Recording(meetingId: UUID(), fileName: "test.m4a", filePath: "/tmp/recordings/test.m4a")
        XCTAssertNotNil(recording.fileURL)
        XCTAssertEqual(recording.fileURL?.lastPathComponent, "test.m4a")
    }

    // MARK: - Transcription

    func testTranscriptionWordCount() {
        let t = Transcription(text: "This is a test transcription with seven words")
        XCTAssertEqual(t.wordCount, 8)
    }

    func testTranscriptionWordCountEmpty() {
        let t = Transcription(text: "")
        XCTAssertEqual(t.wordCount, 0)
    }

    func testTranscriptionInit() {
        let t = Transcription(
            text: "Hello world",
            language: "en",
            model: "whisper-large-v3",
            processingTime: 12.5,
            extractedActionItems: ["Follow up on X"],
            extractedDecisions: ["Go with Plan A"],
            summary: "Quick sync"
        )
        XCTAssertEqual(t.language, "en")
        XCTAssertEqual(t.model, "whisper-large-v3")
        XCTAssertEqual(t.processingTime, 12.5)
        XCTAssertEqual(t.extractedActionItems, ["Follow up on X"])
        XCTAssertEqual(t.extractedDecisions, ["Go with Plan A"])
        XCTAssertEqual(t.summary, "Quick sync")
    }

    // MARK: - TranscriptSegment

    func testTranscriptSegmentFormattedTimeRange() {
        let segment = TranscriptSegment(
            text: "Hello everyone",
            startTime: 65,
            endTime: 125,
            speakerId: "speaker_1",
            confidence: 0.95
        )
        XCTAssertEqual(segment.formattedTimeRange, "1:05 - 2:05")
    }

    func testTranscriptSegmentConfidence() {
        let segment = TranscriptSegment(text: "Test", startTime: 0, endTime: 5, confidence: 0.85)
        XCTAssertEqual(segment.confidence, 0.85)
    }

    // MARK: - TranscriptionStatus

    func testTranscriptionStatusValues() {
        XCTAssertEqual(TranscriptionStatus.pending.rawValue, "Pending")
        XCTAssertEqual(TranscriptionStatus.processing.rawValue, "Processing")
        XCTAssertEqual(TranscriptionStatus.completed.rawValue, "Completed")
        XCTAssertEqual(TranscriptionStatus.failed.rawValue, "Failed")

        for status in [TranscriptionStatus.pending, .processing, .completed, .failed] {
            XCTAssertFalse(status.icon.isEmpty)
            XCTAssertTrue(status.color.hasPrefix("#"))
        }
    }

    // MARK: - Codable

    func testRecordingCodable() throws {
        let recording = Recording(
            meetingId: UUID(),
            fileName: "test.m4a",
            filePath: "/tmp/test.m4a",
            duration: 300,
            fileSize: 1024
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(recording)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Recording.self, from: data)

        XCTAssertEqual(decoded.id, recording.id)
        XCTAssertEqual(decoded.fileName, "test.m4a")
        XCTAssertEqual(decoded.duration, 300)
    }
}
