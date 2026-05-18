//
//  OKR.swift
//  OneOnOne
//
//  OKR (Objectives and Key Results) model
//  Created by Jordan Koch on 2026-02-02.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation

// MARK: - Objective

struct Objective: Identifiable, Codable {
    let id: UUID
    var title: String
    var description: String?
    var level: OKRLevel
    var parentId: UUID? // For cascading OKRs
    var ownerId: UUID? // Person ID
    var quarter: String // e.g., "Q1 2026"
    var keyResults: [KeyResult]
    var status: OKRStatus
    var tags: [String]
    var linkedGoalIds: [UUID] // Links to Goal model
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        description: String? = nil,
        level: OKRLevel = .individual,
        parentId: UUID? = nil,
        ownerId: UUID? = nil,
        quarter: String = "",
        keyResults: [KeyResult] = [],
        status: OKRStatus = .onTrack,
        tags: [String] = [],
        linkedGoalIds: [UUID] = []
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.level = level
        self.parentId = parentId
        self.ownerId = ownerId
        self.quarter = quarter
        self.keyResults = keyResults
        self.status = status
        self.tags = tags
        self.linkedGoalIds = linkedGoalIds
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var progress: Double {
        guard !keyResults.isEmpty else { return 0 }
        let total = keyResults.reduce(0.0) { $0 + $1.progress }
        return total / Double(keyResults.count)
    }

    var completedKeyResults: Int {
        keyResults.filter { $0.progress >= 1.0 }.count
    }

    var isComplete: Bool {
        progress >= 1.0
    }
}

// MARK: - Key Result

struct KeyResult: Identifiable, Codable {
    let id: UUID
    var title: String
    var description: String?
    var metricType: MetricType
    var startValue: Double
    var currentValue: Double
    var targetValue: Double
    var unit: String?
    var updates: [KRUpdate]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        description: String? = nil,
        metricType: MetricType = .increase,
        startValue: Double = 0,
        currentValue: Double = 0,
        targetValue: Double = 100,
        unit: String? = nil,
        updates: [KRUpdate] = []
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.metricType = metricType
        self.startValue = startValue
        self.currentValue = currentValue
        self.targetValue = targetValue
        self.unit = unit
        self.updates = updates
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var progress: Double {
        let range = targetValue - startValue
        guard range != 0 else { return currentValue >= targetValue ? 1.0 : 0.0 }

        switch metricType {
        case .increase:
            return min(1.0, max(0, (currentValue - startValue) / range))
        case .decrease:
            return min(1.0, max(0, (startValue - currentValue) / (startValue - targetValue)))
        case .maintain:
            // For maintain, check if value is within acceptable range
            let variance = abs(currentValue - targetValue)
            let threshold = abs(startValue - targetValue) * 0.1 // 10% variance allowed
            return variance <= threshold ? 1.0 : max(0, 1.0 - (variance / abs(startValue - targetValue)))
        case .binary:
            return currentValue >= targetValue ? 1.0 : 0.0
        }
    }

    var formattedCurrent: String {
        if let unit = unit {
            return "\(formatNumber(currentValue)) \(unit)"
        }
        return formatNumber(currentValue)
    }

    var formattedTarget: String {
        if let unit = unit {
            return "\(formatNumber(targetValue)) \(unit)"
        }
        return formatNumber(targetValue)
    }

    private func formatNumber(_ value: Double) -> String {
        if value == floor(value) {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }
}

struct KRUpdate: Identifiable, Codable {
    let id: UUID
    var value: Double
    var notes: String?
    var date: Date

    init(id: UUID = UUID(), value: Double, notes: String? = nil, date: Date = Date()) {
        self.id = id
        self.value = value
        self.notes = notes
        self.date = date
    }
}

enum MetricType: String, Codable, CaseIterable {
    case increase = "Increase"
    case decrease = "Decrease"
    case maintain = "Maintain"
    case binary = "Yes/No"

    var icon: String {
        switch self {
        case .increase: return "arrow.up.right"
        case .decrease: return "arrow.down.right"
        case .maintain: return "arrow.left.and.right"
        case .binary: return "checkmark.circle"
        }
    }
}

enum OKRLevel: String, Codable, CaseIterable {
    case company = "Company"
    case department = "Department"
    case team = "Team"
    case individual = "Individual"

    var icon: String {
        switch self {
        case .company: return "building.2"
        case .department: return "rectangle.3.group"
        case .team: return "person.3"
        case .individual: return "person"
        }
    }

    var color: String {
        switch self {
        case .company: return "#9966FF"
        case .department: return "#FF9933"
        case .team: return "#3BDAFC"
        case .individual: return "#4DE094"
        }
    }
}

enum OKRStatus: String, Codable, CaseIterable {
    case onTrack = "On Track"
    case atRisk = "At Risk"
    case behind = "Behind"
    case achieved = "Achieved"
    case cancelled = "Cancelled"

    var icon: String {
        switch self {
        case .onTrack: return "checkmark.circle"
        case .atRisk: return "exclamationmark.triangle"
        case .behind: return "exclamationmark.circle"
        case .achieved: return "star.fill"
        case .cancelled: return "xmark.circle"
        }
    }

    var color: String {
        switch self {
        case .onTrack: return "#4DE094"
        case .atRisk: return "#FFD700"
        case .behind: return "#FF4444"
        case .achieved: return "#3BDAFC"
        case .cancelled: return "#888888"
        }
    }
}

// MARK: - OKR Alignment

struct OKRAlignment: Identifiable {
    let id: UUID
    let objectiveId: UUID
    let parentObjectiveId: UUID
    let alignmentStrength: AlignmentStrength
    let notes: String?

    init(
        id: UUID = UUID(),
        objectiveId: UUID,
        parentObjectiveId: UUID,
        alignmentStrength: AlignmentStrength = .strong,
        notes: String? = nil
    ) {
        self.id = id
        self.objectiveId = objectiveId
        self.parentObjectiveId = parentObjectiveId
        self.alignmentStrength = alignmentStrength
        self.notes = notes
    }
}

enum AlignmentStrength: String, Codable, CaseIterable {
    case strong = "Strong"
    case moderate = "Moderate"
    case weak = "Weak"

    var color: String {
        switch self {
        case .strong: return "#4DE094"
        case .moderate: return "#FFD700"
        case .weak: return "#FF9933"
        }
    }
}
