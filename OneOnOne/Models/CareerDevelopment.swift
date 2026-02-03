//
//  CareerDevelopment.swift
//  OneOnOne
//
//  Career development tracking models
//  Created by Jordan Koch on 2026-02-02.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation

// MARK: - Skill

struct Skill: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var category: SkillCategory
    var level: SkillLevel
    var targetLevel: SkillLevel?
    var notes: String?
    var lastAssessed: Date
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        category: SkillCategory = .technical,
        level: SkillLevel = .beginner,
        targetLevel: SkillLevel? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.level = level
        self.targetLevel = targetLevel
        self.notes = notes
        self.lastAssessed = Date()
        self.createdAt = Date()
    }

    var hasGap: Bool {
        guard let target = targetLevel else { return false }
        return level.rawValue < target.rawValue
    }

    var gapSize: Int {
        guard let target = targetLevel else { return 0 }
        return max(0, target.rawValue - level.rawValue)
    }
}

enum SkillCategory: String, Codable, CaseIterable {
    case technical = "Technical"
    case leadership = "Leadership"
    case communication = "Communication"
    case problemSolving = "Problem Solving"
    case collaboration = "Collaboration"
    case domainKnowledge = "Domain Knowledge"
    case projectManagement = "Project Management"
    case other = "Other"

    var icon: String {
        switch self {
        case .technical: return "wrench.and.screwdriver"
        case .leadership: return "person.3.fill"
        case .communication: return "bubble.left.and.bubble.right"
        case .problemSolving: return "puzzlepiece.fill"
        case .collaboration: return "person.2.fill"
        case .domainKnowledge: return "book.fill"
        case .projectManagement: return "chart.gantt"
        case .other: return "ellipsis.circle"
        }
    }

    var color: String {
        switch self {
        case .technical: return "#3BDAFC"
        case .leadership: return "#9966FF"
        case .communication: return "#FF5999"
        case .problemSolving: return "#FF9933"
        case .collaboration: return "#4DE094"
        case .domainKnowledge: return "#5AB3FF"
        case .projectManagement: return "#FFD700"
        case .other: return "#888888"
        }
    }
}

enum SkillLevel: Int, Codable, CaseIterable {
    case beginner = 1
    case developing = 2
    case proficient = 3
    case advanced = 4
    case expert = 5

    var name: String {
        switch self {
        case .beginner: return "Beginner"
        case .developing: return "Developing"
        case .proficient: return "Proficient"
        case .advanced: return "Advanced"
        case .expert: return "Expert"
        }
    }

    var description: String {
        switch self {
        case .beginner: return "Learning the basics"
        case .developing: return "Building competency"
        case .proficient: return "Solid understanding, works independently"
        case .advanced: return "Deep expertise, mentors others"
        case .expert: return "Industry-recognized expertise"
        }
    }
}

// MARK: - Training

struct Training: Identifiable, Codable {
    let id: UUID
    var title: String
    var description: String?
    var type: TrainingType
    var provider: String?
    var url: String?
    var relatedSkills: [UUID] // Skill IDs
    var status: TrainingStatus
    var startDate: Date?
    var completionDate: Date?
    var certificateUrl: String?
    var notes: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        description: String? = nil,
        type: TrainingType = .course,
        provider: String? = nil,
        url: String? = nil,
        relatedSkills: [UUID] = [],
        status: TrainingStatus = .notStarted
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.type = type
        self.provider = provider
        self.url = url
        self.relatedSkills = relatedSkills
        self.status = status
        self.startDate = nil
        self.completionDate = nil
        self.certificateUrl = nil
        self.notes = nil
        self.createdAt = Date()
    }
}

enum TrainingType: String, Codable, CaseIterable {
    case course = "Course"
    case certification = "Certification"
    case book = "Book"
    case workshop = "Workshop"
    case conference = "Conference"
    case mentorship = "Mentorship"
    case project = "Project"
    case other = "Other"

    var icon: String {
        switch self {
        case .course: return "play.rectangle"
        case .certification: return "checkmark.seal"
        case .book: return "book"
        case .workshop: return "person.3"
        case .conference: return "building.2"
        case .mentorship: return "person.2"
        case .project: return "hammer"
        case .other: return "ellipsis.circle"
        }
    }
}

enum TrainingStatus: String, Codable, CaseIterable {
    case notStarted = "Not Started"
    case inProgress = "In Progress"
    case completed = "Completed"
    case onHold = "On Hold"
    case cancelled = "Cancelled"

    var color: String {
        switch self {
        case .notStarted: return "#888888"
        case .inProgress: return "#3BDAFC"
        case .completed: return "#4DE094"
        case .onHold: return "#FF9933"
        case .cancelled: return "#FF4444"
        }
    }
}

// MARK: - Career Profile

struct CareerProfile: Identifiable, Codable {
    let id: UUID
    var personId: UUID
    var currentRole: String?
    var targetRole: String?
    var careerGoals: String?
    var skills: [Skill]
    var trainings: [Training]
    var strengths: [String]
    var areasForGrowth: [String]
    var promotionReadiness: PromotionReadiness
    var lastReviewDate: Date?
    var nextReviewDate: Date?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        personId: UUID,
        currentRole: String? = nil,
        targetRole: String? = nil,
        careerGoals: String? = nil,
        skills: [Skill] = [],
        trainings: [Training] = [],
        strengths: [String] = [],
        areasForGrowth: [String] = []
    ) {
        self.id = id
        self.personId = personId
        self.currentRole = currentRole
        self.targetRole = targetRole
        self.careerGoals = careerGoals
        self.skills = skills
        self.trainings = trainings
        self.strengths = strengths
        self.areasForGrowth = areasForGrowth
        self.promotionReadiness = .notReady
        self.lastReviewDate = nil
        self.nextReviewDate = nil
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var skillGapCount: Int {
        skills.filter { $0.hasGap }.count
    }

    var completedTrainings: Int {
        trainings.filter { $0.status == .completed }.count
    }

    var inProgressTrainings: Int {
        trainings.filter { $0.status == .inProgress }.count
    }
}

enum PromotionReadiness: String, Codable, CaseIterable {
    case notReady = "Not Ready"
    case developing = "Developing"
    case almostReady = "Almost Ready"
    case ready = "Ready"
    case exceeding = "Exceeding"

    var color: String {
        switch self {
        case .notReady: return "#888888"
        case .developing: return "#FF9933"
        case .almostReady: return "#FFD700"
        case .ready: return "#4DE094"
        case .exceeding: return "#3BDAFC"
        }
    }

    var description: String {
        switch self {
        case .notReady: return "Needs significant development"
        case .developing: return "Making progress toward readiness"
        case .almostReady: return "Close to meeting requirements"
        case .ready: return "Meets all requirements for promotion"
        case .exceeding: return "Exceeds requirements, high potential"
        }
    }
}
