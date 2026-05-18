//
//  Person.swift
//  OneOnOne
//
//  Person model for tracking individuals in meetings
//  Created by Jordan Koch on 2026-02-02.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation

struct Person: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var email: String?
    var title: String?
    var department: String?
    var notes: String?
    var avatarColor: String // Hex color for avatar
    var tags: [String]
    var createdAt: Date
    var updatedAt: Date

    // Relationship tracking
    var meetingFrequency: MeetingFrequency
    var lastMeetingDate: Date?
    var nextScheduledMeeting: Date?

    init(
        id: UUID = UUID(),
        name: String,
        email: String? = nil,
        title: String? = nil,
        department: String? = nil,
        notes: String? = nil,
        avatarColor: String = Person.randomAvatarColor(),
        tags: [String] = [],
        meetingFrequency: MeetingFrequency = .weekly
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.title = title
        self.department = department
        self.notes = notes
        self.avatarColor = avatarColor
        self.tags = tags
        self.createdAt = Date()
        self.updatedAt = Date()
        self.meetingFrequency = meetingFrequency
        self.lastMeetingDate = nil
        self.nextScheduledMeeting = nil
    }

    var initials: String {
        let components = name.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
        } else if let first = components.first {
            return String(first.prefix(2)).uppercased()
        }
        return "?"
    }

    var displayTitle: String {
        if let title = title, let department = department {
            return "\(title) - \(department)"
        } else if let title = title {
            return title
        } else if let department = department {
            return department
        }
        return ""
    }

    static func randomAvatarColor() -> String {
        let colors = [
            "#3BDAFC", // Cyan
            "#9966FF", // Purple
            "#FF5999", // Pink
            "#FF9933", // Orange
            "#4DE094", // Green
            "#5AB3FF", // Blue
        ]
        return colors.randomElement() ?? "#3BDAFC"
    }
}

enum MeetingFrequency: String, Codable, CaseIterable {
    case daily = "Daily"
    case weekly = "Weekly"
    case biweekly = "Bi-weekly"
    case monthly = "Monthly"
    case quarterly = "Quarterly"
    case asNeeded = "As Needed"

    var calendarDays: Int? {
        switch self {
        case .daily: return 1
        case .weekly: return 7
        case .biweekly: return 14
        case .monthly: return 30
        case .quarterly: return 90
        case .asNeeded: return nil
        }
    }
}
