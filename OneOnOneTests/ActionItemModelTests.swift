//
//  ActionItemModelTests.swift
//  OneOnOneTests
//
//  Unit tests for ActionItem, Decision, FollowUp, and Priority
//  Created by Jordan Koch on 2026-05-01.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import XCTest
@testable import OneOnOne

final class ActionItemModelTests: XCTestCase {

    // MARK: - Initialization

    func testActionItemDefaultInit() {
        let meetingId = UUID()
        let item = ActionItem(title: "Ship feature", meetingId: meetingId)

        XCTAssertEqual(item.title, "Ship feature")
        XCTAssertNil(item.description)
        XCTAssertNil(item.assigneeId)
        XCTAssertNil(item.dueDate)
        XCTAssertEqual(item.priority, .medium)
        XCTAssertFalse(item.isCompleted)
        XCTAssertNil(item.completedDate)
        XCTAssertEqual(item.meetingId, meetingId)
    }

    func testActionItemCustomInit() {
        let meetingId = UUID()
        let assigneeId = UUID()
        let dueDate = Calendar.current.date(byAdding: .day, value: 7, to: Date())!

        let item = ActionItem(
            title: "Write tests",
            description: "Unit and integration",
            assigneeId: assigneeId,
            dueDate: dueDate,
            priority: .high,
            meetingId: meetingId
        )

        XCTAssertEqual(item.description, "Unit and integration")
        XCTAssertEqual(item.assigneeId, assigneeId)
        XCTAssertEqual(item.priority, .high)
    }

    // MARK: - Mark Complete / Incomplete

    func testMarkComplete() {
        let meetingId = UUID()
        var item = ActionItem(title: "Task", meetingId: meetingId)
        XCTAssertFalse(item.isCompleted)
        XCTAssertNil(item.completedDate)

        item.markComplete()

        XCTAssertTrue(item.isCompleted)
        XCTAssertNotNil(item.completedDate)
    }

    func testMarkIncomplete() {
        let meetingId = UUID()
        var item = ActionItem(title: "Task", isCompleted: true, meetingId: meetingId)
        item.markComplete() // ensure completedDate is set

        item.markIncomplete()

        XCTAssertFalse(item.isCompleted)
        XCTAssertNil(item.completedDate)
    }

    // MARK: - Overdue Logic

    func testIsOverdueWhenPastDue() {
        let meetingId = UUID()
        let pastDate = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        let item = ActionItem(title: "Past due", dueDate: pastDate, meetingId: meetingId)
        XCTAssertTrue(item.isOverdue)
    }

    func testIsNotOverdueWhenFutureDue() {
        let meetingId = UUID()
        let futureDate = Calendar.current.date(byAdding: .day, value: 5, to: Date())!
        let item = ActionItem(title: "Future", dueDate: futureDate, meetingId: meetingId)
        XCTAssertFalse(item.isOverdue)
    }

    func testIsNotOverdueWhenCompleted() {
        let meetingId = UUID()
        let pastDate = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        let item = ActionItem(title: "Done", dueDate: pastDate, isCompleted: true, meetingId: meetingId)
        XCTAssertFalse(item.isOverdue, "Completed items should never be overdue")
    }

    func testIsNotOverdueWhenNoDueDate() {
        let meetingId = UUID()
        let item = ActionItem(title: "No date", meetingId: meetingId)
        XCTAssertFalse(item.isOverdue)
    }

    // MARK: - Due Soon Logic

    func testIsDueSoonTomorrow() {
        let meetingId = UUID()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let item = ActionItem(title: "Tomorrow", dueDate: tomorrow, meetingId: meetingId)
        XCTAssertTrue(item.isDueSoon)
    }

    func testIsNotDueSoonFarFuture() {
        let meetingId = UUID()
        let farFuture = Calendar.current.date(byAdding: .day, value: 10, to: Date())!
        let item = ActionItem(title: "Far out", dueDate: farFuture, meetingId: meetingId)
        XCTAssertFalse(item.isDueSoon)
    }

    func testIsNotDueSoonWhenCompleted() {
        let meetingId = UUID()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let item = ActionItem(title: "Done", dueDate: tomorrow, isCompleted: true, meetingId: meetingId)
        XCTAssertFalse(item.isDueSoon, "Completed items should not report as due soon")
    }

    // MARK: - Priority

    func testPrioritySortOrder() {
        XCTAssertLessThan(Priority.urgent.sortOrder, Priority.high.sortOrder)
        XCTAssertLessThan(Priority.high.sortOrder, Priority.medium.sortOrder)
        XCTAssertLessThan(Priority.medium.sortOrder, Priority.low.sortOrder)
    }

    func testPriorityHasIconAndColor() {
        for priority in Priority.allCases {
            XCTAssertFalse(priority.icon.isEmpty)
            XCTAssertTrue(priority.color.hasPrefix("#"))
        }
    }

    func testPriorityCaseIterable() {
        XCTAssertEqual(Priority.allCases.count, 4)
    }

    // MARK: - Codable

    func testActionItemEncodeDecode() throws {
        let meetingId = UUID()
        let item = ActionItem(
            title: "Codable test",
            description: "Testing encode/decode",
            priority: .urgent,
            meetingId: meetingId
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(item)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ActionItem.self, from: data)

        XCTAssertEqual(decoded.id, item.id)
        XCTAssertEqual(decoded.title, "Codable test")
        XCTAssertEqual(decoded.priority, .urgent)
        XCTAssertEqual(decoded.meetingId, meetingId)
    }

    // MARK: - Decision

    func testDecisionInit() {
        let meetingId = UUID()
        let participants = [UUID(), UUID()]
        let decision = Decision(
            title: "Go with Plan A",
            description: "Better ROI",
            rationale: "Lower cost, faster delivery",
            participants: participants,
            meetingId: meetingId
        )

        XCTAssertEqual(decision.title, "Go with Plan A")
        XCTAssertEqual(decision.description, "Better ROI")
        XCTAssertEqual(decision.rationale, "Lower cost, faster delivery")
        XCTAssertEqual(decision.participants.count, 2)
        XCTAssertEqual(decision.meetingId, meetingId)
    }

    func testDecisionCodable() throws {
        let meetingId = UUID()
        let decision = Decision(title: "Test Decision", meetingId: meetingId)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(decision)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Decision.self, from: data)

        XCTAssertEqual(decoded.id, decision.id)
        XCTAssertEqual(decoded.title, "Test Decision")
    }

    // MARK: - FollowUp

    func testFollowUpInit() {
        let meetingId = UUID()
        let followUp = FollowUp(
            topic: "Check on deployment",
            notes: "Should be done by Friday",
            isAddressed: false,
            meetingId: meetingId
        )

        XCTAssertEqual(followUp.topic, "Check on deployment")
        XCTAssertEqual(followUp.notes, "Should be done by Friday")
        XCTAssertFalse(followUp.isAddressed)
    }

    func testFollowUpCodable() throws {
        let meetingId = UUID()
        let followUp = FollowUp(topic: "Follow up test", meetingId: meetingId)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(followUp)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(FollowUp.self, from: data)

        XCTAssertEqual(decoded.id, followUp.id)
        XCTAssertEqual(decoded.topic, "Follow up test")
    }
}
