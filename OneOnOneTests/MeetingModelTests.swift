//
//  MeetingModelTests.swift
//  OneOnOneTests
//
//  Unit tests for Meeting model, MeetingType, and MeetingMood
//  Created by Jordan Koch on 2026-05-01.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import XCTest
@testable import OneOnOne

final class MeetingModelTests: XCTestCase {

    // MARK: - Initialization

    func testMeetingDefaultInitialization() {
        let meeting = Meeting(title: "Weekly Sync")

        XCTAssertEqual(meeting.title, "Weekly Sync")
        XCTAssertEqual(meeting.duration, 3600, "Default duration should be 1 hour (3600 seconds)")
        XCTAssertTrue(meeting.attendees.isEmpty)
        XCTAssertEqual(meeting.meetingType, .oneOnOne)
        XCTAssertNil(meeting.location)
        XCTAssertNil(meeting.calendarEventId)
        XCTAssertNil(meeting.outlookEventId)
        XCTAssertNil(meeting.agenda)
        XCTAssertEqual(meeting.notes, "")
        XCTAssertNil(meeting.summary)
        XCTAssertTrue(meeting.actionItems.isEmpty)
        XCTAssertTrue(meeting.decisions.isEmpty)
        XCTAssertTrue(meeting.followUps.isEmpty)
        XCTAssertTrue(meeting.tags.isEmpty)
        XCTAssertNil(meeting.mood)
        XCTAssertFalse(meeting.isRecurring)
        XCTAssertNil(meeting.recurringId)
    }

    func testMeetingCustomInitialization() {
        let id = UUID()
        let date = Date()
        let attendee1 = UUID()
        let attendee2 = UUID()

        let meeting = Meeting(
            id: id,
            title: "Sprint Planning",
            date: date,
            duration: 5400,
            attendees: [attendee1, attendee2],
            meetingType: .planning,
            location: "Room A",
            calendarEventId: "cal-123",
            outlookEventId: "outlook-456",
            agenda: "Review backlog",
            notes: "Discussed priorities",
            summary: "Good session",
            tags: ["sprint", "Q2"],
            mood: .productive,
            isRecurring: true,
            recurringId: UUID()
        )

        XCTAssertEqual(meeting.id, id)
        XCTAssertEqual(meeting.title, "Sprint Planning")
        XCTAssertEqual(meeting.duration, 5400)
        XCTAssertEqual(meeting.attendees.count, 2)
        XCTAssertEqual(meeting.meetingType, .planning)
        XCTAssertEqual(meeting.location, "Room A")
        XCTAssertEqual(meeting.calendarEventId, "cal-123")
        XCTAssertEqual(meeting.outlookEventId, "outlook-456")
        XCTAssertEqual(meeting.agenda, "Review backlog")
        XCTAssertEqual(meeting.notes, "Discussed priorities")
        XCTAssertEqual(meeting.summary, "Good session")
        XCTAssertEqual(meeting.tags, ["sprint", "Q2"])
        XCTAssertEqual(meeting.mood, .productive)
        XCTAssertTrue(meeting.isRecurring)
        XCTAssertNotNil(meeting.recurringId)
    }

    func testMeetingSentimentFallback() {
        // When mood is nil and sentiment is provided, mood should take the sentiment value
        let meeting = Meeting(
            title: "Test",
            sentiment: .challenging,
            mood: nil
        )
        XCTAssertEqual(meeting.mood, .challenging)
    }

    func testMeetingMoodOverridesSentiment() {
        // When both mood and sentiment are provided, mood should win
        let meeting = Meeting(
            title: "Test",
            sentiment: .challenging,
            mood: .productive
        )
        XCTAssertEqual(meeting.mood, .productive)
    }

    // MARK: - Formatted Duration

    func testFormattedDurationMinutesOnly() {
        let meeting = Meeting(title: "Quick chat", duration: 1800)
        XCTAssertEqual(meeting.formattedDuration, "30 min")
    }

    func testFormattedDurationHoursAndMinutes() {
        let meeting = Meeting(title: "Long session", duration: 5400)
        XCTAssertEqual(meeting.formattedDuration, "1h 30m")
    }

    func testFormattedDurationExactHour() {
        let meeting = Meeting(title: "One hour", duration: 3600)
        XCTAssertEqual(meeting.formattedDuration, "1h 0m")
    }

    func testFormattedDurationZero() {
        let meeting = Meeting(title: "Zero", duration: 0)
        XCTAssertEqual(meeting.formattedDuration, "0 min")
    }

    // MARK: - Action Item Counts

    func testOpenActionItemsCount() {
        let meetingId = UUID()
        var meeting = Meeting(title: "Test")
        meeting.actionItems = [
            ActionItem(title: "Do X", meetingId: meetingId),
            ActionItem(title: "Do Y", isCompleted: true, meetingId: meetingId),
            ActionItem(title: "Do Z", meetingId: meetingId)
        ]

        XCTAssertEqual(meeting.openActionItemsCount, 2)
        XCTAssertEqual(meeting.completedActionItemsCount, 1)
    }

    func testActionItemCountsAllOpen() {
        let meetingId = UUID()
        var meeting = Meeting(title: "Test")
        meeting.actionItems = [
            ActionItem(title: "A", meetingId: meetingId),
            ActionItem(title: "B", meetingId: meetingId)
        ]

        XCTAssertEqual(meeting.openActionItemsCount, 2)
        XCTAssertEqual(meeting.completedActionItemsCount, 0)
    }

    func testActionItemCountsEmpty() {
        let meeting = Meeting(title: "No items")
        XCTAssertEqual(meeting.openActionItemsCount, 0)
        XCTAssertEqual(meeting.completedActionItemsCount, 0)
    }

    // MARK: - Equatable & Hashable

    func testMeetingEquality() {
        let id = UUID()
        let m1 = Meeting(id: id, title: "A")
        let m2 = Meeting(id: id, title: "B")
        XCTAssertEqual(m1, m2, "Meetings with same ID should be equal regardless of title")
    }

    func testMeetingInequality() {
        let m1 = Meeting(title: "A")
        let m2 = Meeting(title: "A")
        XCTAssertNotEqual(m1, m2, "Meetings with different IDs should not be equal")
    }

    func testMeetingHashable() {
        let id = UUID()
        let m1 = Meeting(id: id, title: "A")
        let m2 = Meeting(id: id, title: "B")
        XCTAssertEqual(m1.hashValue, m2.hashValue)

        var set: Set<Meeting> = [m1]
        set.insert(m2)
        XCTAssertEqual(set.count, 1, "Same-ID meetings should deduplicate in Set")
    }

    // MARK: - Codable

    func testMeetingEncodeDecode() throws {
        let meeting = Meeting(
            title: "Codable Test",
            duration: 1800,
            meetingType: .retrospective,
            notes: "Some notes here",
            tags: ["tag1"],
            mood: .positive
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(meeting)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Meeting.self, from: data)

        XCTAssertEqual(decoded.id, meeting.id)
        XCTAssertEqual(decoded.title, "Codable Test")
        XCTAssertEqual(decoded.duration, 1800)
        XCTAssertEqual(decoded.meetingType, .retrospective)
        XCTAssertEqual(decoded.notes, "Some notes here")
        XCTAssertEqual(decoded.tags, ["tag1"])
        XCTAssertEqual(decoded.mood, .positive)
    }

    // MARK: - MeetingType

    func testMeetingTypeCaseIterable() {
        XCTAssertEqual(MeetingType.allCases.count, 10)
    }

    func testMeetingTypeRawValues() {
        XCTAssertEqual(MeetingType.oneOnOne.rawValue, "1:1")
        XCTAssertEqual(MeetingType.teamMeeting.rawValue, "Team Meeting")
        XCTAssertEqual(MeetingType.standUp.rawValue, "Stand-up")
    }

    func testMeetingTypeIcons() {
        for meetingType in MeetingType.allCases {
            XCTAssertFalse(meetingType.icon.isEmpty, "\(meetingType) should have a non-empty icon")
        }
    }

    // MARK: - MeetingMood

    func testMeetingMoodCaseIterable() {
        XCTAssertEqual(MeetingMood.allCases.count, 5)
    }

    func testMeetingMoodHasIconAndColor() {
        for mood in MeetingMood.allCases {
            XCTAssertFalse(mood.icon.isEmpty, "\(mood) should have an icon")
            XCTAssertTrue(mood.color.hasPrefix("#"), "\(mood) color should be a hex value")
        }
    }
}
