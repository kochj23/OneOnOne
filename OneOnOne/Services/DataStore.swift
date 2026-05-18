//
//  DataStore.swift
//  OneOnOne
//
//  Central data store for all app data with persistence
//  Created by Jordan Koch on 2026-02-02.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation
import Combine

@MainActor
class DataStore: ObservableObject {
    static let shared = DataStore()

    // MARK: - Published Data

    @Published var people: [Person] = []
    @Published var meetings: [Meeting] = []
    @Published var goals: [Goal] = []
    @Published var templates: [MeetingTemplate] = []
    @Published var feedback: [Feedback] = []
    @Published var careerProfiles: [UUID: CareerProfile] = [:]
    @Published var sentimentHistory: [UUID: [SentimentEntry]] = [:]
    @Published var objectives: [Objective] = []
    @Published var recordings: [Recording] = []
    @Published var isLoading = false
    @Published var lastSyncDate: Date?

    // MARK: - Persistence

    private let fileManager = FileManager.default
    private var dataDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("OneOnOne", isDirectory: true)
        try? fileManager.createDirectory(at: appDir, withIntermediateDirectories: true)
        return appDir
    }

    private var peopleFile: URL { dataDirectory.appendingPathComponent("people.json") }
    private var meetingsFile: URL { dataDirectory.appendingPathComponent("meetings.json") }
    private var goalsFile: URL { dataDirectory.appendingPathComponent("goals.json") }
    private var templatesFile: URL { dataDirectory.appendingPathComponent("templates.json") }
    private var feedbackFile: URL { dataDirectory.appendingPathComponent("feedback.json") }
    private var careerProfilesFile: URL { dataDirectory.appendingPathComponent("career_profiles.json") }
    private var sentimentFile: URL { dataDirectory.appendingPathComponent("sentiment.json") }
    private var objectivesFile: URL { dataDirectory.appendingPathComponent("objectives.json") }
    private var recordingsFile: URL { dataDirectory.appendingPathComponent("recordings.json") }

    private init() {
        loadData()
        loadBuiltInTemplates()
    }

    // MARK: - Data Loading

    func loadData() {
        isLoading = true
        defer { isLoading = false }

        // Load people
        if let data = try? Data(contentsOf: peopleFile),
           let decoded = try? JSONDecoder().decode([Person].self, from: data) {
            people = decoded
        }

        // Load meetings
        if let data = try? Data(contentsOf: meetingsFile),
           let decoded = try? JSONDecoder().decode([Meeting].self, from: data) {
            meetings = decoded
        }

        // Load goals
        if let data = try? Data(contentsOf: goalsFile),
           let decoded = try? JSONDecoder().decode([Goal].self, from: data) {
            goals = decoded
        }

        // Load templates
        if let data = try? Data(contentsOf: templatesFile),
           let decoded = try? JSONDecoder().decode([MeetingTemplate].self, from: data) {
            templates = decoded
        }

        // Load feedback
        if let data = try? Data(contentsOf: feedbackFile),
           let decoded = try? JSONDecoder().decode([Feedback].self, from: data) {
            feedback = decoded
        }

        // Load career profiles
        if let data = try? Data(contentsOf: careerProfilesFile),
           let decoded = try? JSONDecoder().decode([UUID: CareerProfile].self, from: data) {
            careerProfiles = decoded
        }

        // Load sentiment history
        if let data = try? Data(contentsOf: sentimentFile),
           let decoded = try? JSONDecoder().decode([UUID: [SentimentEntry]].self, from: data) {
            sentimentHistory = decoded
        }

        // Load objectives
        if let data = try? Data(contentsOf: objectivesFile),
           let decoded = try? JSONDecoder().decode([Objective].self, from: data) {
            objectives = decoded
        }

        // Load recordings
        if let data = try? Data(contentsOf: recordingsFile),
           let decoded = try? JSONDecoder().decode([Recording].self, from: data) {
            recordings = decoded
        }

        print("DataStore loaded: \(people.count) people, \(meetings.count) meetings, \(goals.count) goals")
    }

    private func loadBuiltInTemplates() {
        // Add built-in templates if none exist
        if templates.isEmpty {
            templates = MeetingTemplate.builtInTemplates
        }
    }

    func saveData() {
        // Save people
        if let data = try? JSONEncoder().encode(people) {
            try? data.write(to: peopleFile)
        }

        // Save meetings
        if let data = try? JSONEncoder().encode(meetings) {
            try? data.write(to: meetingsFile)
        }

        // Save goals
        if let data = try? JSONEncoder().encode(goals) {
            try? data.write(to: goalsFile)
        }

        // Save templates
        if let data = try? JSONEncoder().encode(templates) {
            try? data.write(to: templatesFile)
        }

        // Save feedback
        if let data = try? JSONEncoder().encode(feedback) {
            try? data.write(to: feedbackFile)
        }

        // Save career profiles
        if let data = try? JSONEncoder().encode(careerProfiles) {
            try? data.write(to: careerProfilesFile)
        }

        // Save sentiment history
        if let data = try? JSONEncoder().encode(sentimentHistory) {
            try? data.write(to: sentimentFile)
        }

        // Save objectives
        if let data = try? JSONEncoder().encode(objectives) {
            try? data.write(to: objectivesFile)
        }

        // Save recordings
        if let data = try? JSONEncoder().encode(recordings) {
            try? data.write(to: recordingsFile)
        }

        lastSyncDate = Date()
        print("DataStore saved")

        // Sync data to widget
        WidgetSyncService.shared.syncToWidget()

        // Trigger debounced CloudKit push (skipped when we're applying cloud changes locally)
        if !CloudKitService.shared.isFetchingFromCloud {
            CloudKitService.shared.schedulePush()
        }
    }

    // MARK: - Person Operations

    func addPerson(_ person: Person) {
        people.append(person)
        saveData()
    }

    func updatePerson(_ person: Person) {
        if let index = people.firstIndex(where: { $0.id == person.id }) {
            var updated = person
            updated.updatedAt = Date()
            people[index] = updated
            saveData()
        }
    }

    func deletePerson(id: UUID) {
        people.removeAll { $0.id == id }
        // Also remove from meeting attendees
        for i in meetings.indices {
            meetings[i].attendees.removeAll { $0 == id }
        }
        // Remove career profile and sentiment history
        careerProfiles.removeValue(forKey: id)
        sentimentHistory.removeValue(forKey: id)
        saveData()
    }

    func person(for id: UUID) -> Person? {
        people.first { $0.id == id }
    }

    // MARK: - Meeting Operations

    func addMeeting(_ meeting: Meeting) {
        meetings.append(meeting)
        // Update person's last meeting date
        for attendeeId in meeting.attendees {
            if let index = people.firstIndex(where: { $0.id == attendeeId }) {
                people[index].lastMeetingDate = meeting.date
            }
        }
        saveData()
    }

    func updateMeeting(_ meeting: Meeting) {
        if let index = meetings.firstIndex(where: { $0.id == meeting.id }) {
            var updated = meeting
            updated.updatedAt = Date()
            meetings[index] = updated
            saveData()
        }
    }

    func deleteMeeting(id: UUID) {
        meetings.removeAll { $0.id == id }
        // Also remove from goal related meetings
        for i in goals.indices {
            goals[i].relatedMeetingIds.removeAll { $0 == id }
        }
        saveData()
    }

    func meetings(for personId: UUID) -> [Meeting] {
        meetings.filter { $0.attendees.contains(personId) }
            .sorted { $0.date > $1.date }
    }

    func recentMeetings(limit: Int = 10) -> [Meeting] {
        Array(meetings.sorted { $0.date > $1.date }.prefix(limit))
    }

    func upcomingMeetings(limit: Int = 10) -> [Meeting] {
        let now = Date()
        return Array(
            meetings
                .filter { $0.date > now }
                .sorted { $0.date < $1.date }
                .prefix(limit)
        )
    }

    // MARK: - Goal Operations

    func addGoal(_ goal: Goal) {
        goals.append(goal)
        saveData()
    }

    func updateGoal(_ goal: Goal) {
        if let index = goals.firstIndex(where: { $0.id == goal.id }) {
            var updated = goal
            updated.updatedAt = Date()
            goals[index] = updated
            saveData()
        }
    }

    func deleteGoal(id: UUID) {
        goals.removeAll { $0.id == id }
        saveData()
    }

    func goals(for personId: UUID) -> [Goal] {
        goals.filter { $0.personId == personId }
    }

    func activeGoals() -> [Goal] {
        goals.filter { $0.status == .inProgress || $0.status == .notStarted }
    }

    // MARK: - Action Item Operations

    func allActionItems() -> [ActionItem] {
        meetings.flatMap { $0.actionItems }
    }

    func openActionItems() -> [ActionItem] {
        allActionItems().filter { !$0.isCompleted }
            .sorted { $0.priority.sortOrder < $1.priority.sortOrder }
    }

    func actionItems(for personId: UUID) -> [ActionItem] {
        allActionItems().filter { $0.assigneeId == personId }
    }

    func addActionItem(_ actionItem: ActionItem, to meetingId: UUID) {
        if let meetingIndex = meetings.firstIndex(where: { $0.id == meetingId }) {
            meetings[meetingIndex].actionItems.append(actionItem)
            saveData()
        }
    }

    func updateActionItem(_ actionItem: ActionItem, in meetingId: UUID) {
        if let meetingIndex = meetings.firstIndex(where: { $0.id == meetingId }),
           let itemIndex = meetings[meetingIndex].actionItems.firstIndex(where: { $0.id == actionItem.id }) {
            meetings[meetingIndex].actionItems[itemIndex] = actionItem
            saveData()
        }
    }

    func deleteActionItem(_ actionItemId: UUID, from meetingId: UUID) {
        if let meetingIndex = meetings.firstIndex(where: { $0.id == meetingId }) {
            meetings[meetingIndex].actionItems.removeAll { $0.id == actionItemId }
            saveData()
        }
    }

    // MARK: - Template Operations

    func addTemplate(_ template: MeetingTemplate) {
        templates.append(template)
        saveData()
    }

    func updateTemplate(_ template: MeetingTemplate) {
        if let index = templates.firstIndex(where: { $0.id == template.id }) {
            templates[index] = template
            saveData()
        }
    }

    func deleteTemplate(id: UUID) {
        templates.removeAll { $0.id == id }
        saveData()
    }

    func customTemplates() -> [MeetingTemplate] {
        templates.filter { !$0.isBuiltIn }
    }

    // MARK: - Feedback Operations

    func addFeedback(_ item: Feedback) {
        feedback.append(item)
        saveData()
    }

    func updateFeedback(_ item: Feedback) {
        if let index = feedback.firstIndex(where: { $0.id == item.id }) {
            feedback[index] = item
            saveData()
        }
    }

    func deleteFeedback(id: UUID) {
        feedback.removeAll { $0.id == id }
        saveData()
    }

    func feedback(for personId: UUID) -> [Feedback] {
        feedback.filter { $0.personId == personId }
            .sorted { $0.date > $1.date }
    }

    func recentFeedback(limit: Int = 10) -> [Feedback] {
        Array(feedback.sorted { $0.date > $1.date }.prefix(limit))
    }

    // MARK: - Career Profile Operations

    func careerProfile(for personId: UUID) -> CareerProfile? {
        careerProfiles[personId]
    }

    func updateCareerProfile(_ profile: CareerProfile, for personId: UUID) {
        var updated = profile
        updated.updatedAt = Date()
        careerProfiles[personId] = updated
        saveData()
    }

    func createCareerProfile(for personId: UUID) -> CareerProfile {
        let profile = CareerProfile(personId: personId)
        careerProfiles[personId] = profile
        saveData()
        return profile
    }

    // MARK: - Sentiment Operations

    func addSentimentEntry(_ entry: SentimentEntry, for personId: UUID) {
        var history = sentimentHistory[personId] ?? []
        history.append(entry)
        sentimentHistory[personId] = history
        saveData()
    }

    func sentimentEntries(for personId: UUID) -> [SentimentEntry] {
        sentimentHistory[personId] ?? []
    }

    func latestSentiment(for personId: UUID) -> SentimentEntry? {
        sentimentHistory[personId]?.sorted { $0.date > $1.date }.first
    }

    func relationshipHealth(for personId: UUID) -> RelationshipHealth {
        let history = sentimentEntries(for: personId)
        // Normalize sentiment score from 1-5 to 0-1 scale
        let normalizedScore: (SentimentEntry) -> Double = { Double($0.sentiment.rawValue - 1) / 4.0 }
        let healthScore = history.isEmpty ? 0.5 : history.map(normalizedScore).reduce(0, +) / Double(history.count)
        let trend: HealthTrend = {
            guard history.count >= 2 else { return .stable }
            let recent = history.prefix(3).map(normalizedScore)
            let older = history.dropFirst(3).prefix(3).map(normalizedScore)
            guard !older.isEmpty else { return .stable }
            let recentAvg = recent.reduce(0, +) / Double(recent.count)
            let olderAvg = older.reduce(0, +) / Double(older.count)
            if recentAvg > olderAvg + 0.1 { return .improving }
            if recentAvg < olderAvg - 0.1 { return .declining }
            return .stable
        }()
        return RelationshipHealth(
            id: UUID(),
            personId: personId,
            healthScore: healthScore,
            trend: trend,
            sentimentHistory: history,
            riskFactors: [],
            recommendations: []
        )
    }

    // MARK: - OKR Operations

    func addObjective(_ objective: Objective) {
        objectives.append(objective)
        saveData()
    }

    func updateObjective(_ objective: Objective) {
        if let index = objectives.firstIndex(where: { $0.id == objective.id }) {
            var updated = objective
            updated.updatedAt = Date()
            objectives[index] = updated
            saveData()
        }
    }

    func deleteObjective(id: UUID) {
        objectives.removeAll { $0.id == id }
        saveData()
    }

    func objectives(for personId: UUID) -> [Objective] {
        objectives.filter { $0.ownerId == personId }
    }

    func teamObjectives() -> [Objective] {
        objectives.filter { $0.ownerId == nil }
    }

    func activeObjectives() -> [Objective] {
        // Get current quarter string
        let calendar = Calendar.current
        let now = Date()
        let quarter = (calendar.component(.month, from: now) - 1) / 3 + 1
        let year = calendar.component(.year, from: now)
        let currentQuarter = "Q\(quarter) \(year)"
        return objectives.filter { $0.quarter == currentQuarter && $0.status != .achieved && $0.status != .cancelled }
    }

    // MARK: - Recording Operations

    func addRecording(_ recording: Recording) {
        recordings.append(recording)
        saveData()
    }

    func updateRecording(_ recording: Recording) {
        if let index = recordings.firstIndex(where: { $0.id == recording.id }) {
            recordings[index] = recording
            saveData()
        }
    }

    func deleteRecording(id: UUID) {
        recordings.removeAll { $0.id == id }
        saveData()
    }

    func recordings(for meetingId: UUID) -> [Recording] {
        recordings.filter { $0.meetingId == meetingId }
    }

    // MARK: - Export/Import

    func exportData() -> Data? {
        let exportData = ExportData(
            people: people,
            meetings: meetings,
            goals: goals,
            templates: templates,
            feedback: feedback,
            careerProfiles: careerProfiles,
            sentimentHistory: sentimentHistory,
            objectives: objectives,
            recordings: recordings,
            exportDate: Date(),
            version: "1.1"
        )
        return try? JSONEncoder().encode(exportData)
    }

    func importData(from data: Data) throws {
        let imported = try JSONDecoder().decode(ExportData.self, from: data)

        // Merge data (don't overwrite existing)
        for person in imported.people {
            if !people.contains(where: { $0.id == person.id }) {
                people.append(person)
            }
        }

        for meeting in imported.meetings {
            if !meetings.contains(where: { $0.id == meeting.id }) {
                meetings.append(meeting)
            }
        }

        for goal in imported.goals {
            if !goals.contains(where: { $0.id == goal.id }) {
                goals.append(goal)
            }
        }

        for template in imported.templates {
            if !templates.contains(where: { $0.id == template.id }) {
                templates.append(template)
            }
        }

        for item in imported.feedback {
            if !feedback.contains(where: { $0.id == item.id }) {
                feedback.append(item)
            }
        }

        for (personId, profile) in imported.careerProfiles {
            if careerProfiles[personId] == nil {
                careerProfiles[personId] = profile
            }
        }

        for (personId, entries) in imported.sentimentHistory {
            var existing = sentimentHistory[personId] ?? []
            for entry in entries {
                if !existing.contains(where: { $0.id == entry.id }) {
                    existing.append(entry)
                }
            }
            sentimentHistory[personId] = existing
        }

        for objective in imported.objectives {
            if !objectives.contains(where: { $0.id == objective.id }) {
                objectives.append(objective)
            }
        }

        for recording in imported.recordings {
            if !recordings.contains(where: { $0.id == recording.id }) {
                recordings.append(recording)
            }
        }

        saveData()
    }

    // MARK: - Statistics

    var totalMeetingsThisWeek: Int {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return meetings.filter { $0.date >= weekAgo && $0.date <= Date() }.count
    }

    var totalMeetingsThisMonth: Int {
        let monthAgo = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        return meetings.filter { $0.date >= monthAgo && $0.date <= Date() }.count
    }

    var overdueActionItems: [ActionItem] {
        openActionItems().filter { $0.isOverdue }
    }

    var totalFeedbackThisMonth: Int {
        let monthAgo = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        return feedback.filter { $0.date >= monthAgo }.count
    }
}

// MARK: - Export Data Structure

struct ExportData: Codable {
    let people: [Person]
    let meetings: [Meeting]
    let goals: [Goal]
    let templates: [MeetingTemplate]
    let feedback: [Feedback]
    let careerProfiles: [UUID: CareerProfile]
    let sentimentHistory: [UUID: [SentimentEntry]]
    let objectives: [Objective]
    let recordings: [Recording]
    let exportDate: Date
    let version: String

    init(
        people: [Person],
        meetings: [Meeting],
        goals: [Goal],
        templates: [MeetingTemplate] = [],
        feedback: [Feedback] = [],
        careerProfiles: [UUID: CareerProfile] = [:],
        sentimentHistory: [UUID: [SentimentEntry]] = [:],
        objectives: [Objective] = [],
        recordings: [Recording] = [],
        exportDate: Date,
        version: String
    ) {
        self.people = people
        self.meetings = meetings
        self.goals = goals
        self.templates = templates
        self.feedback = feedback
        self.careerProfiles = careerProfiles
        self.sentimentHistory = sentimentHistory
        self.objectives = objectives
        self.recordings = recordings
        self.exportDate = exportDate
        self.version = version
    }
}
