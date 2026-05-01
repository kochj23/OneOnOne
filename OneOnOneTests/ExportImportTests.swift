//
//  ExportImportTests.swift
//  OneOnOneTests
//
//  Tests for ExportData encode/decode and data integrity
//  Created by Jordan Koch on 2026-05-01.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import XCTest
@testable import OneOnOne

final class ExportImportTests: XCTestCase {

    // MARK: - ExportData Codable

    func testExportDataRoundTrip() throws {
        let personId = UUID()
        let meetingId = UUID()

        let people = [
            Person(name: "Alice", title: "Engineer")
        ]
        let meetings = [
            Meeting(
                id: meetingId,
                title: "Sprint Review",
                attendees: [personId],
                meetingType: .review,
                notes: "Went well",
                actionItems: [
                    ActionItem(title: "Follow up", priority: .high, meetingId: meetingId)
                ]
            )
        ]
        let goals = [
            Goal(title: "Ship v2", category: .project, status: .inProgress, progress: 0.5)
        ]

        let exportData = ExportData(
            people: people,
            meetings: meetings,
            goals: goals,
            exportDate: Date(),
            version: "1.1"
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(exportData)
        XCTAssertGreaterThan(data.count, 0)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ExportData.self, from: data)

        XCTAssertEqual(decoded.people.count, 1)
        XCTAssertEqual(decoded.people.first?.name, "Alice")
        XCTAssertEqual(decoded.meetings.count, 1)
        XCTAssertEqual(decoded.meetings.first?.title, "Sprint Review")
        XCTAssertEqual(decoded.meetings.first?.actionItems.count, 1)
        XCTAssertEqual(decoded.goals.count, 1)
        XCTAssertEqual(decoded.version, "1.1")
    }

    func testExportDataEmptyCollections() throws {
        let exportData = ExportData(
            people: [],
            meetings: [],
            goals: [],
            exportDate: Date(),
            version: "1.1"
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(exportData)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ExportData.self, from: data)

        XCTAssertTrue(decoded.people.isEmpty)
        XCTAssertTrue(decoded.meetings.isEmpty)
        XCTAssertTrue(decoded.goals.isEmpty)
        XCTAssertTrue(decoded.templates.isEmpty)
        XCTAssertTrue(decoded.feedback.isEmpty)
        XCTAssertTrue(decoded.careerProfiles.isEmpty)
        XCTAssertTrue(decoded.sentimentHistory.isEmpty)
        XCTAssertTrue(decoded.objectives.isEmpty)
        XCTAssertTrue(decoded.recordings.isEmpty)
    }

    func testExportDataWithAllFields() throws {
        let personId = UUID()
        let meetingId = UUID()

        let exportData = ExportData(
            people: [Person(id: personId, name: "Test")],
            meetings: [Meeting(id: meetingId, title: "Meeting")],
            goals: [Goal(title: "Goal")],
            templates: [MeetingTemplate(name: "Template")],
            feedback: [Feedback(personId: personId, type: .praise, direction: .given, content: "Great")],
            careerProfiles: [personId: CareerProfile(personId: personId)],
            sentimentHistory: [personId: [SentimentEntry(personId: personId)]],
            objectives: [Objective(title: "OKR")],
            recordings: [Recording(meetingId: meetingId, fileName: "rec.m4a", filePath: "/tmp/rec.m4a")],
            exportDate: Date(),
            version: "1.1"
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(exportData)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ExportData.self, from: data)

        XCTAssertEqual(decoded.people.count, 1)
        XCTAssertEqual(decoded.meetings.count, 1)
        XCTAssertEqual(decoded.goals.count, 1)
        XCTAssertEqual(decoded.templates.count, 1)
        XCTAssertEqual(decoded.feedback.count, 1)
        XCTAssertEqual(decoded.careerProfiles.count, 1)
        XCTAssertEqual(decoded.sentimentHistory.count, 1)
        XCTAssertEqual(decoded.objectives.count, 1)
        XCTAssertEqual(decoded.recordings.count, 1)
    }

    // MARK: - JSON Corruption Handling

    func testInvalidJSONThrowsDecodingError() {
        let invalidJSON = Data("{ not valid json".utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        XCTAssertThrowsError(try decoder.decode(ExportData.self, from: invalidJSON))
    }

    func testMissingRequiredFieldsThrows() {
        // ExportData requires people, meetings, goals, exportDate, version
        let partialJSON = Data("""
        {"people":[],"meetings":[]}
        """.utf8)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        XCTAssertThrowsError(try decoder.decode(ExportData.self, from: partialJSON))
    }

    // MARK: - Cross-Model Relationships

    func testMeetingActionItemRelationship() throws {
        let meetingId = UUID()
        let actionItem = ActionItem(title: "Fix bug", priority: .urgent, meetingId: meetingId)
        let meeting = Meeting(
            id: meetingId,
            title: "Bug Triage",
            actionItems: [actionItem]
        )

        XCTAssertEqual(meeting.actionItems.first?.meetingId, meetingId)
        XCTAssertEqual(meeting.openActionItemsCount, 1)
    }

    func testGoalMeetingRelationship() {
        let meetingId1 = UUID()
        let meetingId2 = UUID()
        let goal = Goal(
            title: "Ship Feature",
            relatedMeetingIds: [meetingId1, meetingId2]
        )
        XCTAssertEqual(goal.relatedMeetingIds.count, 2)
        XCTAssertTrue(goal.relatedMeetingIds.contains(meetingId1))
    }

    func testFeedbackMeetingRelationship() {
        let meetingId = UUID()
        let personId = UUID()
        let fb = Feedback(
            personId: personId,
            type: .praise,
            direction: .given,
            content: "Excellent work",
            meetingId: meetingId
        )
        XCTAssertEqual(fb.meetingId, meetingId)
        XCTAssertEqual(fb.personId, personId)
    }
}
