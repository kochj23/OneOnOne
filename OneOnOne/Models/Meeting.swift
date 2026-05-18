//
//  Meeting.swift
//  OneOnOne
//
//  Meeting model for storing meeting details
//  Created by Jordan Koch on 2026-02-02.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation

struct Meeting: Identifiable, Codable, Hashable {
    static func == (lhs: Meeting, rhs: Meeting) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    let id: UUID
    var title: String
    var date: Date
    var duration: TimeInterval // in seconds
    var attendees: [UUID] // Person IDs
    var meetingType: MeetingType
    var location: String?
    var calendarEventId: String? // For Apple Calendar integration
    var outlookEventId: String? // For Outlook calendar integration

    // Content
    var agenda: String?
    var notes: String
    var summary: String? // AI-generated summary
    var actionItems: [ActionItem]
    var decisions: [Decision]
    var followUps: [FollowUp]

    // Metadata
    var tags: [String]
    var mood: MeetingMood?
    var isRecurring: Bool
    var recurringId: UUID? // Links recurring meetings together
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        date: Date = Date(),
        duration: TimeInterval = 3600, // 1 hour default
        attendees: [UUID] = [],
        meetingType: MeetingType = .oneOnOne,
        location: String? = nil,
        calendarEventId: String? = nil,
        outlookEventId: String? = nil,
        agenda: String? = nil,
        notes: String = "",
        summary: String? = nil,
        actionItems: [ActionItem] = [],
        decisions: [Decision] = [],
        followUps: [FollowUp] = [],
        sentiment: MeetingMood? = nil,
        tags: [String] = [],
        mood: MeetingMood? = nil,
        isRecurring: Bool = false,
        recurringId: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.duration = duration
        self.attendees = attendees
        self.meetingType = meetingType
        self.location = location
        self.calendarEventId = calendarEventId
        self.outlookEventId = outlookEventId
        self.agenda = agenda
        self.notes = notes
        self.summary = summary
        self.actionItems = actionItems
        self.decisions = decisions
        self.followUps = followUps
        self.tags = tags
        self.mood = mood ?? sentiment
        self.isRecurring = isRecurring
        self.recurringId = recurringId
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes) min"
    }

    var openActionItemsCount: Int {
        actionItems.filter { !$0.isCompleted }.count
    }

    var completedActionItemsCount: Int {
        actionItems.filter { $0.isCompleted }.count
    }
}

enum MeetingType: String, Codable, CaseIterable {
    case oneOnOne = "1:1"
    case teamMeeting = "Team Meeting"
    case standUp = "Stand-up"
    case retrospective = "Retrospective"
    case planning = "Planning"
    case review = "Review"
    case brainstorm = "Brainstorm"
    case interview = "Interview"
    case training = "Training"
    case other = "Other"

    var icon: String {
        switch self {
        case .oneOnOne: return "person.2"
        case .teamMeeting: return "person.3"
        case .standUp: return "figure.stand"
        case .retrospective: return "arrow.counterclockwise"
        case .planning: return "calendar"
        case .review: return "checkmark.circle"
        case .brainstorm: return "lightbulb"
        case .interview: return "person.badge.plus"
        case .training: return "book"
        case .other: return "rectangle.3.group"
        }
    }
}

enum MeetingMood: String, Codable, CaseIterable {
    case productive = "Productive"
    case challenging = "Challenging"
    case neutral = "Neutral"
    case positive = "Positive"
    case tense = "Tense"

    var icon: String {
        switch self {
        case .productive: return "bolt.fill"
        case .challenging: return "exclamationmark.triangle"
        case .neutral: return "minus.circle"
        case .positive: return "face.smiling"
        case .tense: return "cloud.rain"
        }
    }

    var color: String {
        switch self {
        case .productive: return "#4DE094"
        case .challenging: return "#FF9933"
        case .neutral: return "#888888"
        case .positive: return "#3BDAFC"
        case .tense: return "#FF5999"
        }
    }
}
