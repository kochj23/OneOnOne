//
//  Template.swift
//  OneOnOne
//
//  Meeting template model for reusable meeting structures
//  Created by Jordan Koch on 2026-02-02.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation

struct MeetingTemplate: Identifiable, Codable {
    let id: UUID
    var name: String
    var description: String?
    var meetingType: MeetingType
    var defaultDuration: TimeInterval
    var agendaItems: [AgendaItem]
    var suggestedQuestions: [String]
    var isBuiltIn: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        meetingType: MeetingType = .oneOnOne,
        defaultDuration: TimeInterval = 3600,
        agendaItems: [AgendaItem] = [],
        suggestedQuestions: [String] = [],
        isBuiltIn: Bool = false
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.meetingType = meetingType
        self.defaultDuration = defaultDuration
        self.agendaItems = agendaItems
        self.suggestedQuestions = suggestedQuestions
        self.isBuiltIn = isBuiltIn
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    func generateAgenda() -> String {
        agendaItems.enumerated().map { index, item in
            "\(index + 1). \(item.title)" + (item.duration > 0 ? " (\(Int(item.duration / 60)) min)" : "")
        }.joined(separator: "\n")
    }
}

struct AgendaItem: Identifiable, Codable {
    let id: UUID
    var title: String
    var description: String?
    var duration: TimeInterval // in seconds
    var isRequired: Bool

    init(
        id: UUID = UUID(),
        title: String,
        description: String? = nil,
        duration: TimeInterval = 0,
        isRequired: Bool = false
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.duration = duration
        self.isRequired = isRequired
    }
}

// MARK: - Built-in Templates

extension MeetingTemplate {
    static let builtInTemplates: [MeetingTemplate] = [
        // 1:1 Check-in
        MeetingTemplate(
            name: "1:1 Check-in",
            description: "Regular check-in meeting with direct reports",
            meetingType: .oneOnOne,
            defaultDuration: 1800, // 30 min
            agendaItems: [
                AgendaItem(title: "How are you doing?", duration: 300, isRequired: true),
                AgendaItem(title: "Updates since last meeting", duration: 300),
                AgendaItem(title: "Blockers and challenges", duration: 300, isRequired: true),
                AgendaItem(title: "Goals progress", duration: 300),
                AgendaItem(title: "Action items review", duration: 300),
                AgendaItem(title: "Anything else?", duration: 300)
            ],
            suggestedQuestions: [
                "What's been the highlight of your week?",
                "Is there anything blocking your progress?",
                "How can I better support you?",
                "What would you like to focus on next?",
                "Any feedback for me?"
            ],
            isBuiltIn: true
        ),

        // Performance Review
        MeetingTemplate(
            name: "Performance Review",
            description: "Quarterly or annual performance discussion",
            meetingType: .review,
            defaultDuration: 3600, // 1 hour
            agendaItems: [
                AgendaItem(title: "Review period accomplishments", duration: 600, isRequired: true),
                AgendaItem(title: "Goals assessment", duration: 600, isRequired: true),
                AgendaItem(title: "Strengths discussion", duration: 300),
                AgendaItem(title: "Areas for growth", duration: 300),
                AgendaItem(title: "Career development", duration: 600),
                AgendaItem(title: "Goals for next period", duration: 600, isRequired: true),
                AgendaItem(title: "Feedback exchange", duration: 300)
            ],
            suggestedQuestions: [
                "What are you most proud of this period?",
                "What challenges did you face and how did you handle them?",
                "Where do you want to grow?",
                "What skills would you like to develop?",
                "Where do you see yourself in 6-12 months?"
            ],
            isBuiltIn: true
        ),

        // Project Kickoff
        MeetingTemplate(
            name: "Project Kickoff",
            description: "Start a new project with the team",
            meetingType: .planning,
            defaultDuration: 3600,
            agendaItems: [
                AgendaItem(title: "Project overview and goals", duration: 600, isRequired: true),
                AgendaItem(title: "Stakeholders and roles", duration: 300),
                AgendaItem(title: "Timeline and milestones", duration: 600, isRequired: true),
                AgendaItem(title: "Resources and constraints", duration: 300),
                AgendaItem(title: "Risks and mitigation", duration: 300),
                AgendaItem(title: "Success criteria", duration: 300, isRequired: true),
                AgendaItem(title: "Questions and next steps", duration: 600)
            ],
            suggestedQuestions: [
                "What does success look like?",
                "What are the biggest risks?",
                "Who needs to be involved?",
                "What dependencies do we have?",
                "What's our communication plan?"
            ],
            isBuiltIn: true
        ),

        // Team Stand-up
        MeetingTemplate(
            name: "Daily Stand-up",
            description: "Quick daily sync with the team",
            meetingType: .standUp,
            defaultDuration: 900, // 15 min
            agendaItems: [
                AgendaItem(title: "What did you accomplish yesterday?", duration: 300, isRequired: true),
                AgendaItem(title: "What will you work on today?", duration: 300, isRequired: true),
                AgendaItem(title: "Any blockers?", duration: 300, isRequired: true)
            ],
            suggestedQuestions: [],
            isBuiltIn: true
        ),

        // Retrospective
        MeetingTemplate(
            name: "Sprint Retrospective",
            description: "Reflect on the sprint and identify improvements",
            meetingType: .retrospective,
            defaultDuration: 3600,
            agendaItems: [
                AgendaItem(title: "What went well?", duration: 900, isRequired: true),
                AgendaItem(title: "What didn't go well?", duration: 900, isRequired: true),
                AgendaItem(title: "What can we improve?", duration: 900, isRequired: true),
                AgendaItem(title: "Action items", duration: 600, isRequired: true)
            ],
            suggestedQuestions: [
                "What should we keep doing?",
                "What should we stop doing?",
                "What should we start doing?",
                "What was our biggest win?",
                "What was our biggest challenge?"
            ],
            isBuiltIn: true
        ),

        // Career Development
        MeetingTemplate(
            name: "Career Development",
            description: "Discuss career growth and development plans",
            meetingType: .oneOnOne,
            defaultDuration: 3600,
            agendaItems: [
                AgendaItem(title: "Career aspirations", duration: 600, isRequired: true),
                AgendaItem(title: "Current skills assessment", duration: 600),
                AgendaItem(title: "Skills to develop", duration: 600, isRequired: true),
                AgendaItem(title: "Learning opportunities", duration: 600),
                AgendaItem(title: "Timeline and milestones", duration: 600),
                AgendaItem(title: "Support needed", duration: 300)
            ],
            suggestedQuestions: [
                "Where do you see yourself in 1-2 years?",
                "What skills are most important for your goals?",
                "What training or resources would help?",
                "What projects would help you grow?",
                "How can I support your development?"
            ],
            isBuiltIn: true
        ),

        // Skip Level
        MeetingTemplate(
            name: "Skip Level",
            description: "Meeting with indirect reports",
            meetingType: .oneOnOne,
            defaultDuration: 1800,
            agendaItems: [
                AgendaItem(title: "How are things going?", duration: 300, isRequired: true),
                AgendaItem(title: "Team dynamics", duration: 300),
                AgendaItem(title: "Manager effectiveness", duration: 300),
                AgendaItem(title: "Growth and development", duration: 300),
                AgendaItem(title: "Questions for me", duration: 300)
            ],
            suggestedQuestions: [
                "How is your team working together?",
                "Is there anything you'd like me to know?",
                "How can leadership better support you?",
                "What would make your job easier?",
                "Any concerns you'd like to discuss?"
            ],
            isBuiltIn: true
        ),

        // Interview
        MeetingTemplate(
            name: "Interview",
            description: "Candidate interview structure",
            meetingType: .interview,
            defaultDuration: 3600,
            agendaItems: [
                AgendaItem(title: "Introduction and role overview", duration: 300, isRequired: true),
                AgendaItem(title: "Background and experience", duration: 600),
                AgendaItem(title: "Technical/Role-specific questions", duration: 1200, isRequired: true),
                AgendaItem(title: "Behavioral questions", duration: 900),
                AgendaItem(title: "Candidate questions", duration: 600, isRequired: true),
                AgendaItem(title: "Next steps", duration: 300)
            ],
            suggestedQuestions: [
                "Tell me about yourself",
                "Why are you interested in this role?",
                "Describe a challenging situation and how you handled it",
                "What are your strengths and areas for growth?",
                "Where do you see yourself in 5 years?"
            ],
            isBuiltIn: true
        )
    ]
}
