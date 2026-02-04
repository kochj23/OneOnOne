//
//  CloudKitService.swift
//  OneOnOne
//
//  CloudKit sync service for iCloud synchronization across devices
//  Created by Jordan Koch on 2026-02-04.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation
import CloudKit
import Combine

/// CloudKit-based sync service for cross-device synchronization via iCloud
@MainActor
class CloudKitService: ObservableObject {
    static let shared = CloudKitService()

    // MARK: - Published Properties

    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?
    @Published var isCloudAvailable = false

    // MARK: - CloudKit Properties

    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let zoneID: CKRecordZone.ID
    private let subscriptionID = "OneOnOne-Changes"

    // Record types
    private enum RecordType: String {
        case person = "Person"
        case meeting = "Meeting"
        case goal = "Goal"
        case template = "MeetingTemplate"
        case feedback = "Feedback"
        case careerProfile = "CareerProfile"
        case sentimentEntry = "SentimentEntry"
        case objective = "Objective"
        case recording = "Recording"
        case syncMetadata = "SyncMetadata"
    }

    // MARK: - Initialization

    private init() {
        container = CKContainer(identifier: "iCloud.com.jordankoch.OneOnOne")
        privateDatabase = container.privateCloudDatabase
        zoneID = CKRecordZone.ID(zoneName: "OneOnOneZone", ownerName: CKCurrentUserDefaultName)

        Task {
            await checkCloudAvailability()
            await setupCloudKit()
        }
    }

    // MARK: - Setup

    private func checkCloudAvailability() async {
        do {
            let status = try await container.accountStatus()
            isCloudAvailable = status == .available
            if !isCloudAvailable {
                syncError = "iCloud account not available. Sign in to iCloud to enable sync."
            }
        } catch {
            isCloudAvailable = false
            syncError = "Could not check iCloud status: \(error.localizedDescription)"
        }
    }

    private func setupCloudKit() async {
        guard isCloudAvailable else { return }

        // Create custom zone
        let zone = CKRecordZone(zoneID: zoneID)
        do {
            try await privateDatabase.save(zone)
        } catch let error as CKError where error.code == .serverRecordChanged {
            // Zone already exists, that's fine
        } catch {
            print("Failed to create zone: \(error)")
        }

        // Subscribe to changes
        await subscribeToChanges()
    }

    private func subscribeToChanges() async {
        let subscription = CKDatabaseSubscription(subscriptionID: subscriptionID)

        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo

        do {
            try await privateDatabase.save(subscription)
        } catch let error as CKError where error.code == .serverRecordChanged {
            // Subscription already exists
        } catch {
            print("Failed to subscribe to changes: \(error)")
        }
    }

    // MARK: - Sync Operations

    /// Performs a full sync with iCloud
    func sync() async {
        guard isCloudAvailable else {
            syncError = "iCloud not available"
            return
        }

        isSyncing = true
        syncError = nil

        defer { isSyncing = false }

        do {
            // First, fetch changes from cloud
            try await fetchChanges()

            // Then push local changes
            try await pushChanges()

            lastSyncDate = Date()
            UserDefaults.standard.set(lastSyncDate, forKey: "lastCloudSyncDate")
        } catch {
            syncError = "Sync failed: \(error.localizedDescription)"
            print("Sync error: \(error)")
        }
    }

    /// Fetches changes from iCloud
    private func fetchChanges() async throws {
        let dataStore = DataStore.shared

        // Fetch people
        let peopleRecords = try await fetchRecords(ofType: .person)
        for record in peopleRecords {
            if let person = person(from: record) {
                if !dataStore.people.contains(where: { $0.id == person.id }) {
                    dataStore.people.append(person)
                } else if let existingIndex = dataStore.people.firstIndex(where: { $0.id == person.id }) {
                    // Update if cloud version is newer
                    if person.updatedAt > dataStore.people[existingIndex].updatedAt {
                        dataStore.people[existingIndex] = person
                    }
                }
            }
        }

        // Fetch meetings
        let meetingRecords = try await fetchRecords(ofType: .meeting)
        for record in meetingRecords {
            if let meeting = meeting(from: record) {
                if !dataStore.meetings.contains(where: { $0.id == meeting.id }) {
                    dataStore.meetings.append(meeting)
                } else if let existingIndex = dataStore.meetings.firstIndex(where: { $0.id == meeting.id }) {
                    if meeting.updatedAt > dataStore.meetings[existingIndex].updatedAt {
                        dataStore.meetings[existingIndex] = meeting
                    }
                }
            }
        }

        // Fetch goals
        let goalRecords = try await fetchRecords(ofType: .goal)
        for record in goalRecords {
            if let goal = goal(from: record) {
                if !dataStore.goals.contains(where: { $0.id == goal.id }) {
                    dataStore.goals.append(goal)
                } else if let existingIndex = dataStore.goals.firstIndex(where: { $0.id == goal.id }) {
                    if goal.updatedAt > dataStore.goals[existingIndex].updatedAt {
                        dataStore.goals[existingIndex] = goal
                    }
                }
            }
        }

        // Fetch objectives
        let objectiveRecords = try await fetchRecords(ofType: .objective)
        for record in objectiveRecords {
            if let objective = objective(from: record) {
                if !dataStore.objectives.contains(where: { $0.id == objective.id }) {
                    dataStore.objectives.append(objective)
                } else if let existingIndex = dataStore.objectives.firstIndex(where: { $0.id == objective.id }) {
                    if objective.updatedAt > dataStore.objectives[existingIndex].updatedAt {
                        dataStore.objectives[existingIndex] = objective
                    }
                }
            }
        }

        // Fetch feedback
        let feedbackRecords = try await fetchRecords(ofType: .feedback)
        for record in feedbackRecords {
            if let fb = feedback(from: record) {
                if !dataStore.feedback.contains(where: { $0.id == fb.id }) {
                    dataStore.feedback.append(fb)
                }
            }
        }

        // Save locally
        dataStore.saveData()
    }

    /// Pushes local changes to iCloud
    private func pushChanges() async throws {
        let dataStore = DataStore.shared

        // Push people
        for person in dataStore.people {
            let record = record(from: person)
            try await saveRecord(record)
        }

        // Push meetings
        for meeting in dataStore.meetings {
            let record = record(from: meeting)
            try await saveRecord(record)
        }

        // Push goals
        for goal in dataStore.goals {
            let record = record(from: goal)
            try await saveRecord(record)
        }

        // Push objectives
        for objective in dataStore.objectives {
            let record = record(from: objective)
            try await saveRecord(record)
        }

        // Push feedback
        for fb in dataStore.feedback {
            let record = record(from: fb)
            try await saveRecord(record)
        }
    }

    private func fetchRecords(ofType type: RecordType) async throws -> [CKRecord] {
        let query = CKQuery(recordType: type.rawValue, predicate: NSPredicate(value: true))
        let (records, _) = try await privateDatabase.records(matching: query, inZoneWith: zoneID)
        return records.compactMap { try? $0.1.get() }
    }

    private func saveRecord(_ record: CKRecord) async throws {
        do {
            try await privateDatabase.save(record)
        } catch let error as CKError where error.code == .serverRecordChanged {
            // Handle conflict by fetching server version and merging
            if let serverRecord = error.serverRecord {
                try await privateDatabase.save(serverRecord)
            }
        }
    }

    // MARK: - Record Conversion - Person

    private func record(from person: Person) -> CKRecord {
        let recordID = CKRecord.ID(recordName: person.id.uuidString, zoneID: zoneID)
        let record = CKRecord(recordType: RecordType.person.rawValue, recordID: recordID)

        record["name"] = person.name
        record["email"] = person.email
        record["title"] = person.title
        record["department"] = person.department
        record["notes"] = person.notes
        record["avatarColor"] = person.avatarColor
        record["tags"] = person.tags
        record["meetingFrequency"] = person.meetingFrequency.rawValue
        record["lastMeetingDate"] = person.lastMeetingDate
        record["nextScheduledMeeting"] = person.nextScheduledMeeting
        record["createdAt"] = person.createdAt
        record["updatedAt"] = person.updatedAt

        return record
    }

    private func person(from record: CKRecord) -> Person? {
        guard let idString = record.recordID.recordName.components(separatedBy: "-").first,
              let id = UUID(uuidString: record.recordID.recordName),
              let name = record["name"] as? String else {
            return nil
        }

        var person = Person(
            id: id,
            name: name,
            email: record["email"] as? String,
            title: record["title"] as? String,
            department: record["department"] as? String,
            notes: record["notes"] as? String
        )

        person.avatarColor = record["avatarColor"] as? String ?? "blue"
        person.tags = record["tags"] as? [String] ?? []
        if let freqString = record["meetingFrequency"] as? String,
           let freq = MeetingFrequency(rawValue: freqString) {
            person.meetingFrequency = freq
        }
        person.lastMeetingDate = record["lastMeetingDate"] as? Date
        person.nextScheduledMeeting = record["nextScheduledMeeting"] as? Date
        person.createdAt = record["createdAt"] as? Date ?? Date()
        person.updatedAt = record["updatedAt"] as? Date ?? Date()

        return person
    }

    // MARK: - Record Conversion - Meeting

    private func record(from meeting: Meeting) -> CKRecord {
        let recordID = CKRecord.ID(recordName: meeting.id.uuidString, zoneID: zoneID)
        let record = CKRecord(recordType: RecordType.meeting.rawValue, recordID: recordID)

        record["title"] = meeting.title
        record["date"] = meeting.date
        record["duration"] = meeting.duration
        record["attendeeIds"] = meeting.attendees.map { $0.uuidString }
        record["meetingType"] = meeting.meetingType.rawValue
        record["location"] = meeting.location
        record["agenda"] = meeting.agenda
        record["notes"] = meeting.notes
        record["summary"] = meeting.summary
        record["tags"] = meeting.tags
        record["mood"] = meeting.mood?.rawValue
        record["isRecurring"] = meeting.isRecurring
        record["calendarEventId"] = meeting.calendarEventId
        record["createdAt"] = meeting.createdAt
        record["updatedAt"] = meeting.updatedAt

        // Encode action items, decisions, follow-ups as JSON
        if let actionItemsData = try? JSONEncoder().encode(meeting.actionItems) {
            record["actionItemsData"] = String(data: actionItemsData, encoding: .utf8)
        }
        if let decisionsData = try? JSONEncoder().encode(meeting.decisions) {
            record["decisionsData"] = String(data: decisionsData, encoding: .utf8)
        }
        if let followUpsData = try? JSONEncoder().encode(meeting.followUps) {
            record["followUpsData"] = String(data: followUpsData, encoding: .utf8)
        }

        return record
    }

    private func meeting(from record: CKRecord) -> Meeting? {
        guard let id = UUID(uuidString: record.recordID.recordName),
              let title = record["title"] as? String,
              let date = record["date"] as? Date else {
            return nil
        }

        var meeting = Meeting(
            id: id,
            title: title,
            date: date,
            attendees: (record["attendeeIds"] as? [String])?.compactMap { UUID(uuidString: $0) } ?? []
        )

        meeting.duration = record["duration"] as? TimeInterval ?? 3600
        if let typeString = record["meetingType"] as? String,
           let type = MeetingType(rawValue: typeString) {
            meeting.meetingType = type
        }
        meeting.location = record["location"] as? String
        meeting.agenda = record["agenda"] as? String
        if let notes = record["notes"] as? String {
            meeting.notes = notes
        }
        meeting.summary = record["summary"] as? String
        meeting.tags = record["tags"] as? [String] ?? []
        if let moodString = record["mood"] as? String {
            meeting.mood = MeetingMood(rawValue: moodString)
        }
        meeting.isRecurring = record["isRecurring"] as? Bool ?? false
        meeting.calendarEventId = record["calendarEventId"] as? String
        meeting.createdAt = record["createdAt"] as? Date ?? Date()
        meeting.updatedAt = record["updatedAt"] as? Date ?? Date()

        // Decode action items, decisions, follow-ups
        if let actionItemsJson = record["actionItemsData"] as? String,
           let data = actionItemsJson.data(using: .utf8),
           let items = try? JSONDecoder().decode([ActionItem].self, from: data) {
            meeting.actionItems = items
        }
        if let decisionsJson = record["decisionsData"] as? String,
           let data = decisionsJson.data(using: .utf8),
           let decisions = try? JSONDecoder().decode([Decision].self, from: data) {
            meeting.decisions = decisions
        }
        if let followUpsJson = record["followUpsData"] as? String,
           let data = followUpsJson.data(using: .utf8),
           let followUps = try? JSONDecoder().decode([FollowUp].self, from: data) {
            meeting.followUps = followUps
        }

        return meeting
    }

    // MARK: - Record Conversion - Goal

    private func record(from goal: Goal) -> CKRecord {
        let recordID = CKRecord.ID(recordName: goal.id.uuidString, zoneID: zoneID)
        let record = CKRecord(recordType: RecordType.goal.rawValue, recordID: recordID)

        record["title"] = goal.title
        record["goalDescription"] = goal.description
        record["category"] = goal.category.rawValue
        record["status"] = goal.status.rawValue
        record["progress"] = goal.progress
        record["targetDate"] = goal.targetDate
        record["personId"] = goal.personId?.uuidString
        record["relatedMeetingIds"] = goal.relatedMeetingIds.map { $0.uuidString }
        record["createdAt"] = goal.createdAt
        record["updatedAt"] = goal.updatedAt

        if let milestonesData = try? JSONEncoder().encode(goal.milestones) {
            record["milestonesData"] = String(data: milestonesData, encoding: .utf8)
        }

        return record
    }

    private func goal(from record: CKRecord) -> Goal? {
        guard let id = UUID(uuidString: record.recordID.recordName),
              let title = record["title"] as? String else {
            return nil
        }

        var goal = Goal(
            id: id,
            title: title,
            description: record["goalDescription"] as? String
        )

        if let catString = record["category"] as? String,
           let cat = GoalCategory(rawValue: catString) {
            goal.category = cat
        }
        if let statusString = record["status"] as? String,
           let status = GoalStatus(rawValue: statusString) {
            goal.status = status
        }
        goal.progress = record["progress"] as? Double ?? 0
        goal.targetDate = record["targetDate"] as? Date
        if let personIdString = record["personId"] as? String {
            goal.personId = UUID(uuidString: personIdString)
        }
        goal.relatedMeetingIds = (record["relatedMeetingIds"] as? [String])?.compactMap { UUID(uuidString: $0) } ?? []
        goal.createdAt = record["createdAt"] as? Date ?? Date()
        goal.updatedAt = record["updatedAt"] as? Date ?? Date()

        if let milestonesJson = record["milestonesData"] as? String,
           let data = milestonesJson.data(using: .utf8),
           let milestones = try? JSONDecoder().decode([Milestone].self, from: data) {
            goal.milestones = milestones
        }

        return goal
    }

    // MARK: - Record Conversion - Objective

    private func record(from objective: Objective) -> CKRecord {
        let recordID = CKRecord.ID(recordName: objective.id.uuidString, zoneID: zoneID)
        let record = CKRecord(recordType: RecordType.objective.rawValue, recordID: recordID)

        record["title"] = objective.title
        record["objectiveDescription"] = objective.description
        record["quarter"] = objective.quarter
        record["status"] = objective.status.rawValue
        record["ownerId"] = objective.ownerId?.uuidString
        record["parentId"] = objective.parentId?.uuidString
        record["createdAt"] = objective.createdAt
        record["updatedAt"] = objective.updatedAt

        if let keyResultsData = try? JSONEncoder().encode(objective.keyResults) {
            record["keyResultsData"] = String(data: keyResultsData, encoding: .utf8)
        }

        return record
    }

    private func objective(from record: CKRecord) -> Objective? {
        guard let id = UUID(uuidString: record.recordID.recordName),
              let title = record["title"] as? String,
              let quarter = record["quarter"] as? String else {
            return nil
        }

        var objective = Objective(
            id: id,
            title: title,
            description: record["objectiveDescription"] as? String,
            quarter: quarter
        )

        if let statusString = record["status"] as? String,
           let status = OKRStatus(rawValue: statusString) {
            objective.status = status
        }
        if let ownerIdString = record["ownerId"] as? String {
            objective.ownerId = UUID(uuidString: ownerIdString)
        }
        if let parentIdString = record["parentId"] as? String {
            objective.parentId = UUID(uuidString: parentIdString)
        }
        objective.createdAt = record["createdAt"] as? Date ?? Date()
        objective.updatedAt = record["updatedAt"] as? Date ?? Date()

        if let keyResultsJson = record["keyResultsData"] as? String,
           let data = keyResultsJson.data(using: .utf8),
           let keyResults = try? JSONDecoder().decode([KeyResult].self, from: data) {
            objective.keyResults = keyResults
        }

        return objective
    }

    // MARK: - Record Conversion - Feedback

    private func record(from feedback: Feedback) -> CKRecord {
        let recordID = CKRecord.ID(recordName: feedback.id.uuidString, zoneID: zoneID)
        let record = CKRecord(recordType: RecordType.feedback.rawValue, recordID: recordID)

        record["personId"] = feedback.personId.uuidString
        record["date"] = feedback.date
        record["type"] = feedback.type.rawValue
        record["direction"] = feedback.direction.rawValue
        record["content"] = feedback.content
        record["context"] = feedback.context
        record["meetingId"] = feedback.meetingId?.uuidString
        record["tags"] = feedback.tags
        record["createdAt"] = feedback.createdAt

        return record
    }

    private func feedback(from record: CKRecord) -> Feedback? {
        guard let id = UUID(uuidString: record.recordID.recordName),
              let personIdString = record["personId"] as? String,
              let personId = UUID(uuidString: personIdString),
              let date = record["date"] as? Date,
              let typeString = record["type"] as? String,
              let type = FeedbackType(rawValue: typeString),
              let directionString = record["direction"] as? String,
              let direction = FeedbackDirection(rawValue: directionString),
              let content = record["content"] as? String else {
            return nil
        }

        var meetingId: UUID?
        if let meetingIdString = record["meetingId"] as? String {
            meetingId = UUID(uuidString: meetingIdString)
        }

        return Feedback(
            id: id,
            personId: personId,
            type: type,
            direction: direction,
            content: content,
            context: record["context"] as? String,
            meetingId: meetingId,
            tags: record["tags"] as? [String] ?? [],
            date: date
        )
    }

    // MARK: - Delete Operations

    func deleteFromCloud(_ person: Person) async {
        let recordID = CKRecord.ID(recordName: person.id.uuidString, zoneID: zoneID)
        try? await privateDatabase.deleteRecord(withID: recordID)
    }

    func deleteFromCloud(_ meeting: Meeting) async {
        let recordID = CKRecord.ID(recordName: meeting.id.uuidString, zoneID: zoneID)
        try? await privateDatabase.deleteRecord(withID: recordID)
    }

    func deleteFromCloud(_ goal: Goal) async {
        let recordID = CKRecord.ID(recordName: goal.id.uuidString, zoneID: zoneID)
        try? await privateDatabase.deleteRecord(withID: recordID)
    }
}
