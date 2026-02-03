//
//  Goal.swift
//  OneOnOne
//
//  Goal tracking model for people and teams
//  Created by Jordan Koch on 2026-02-02.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation

struct Goal: Identifiable, Codable {
    let id: UUID
    var title: String
    var description: String?
    var personId: UUID? // Optional - can be team/personal goal
    var category: GoalCategory
    var status: GoalStatus
    var progress: Double // 0.0 to 1.0
    var targetDate: Date?
    var milestones: [Milestone]
    var relatedMeetingIds: [UUID] // Meetings where this goal was discussed
    var tags: [String]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        description: String? = nil,
        personId: UUID? = nil,
        category: GoalCategory = .development,
        status: GoalStatus = .notStarted,
        progress: Double = 0.0,
        targetDate: Date? = nil,
        milestones: [Milestone] = [],
        relatedMeetingIds: [UUID] = [],
        tags: [String] = []
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.personId = personId
        self.category = category
        self.status = status
        self.progress = progress
        self.targetDate = targetDate
        self.milestones = milestones
        self.relatedMeetingIds = relatedMeetingIds
        self.tags = tags
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var completedMilestones: Int {
        milestones.filter { $0.isCompleted }.count
    }

    var isOverdue: Bool {
        guard let targetDate = targetDate, status != .completed else { return false }
        return targetDate < Date()
    }

    mutating func updateProgress() {
        if milestones.isEmpty {
            return
        }
        progress = Double(completedMilestones) / Double(milestones.count)
        if progress >= 1.0 {
            status = .completed
        } else if progress > 0 {
            status = .inProgress
        }
        updatedAt = Date()
    }
}

enum GoalCategory: String, Codable, CaseIterable {
    case development = "Development"
    case performance = "Performance"
    case learning = "Learning"
    case project = "Project"
    case personal = "Personal"
    case team = "Team"
    case career = "Career"

    var icon: String {
        switch self {
        case .development: return "hammer"
        case .performance: return "chart.line.uptrend.xyaxis"
        case .learning: return "book"
        case .project: return "folder"
        case .personal: return "person"
        case .team: return "person.3"
        case .career: return "stairs"
        }
    }

    var color: String {
        switch self {
        case .development: return "#3BDAFC"
        case .performance: return "#4DE094"
        case .learning: return "#9966FF"
        case .project: return "#FF9933"
        case .personal: return "#FF5999"
        case .team: return "#5AB3FF"
        case .career: return "#FFD700"
        }
    }
}

enum GoalStatus: String, Codable, CaseIterable {
    case notStarted = "Not Started"
    case inProgress = "In Progress"
    case onHold = "On Hold"
    case completed = "Completed"
    case cancelled = "Cancelled"

    var icon: String {
        switch self {
        case .notStarted: return "circle"
        case .inProgress: return "circle.lefthalf.filled"
        case .onHold: return "pause.circle"
        case .completed: return "checkmark.circle.fill"
        case .cancelled: return "xmark.circle"
        }
    }

    var color: String {
        switch self {
        case .notStarted: return "#888888"
        case .inProgress: return "#3BDAFC"
        case .onHold: return "#FF9933"
        case .completed: return "#4DE094"
        case .cancelled: return "#FF4444"
        }
    }
}

// MARK: - Milestone

struct Milestone: Identifiable, Codable {
    let id: UUID
    var title: String
    var description: String?
    var targetDate: Date?
    var isCompleted: Bool
    var completedDate: Date?

    init(
        id: UUID = UUID(),
        title: String,
        description: String? = nil,
        targetDate: Date? = nil,
        isCompleted: Bool = false
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.targetDate = targetDate
        self.isCompleted = isCompleted
        self.completedDate = nil
    }

    mutating func markComplete() {
        isCompleted = true
        completedDate = Date()
    }
}
