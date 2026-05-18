//
//  Feedback.swift
//  OneOnOne
//
//  Feedback and praise tracking model
//  Created by Jordan Koch on 2026-02-02.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation

struct Feedback: Identifiable, Codable {
    let id: UUID
    var personId: UUID
    var type: FeedbackType
    var direction: FeedbackDirection
    var content: String
    var context: String? // What it was about
    var meetingId: UUID? // Optional link to meeting
    var tags: [String]
    var date: Date
    var createdAt: Date

    init(
        id: UUID = UUID(),
        personId: UUID,
        type: FeedbackType,
        direction: FeedbackDirection,
        content: String,
        context: String? = nil,
        meetingId: UUID? = nil,
        tags: [String] = [],
        date: Date = Date()
    ) {
        self.id = id
        self.personId = personId
        self.type = type
        self.direction = direction
        self.content = content
        self.context = context
        self.meetingId = meetingId
        self.tags = tags
        self.date = date
        self.createdAt = Date()
    }
}

enum FeedbackType: String, Codable, CaseIterable {
    case praise = "Praise"
    case recognition = "Recognition"
    case constructive = "Constructive"
    case achievement = "Achievement"
    case thanks = "Thanks"
    case milestone = "Milestone"

    var icon: String {
        switch self {
        case .praise: return "star.fill"
        case .recognition: return "trophy.fill"
        case .constructive: return "lightbulb.fill"
        case .achievement: return "medal.fill"
        case .thanks: return "heart.fill"
        case .milestone: return "flag.fill"
        }
    }

    var color: String {
        switch self {
        case .praise: return "#FFD700"
        case .recognition: return "#FF9933"
        case .constructive: return "#5AB3FF"
        case .achievement: return "#4DE094"
        case .thanks: return "#FF5999"
        case .milestone: return "#9966FF"
        }
    }
}

enum FeedbackDirection: String, Codable, CaseIterable {
    case given = "Given"
    case received = "Received"

    var icon: String {
        switch self {
        case .given: return "arrow.up.right"
        case .received: return "arrow.down.left"
        }
    }
}

// MARK: - Praise Summary

struct PraiseSummary {
    let personId: UUID
    let totalPraise: Int
    let praiseGiven: Int
    let praiseReceived: Int
    let recentPraise: [Feedback]
    let topTags: [String]

    var praiseRatio: Double {
        guard praiseGiven > 0 else { return 0 }
        return Double(praiseReceived) / Double(praiseGiven)
    }
}
