//
//  ActionItem.swift
//  OneOnOne
//
//  Action item model for tracking tasks from meetings
//  Created by Jordan Koch on 2026-02-02.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation

struct ActionItem: Identifiable, Codable {
    let id: UUID
    var title: String
    var description: String?
    var assigneeId: UUID? // Person ID
    var dueDate: Date?
    var priority: Priority
    var isCompleted: Bool
    var completedDate: Date?
    var meetingId: UUID // Source meeting
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        description: String? = nil,
        assigneeId: UUID? = nil,
        dueDate: Date? = nil,
        priority: Priority = .medium,
        isCompleted: Bool = false,
        meetingId: UUID
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.assigneeId = assigneeId
        self.dueDate = dueDate
        self.priority = priority
        self.isCompleted = isCompleted
        self.completedDate = nil
        self.meetingId = meetingId
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    mutating func markComplete() {
        isCompleted = true
        completedDate = Date()
        updatedAt = Date()
    }

    mutating func markIncomplete() {
        isCompleted = false
        completedDate = nil
        updatedAt = Date()
    }

    var isOverdue: Bool {
        guard let dueDate = dueDate, !isCompleted else { return false }
        return dueDate < Date()
    }

    var isDueSoon: Bool {
        guard let dueDate = dueDate, !isCompleted else { return false }
        let twoDaysFromNow = Calendar.current.date(byAdding: .day, value: 2, to: Date()) ?? Date()
        return dueDate <= twoDaysFromNow && dueDate >= Date()
    }
}

enum Priority: String, Codable, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case urgent = "Urgent"

    var icon: String {
        switch self {
        case .low: return "arrow.down"
        case .medium: return "minus"
        case .high: return "arrow.up"
        case .urgent: return "exclamationmark.2"
        }
    }

    var color: String {
        switch self {
        case .low: return "#888888"
        case .medium: return "#3BDAFC"
        case .high: return "#FF9933"
        case .urgent: return "#FF4444"
        }
    }

    var sortOrder: Int {
        switch self {
        case .urgent: return 0
        case .high: return 1
        case .medium: return 2
        case .low: return 3
        }
    }
}

// MARK: - Decision

struct Decision: Identifiable, Codable {
    let id: UUID
    var title: String
    var description: String?
    var rationale: String?
    var participants: [UUID] // Person IDs involved in decision
    var meetingId: UUID
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        description: String? = nil,
        rationale: String? = nil,
        participants: [UUID] = [],
        meetingId: UUID
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.rationale = rationale
        self.participants = participants
        self.meetingId = meetingId
        self.createdAt = Date()
    }
}

// MARK: - Follow Up

struct FollowUp: Identifiable, Codable {
    let id: UUID
    var topic: String
    var notes: String?
    var targetMeetingDate: Date?
    var isAddressed: Bool
    var meetingId: UUID
    var createdAt: Date

    init(
        id: UUID = UUID(),
        topic: String,
        notes: String? = nil,
        targetMeetingDate: Date? = nil,
        isAddressed: Bool = false,
        meetingId: UUID
    ) {
        self.id = id
        self.topic = topic
        self.notes = notes
        self.targetMeetingDate = targetMeetingDate
        self.isAddressed = isAddressed
        self.meetingId = meetingId
        self.createdAt = Date()
    }
}
