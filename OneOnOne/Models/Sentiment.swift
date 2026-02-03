//
//  Sentiment.swift
//  OneOnOne
//
//  Sentiment and relationship health tracking
//  Created by Jordan Koch on 2026-02-02.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation

// MARK: - Sentiment Entry

struct SentimentEntry: Identifiable, Codable {
    let id: UUID
    var personId: UUID
    var meetingId: UUID?
    var sentiment: SentimentLevel
    var energyLevel: EnergyLevel
    var engagementLevel: EngagementLevel
    var stressIndicators: [StressIndicator]
    var notes: String?
    var date: Date
    var createdAt: Date

    init(
        id: UUID = UUID(),
        personId: UUID,
        meetingId: UUID? = nil,
        sentiment: SentimentLevel = .neutral,
        energyLevel: EnergyLevel = .moderate,
        engagementLevel: EngagementLevel = .engaged,
        stressIndicators: [StressIndicator] = [],
        notes: String? = nil,
        date: Date = Date()
    ) {
        self.id = id
        self.personId = personId
        self.meetingId = meetingId
        self.sentiment = sentiment
        self.energyLevel = energyLevel
        self.engagementLevel = engagementLevel
        self.stressIndicators = stressIndicators
        self.notes = notes
        self.date = date
        self.createdAt = Date()
    }

    var overallScore: Double {
        let sentimentScore = Double(sentiment.rawValue) / 5.0
        let energyScore = Double(energyLevel.rawValue) / 5.0
        let engagementScore = Double(engagementLevel.rawValue) / 5.0
        let stressPenalty = Double(stressIndicators.count) * 0.1

        return max(0, (sentimentScore + energyScore + engagementScore) / 3.0 - stressPenalty)
    }
}

enum SentimentLevel: Int, Codable, CaseIterable {
    case veryNegative = 1
    case negative = 2
    case neutral = 3
    case positive = 4
    case veryPositive = 5

    var name: String {
        switch self {
        case .veryNegative: return "Very Negative"
        case .negative: return "Negative"
        case .neutral: return "Neutral"
        case .positive: return "Positive"
        case .veryPositive: return "Very Positive"
        }
    }

    var icon: String {
        switch self {
        case .veryNegative: return "face.smiling.inverse"
        case .negative: return "cloud.rain"
        case .neutral: return "minus.circle"
        case .positive: return "face.smiling"
        case .veryPositive: return "sun.max.fill"
        }
    }

    var color: String {
        switch self {
        case .veryNegative: return "#FF4444"
        case .negative: return "#FF9933"
        case .neutral: return "#888888"
        case .positive: return "#5AB3FF"
        case .veryPositive: return "#4DE094"
        }
    }
}

enum EnergyLevel: Int, Codable, CaseIterable {
    case veryLow = 1
    case low = 2
    case moderate = 3
    case high = 4
    case veryHigh = 5

    var name: String {
        switch self {
        case .veryLow: return "Very Low"
        case .low: return "Low"
        case .moderate: return "Moderate"
        case .high: return "High"
        case .veryHigh: return "Very High"
        }
    }

    var icon: String {
        switch self {
        case .veryLow: return "battery.0percent"
        case .low: return "battery.25percent"
        case .moderate: return "battery.50percent"
        case .high: return "battery.75percent"
        case .veryHigh: return "battery.100percent"
        }
    }
}

enum EngagementLevel: Int, Codable, CaseIterable {
    case disengaged = 1
    case passive = 2
    case neutral = 3
    case engaged = 4
    case highlyEngaged = 5

    var name: String {
        switch self {
        case .disengaged: return "Disengaged"
        case .passive: return "Passive"
        case .neutral: return "Neutral"
        case .engaged: return "Engaged"
        case .highlyEngaged: return "Highly Engaged"
        }
    }

    var icon: String {
        switch self {
        case .disengaged: return "person.fill.xmark"
        case .passive: return "person.fill.questionmark"
        case .neutral: return "person.fill"
        case .engaged: return "person.fill.checkmark"
        case .highlyEngaged: return "star.fill"
        }
    }
}

enum StressIndicator: String, Codable, CaseIterable {
    case workload = "High Workload"
    case deadlines = "Deadline Pressure"
    case teamConflict = "Team Conflict"
    case unclear = "Unclear Expectations"
    case resources = "Lack of Resources"
    case workLifeBalance = "Work-Life Balance"
    case careerUncertainty = "Career Uncertainty"
    case healthIssues = "Health Issues"
    case personalIssues = "Personal Issues"

    var icon: String {
        switch self {
        case .workload: return "tray.full"
        case .deadlines: return "clock.badge.exclamationmark"
        case .teamConflict: return "person.2.slash"
        case .unclear: return "questionmark.circle"
        case .resources: return "exclamationmark.triangle"
        case .workLifeBalance: return "scale.3d"
        case .careerUncertainty: return "arrow.triangle.branch"
        case .healthIssues: return "heart.slash"
        case .personalIssues: return "house"
        }
    }
}

// MARK: - Relationship Health

struct RelationshipHealth: Identifiable {
    let id: UUID
    let personId: UUID
    let healthScore: Double // 0.0 to 1.0
    let trend: HealthTrend
    let sentimentHistory: [SentimentEntry]
    let riskFactors: [String]
    let recommendations: [String]

    var healthLevel: HealthLevel {
        switch healthScore {
        case 0.8...1.0: return .excellent
        case 0.6..<0.8: return .good
        case 0.4..<0.6: return .fair
        case 0.2..<0.4: return .poor
        default: return .critical
        }
    }
}

enum HealthLevel: String {
    case excellent = "Excellent"
    case good = "Good"
    case fair = "Fair"
    case poor = "Poor"
    case critical = "Critical"

    var color: String {
        switch self {
        case .excellent: return "#4DE094"
        case .good: return "#5AB3FF"
        case .fair: return "#FFD700"
        case .poor: return "#FF9933"
        case .critical: return "#FF4444"
        }
    }

    var icon: String {
        switch self {
        case .excellent: return "heart.fill"
        case .good: return "heart"
        case .fair: return "heart.slash"
        case .poor: return "exclamationmark.heart"
        case .critical: return "heart.slash.fill"
        }
    }
}

enum HealthTrend: String, Codable {
    case improving = "Improving"
    case stable = "Stable"
    case declining = "Declining"

    var icon: String {
        switch self {
        case .improving: return "arrow.up.right"
        case .stable: return "arrow.right"
        case .declining: return "arrow.down.right"
        }
    }

    var color: String {
        switch self {
        case .improving: return "#4DE094"
        case .stable: return "#5AB3FF"
        case .declining: return "#FF4444"
        }
    }
}
