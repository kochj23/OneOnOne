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

    private init() {
        loadData()
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

        print("DataStore loaded: \(people.count) people, \(meetings.count) meetings, \(goals.count) goals")
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

        lastSyncDate = Date()
        print("DataStore saved")
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

    func updateActionItem(_ actionItem: ActionItem, in meetingId: UUID) {
        if let meetingIndex = meetings.firstIndex(where: { $0.id == meetingId }),
           let itemIndex = meetings[meetingIndex].actionItems.firstIndex(where: { $0.id == actionItem.id }) {
            meetings[meetingIndex].actionItems[itemIndex] = actionItem
            saveData()
        }
    }

    // MARK: - Export/Import

    func exportData() -> Data? {
        let exportData = ExportData(
            people: people,
            meetings: meetings,
            goals: goals,
            exportDate: Date(),
            version: "1.0"
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
}

// MARK: - Export Data Structure

struct ExportData: Codable {
    let people: [Person]
    let meetings: [Meeting]
    let goals: [Goal]
    let exportDate: Date
    let version: String
}
