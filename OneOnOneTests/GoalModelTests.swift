//
//  GoalModelTests.swift
//  OneOnOneTests
//
//  Unit tests for Goal, Milestone, GoalCategory, and GoalStatus
//  Created by Jordan Koch on 2026-05-01.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import XCTest
@testable import OneOnOne

final class GoalModelTests: XCTestCase {

    // MARK: - Initialization

    func testGoalDefaultInit() {
        let goal = Goal(title: "Learn SwiftUI")

        XCTAssertEqual(goal.title, "Learn SwiftUI")
        XCTAssertNil(goal.description)
        XCTAssertNil(goal.personId)
        XCTAssertEqual(goal.category, .development)
        XCTAssertEqual(goal.status, .notStarted)
        XCTAssertEqual(goal.progress, 0.0)
        XCTAssertNil(goal.targetDate)
        XCTAssertTrue(goal.milestones.isEmpty)
        XCTAssertTrue(goal.relatedMeetingIds.isEmpty)
        XCTAssertTrue(goal.tags.isEmpty)
    }

    // MARK: - Progress Calculation

    func testUpdateProgressAllComplete() {
        var goal = Goal(title: "Ship v2")
        goal.milestones = [
            Milestone(title: "Design", isCompleted: true),
            Milestone(title: "Implement", isCompleted: true),
            Milestone(title: "Test", isCompleted: true)
        ]
        goal.updateProgress()

        XCTAssertEqual(goal.progress, 1.0, accuracy: 0.001)
        XCTAssertEqual(goal.status, .completed)
    }

    func testUpdateProgressPartial() {
        var goal = Goal(title: "Ship v2")
        goal.milestones = [
            Milestone(title: "Design", isCompleted: true),
            Milestone(title: "Implement", isCompleted: false),
            Milestone(title: "Test", isCompleted: false)
        ]
        goal.updateProgress()

        XCTAssertEqual(goal.progress, 1.0 / 3.0, accuracy: 0.001)
        XCTAssertEqual(goal.status, .inProgress)
    }

    func testUpdateProgressNoneComplete() {
        var goal = Goal(title: "New Goal")
        goal.milestones = [
            Milestone(title: "Step 1", isCompleted: false),
            Milestone(title: "Step 2", isCompleted: false)
        ]
        goal.updateProgress()

        XCTAssertEqual(goal.progress, 0.0)
        // Status stays notStarted because progress is 0
        XCTAssertEqual(goal.status, .notStarted)
    }

    func testUpdateProgressNoMilestones() {
        var goal = Goal(title: "No milestones", progress: 0.5)
        goal.updateProgress()
        XCTAssertEqual(goal.progress, 0.5, "Progress should not change when there are no milestones")
    }

    func testCompletedMilestoneCount() {
        var goal = Goal(title: "G")
        goal.milestones = [
            Milestone(title: "A", isCompleted: true),
            Milestone(title: "B", isCompleted: false),
            Milestone(title: "C", isCompleted: true)
        ]
        XCTAssertEqual(goal.completedMilestones, 2)
    }

    // MARK: - Overdue

    func testIsOverdueWithPastDate() {
        let pastDate = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let goal = Goal(title: "Overdue", status: .inProgress, targetDate: pastDate)
        XCTAssertTrue(goal.isOverdue)
    }

    func testIsNotOverdueWithFutureDate() {
        let futureDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())!
        let goal = Goal(title: "On time", status: .inProgress, targetDate: futureDate)
        XCTAssertFalse(goal.isOverdue)
    }

    func testIsNotOverdueWhenCompleted() {
        let pastDate = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let goal = Goal(title: "Done", status: .completed, targetDate: pastDate)
        XCTAssertFalse(goal.isOverdue, "Completed goals should not be overdue")
    }

    func testIsNotOverdueWithoutTargetDate() {
        let goal = Goal(title: "No date")
        XCTAssertFalse(goal.isOverdue)
    }

    // MARK: - Equatable & Hashable

    func testGoalEquality() {
        let id = UUID()
        let g1 = Goal(id: id, title: "A")
        let g2 = Goal(id: id, title: "B")
        XCTAssertEqual(g1, g2, "Goals with same ID should be equal")
    }

    func testGoalHashable() {
        let id = UUID()
        let g1 = Goal(id: id, title: "A")
        let g2 = Goal(id: id, title: "B")
        var set: Set<Goal> = [g1]
        set.insert(g2)
        XCTAssertEqual(set.count, 1)
    }

    // MARK: - Codable

    func testGoalEncodeDecode() throws {
        let goal = Goal(
            title: "Test Goal",
            description: "Description here",
            category: .learning,
            status: .inProgress,
            progress: 0.5,
            tags: ["important"]
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(goal)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Goal.self, from: data)

        XCTAssertEqual(decoded.id, goal.id)
        XCTAssertEqual(decoded.title, "Test Goal")
        XCTAssertEqual(decoded.category, .learning)
        XCTAssertEqual(decoded.status, .inProgress)
        XCTAssertEqual(decoded.progress, 0.5, accuracy: 0.001)
    }

    // MARK: - GoalCategory & GoalStatus

    func testGoalCategoryCount() {
        XCTAssertEqual(GoalCategory.allCases.count, 7)
    }

    func testGoalStatusCount() {
        XCTAssertEqual(GoalStatus.allCases.count, 5)
    }

    func testGoalCategoryHasIconAndColor() {
        for cat in GoalCategory.allCases {
            XCTAssertFalse(cat.icon.isEmpty)
            XCTAssertTrue(cat.color.hasPrefix("#"))
        }
    }

    func testGoalStatusHasIconAndColor() {
        for status in GoalStatus.allCases {
            XCTAssertFalse(status.icon.isEmpty)
            XCTAssertTrue(status.color.hasPrefix("#"))
        }
    }

    // MARK: - Milestone

    func testMilestoneMarkComplete() {
        var ms = Milestone(title: "Step 1")
        XCTAssertFalse(ms.isCompleted)
        XCTAssertNil(ms.completedDate)

        ms.markComplete()

        XCTAssertTrue(ms.isCompleted)
        XCTAssertNotNil(ms.completedDate)
    }

    func testMilestoneCodable() throws {
        let ms = Milestone(title: "Codable Milestone", description: "desc")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(ms)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Milestone.self, from: data)

        XCTAssertEqual(decoded.id, ms.id)
        XCTAssertEqual(decoded.title, "Codable Milestone")
    }
}
