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
    @Published var syncProgress: Double = 0

    // MARK: - CloudKit Properties

    private var container: CKContainer?
    private var privateDatabase: CKDatabase?
    private var zoneID: CKRecordZone.ID?
    private let subscriptionID = "OneOnOne-Changes"
    private var isConfigured = false

    // Change token for incremental sync
    private var serverChangeToken: CKServerChangeToken? {
        get {
            guard let data = UserDefaults.standard.data(forKey: "cloudKitChangeToken") else { return nil }
            return try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: data)
        }
        set {
            if let token = newValue,
               let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true) {
                UserDefaults.standard.set(data, forKey: "cloudKitChangeToken")
            } else {
                UserDefaults.standard.removeObject(forKey: "cloudKitChangeToken")
            }
        }
    }

    // Record types
    private enum RecordType: String, CaseIterable {
        case person = "Person"
        case meeting = "Meeting"
        case goal = "Goal"
        case template = "MeetingTemplate"
        case feedback = "Feedback"
        case careerProfile = "CareerProfile"
        case sentimentEntry = "SentimentEntry"
        case objective = "Objective"
        case recording = "Recording"
    }

    // MARK: - Initialization

    private init() {
        setupContainer()
    }

    private func setupContainer() {
        container = CKContainer(identifier: "iCloud.com.jordankoch.OneOnOne")
        if let container = container {
            privateDatabase = container.privateCloudDatabase
            zoneID = CKRecordZone.ID(zoneName: "OneOnOneZone", ownerName: CKCurrentUserDefaultName)
            isConfigured = true

            Task {
                await checkCloudAvailability()
                if isCloudAvailable {
                    await setupCloudKit()
                }
            }
        }
    }

    // MARK: - Setup

    private func checkCloudAvailability() async {
        guard isConfigured, let container = container else {
            isCloudAvailable = false
            syncError = "iCloud not configured"
            return
        }

        do {
            let status = try await container.accountStatus()
            isCloudAvailable = status == .available
            if !isCloudAvailable {
                switch status {
                case .noAccount:
                    syncError = "No iCloud account. Sign in to iCloud in System Settings to enable sync."
                case .restricted:
                    syncError = "iCloud access is restricted on this device."
                case .couldNotDetermine:
                    syncError = "Could not determine iCloud status. Please try again."
                case .temporarilyUnavailable:
                    syncError = "iCloud is temporarily unavailable. Please try again later."
                @unknown default:
                    syncError = "iCloud account not available."
                }
            } else {
                syncError = nil
            }
        } catch {
            isCloudAvailable = false
            syncError = "Could not check iCloud status: \(error.localizedDescription)"
        }
    }

    private func setupCloudKit() async {
        guard isCloudAvailable, let privateDatabase = privateDatabase, let zoneID = zoneID else { return }

        // Create custom zone
        let zone = CKRecordZone(zoneID: zoneID)
        do {
            try await privateDatabase.save(zone)
            print("[CloudKit] Zone created successfully")
        } catch {
            // Zone likely already exists, which is fine
            print("[CloudKit] Zone setup: \(error.localizedDescription)")
        }

        // Subscribe to changes for push notifications
        await subscribeToChanges()
    }

    private func subscribeToChanges() async {
        guard let privateDatabase = privateDatabase, let zoneID = zoneID else { return }

        let subscription = CKRecordZoneSubscription(zoneID: zoneID, subscriptionID: subscriptionID)

        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo

        do {
            try await privateDatabase.save(subscription)
            print("[CloudKit] Subscribed to changes")
        } catch let error as CKError where error.code == .serverRecordChanged {
            // Subscription already exists
            print("[CloudKit] Subscription already exists")
        } catch {
            print("[CloudKit] Failed to subscribe to changes: \(error)")
        }
    }

    // MARK: - Public Sync Operations

    /// Performs a full sync with iCloud
    func sync() async {
        guard isConfigured else {
            syncError = "iCloud sync not configured"
            return
        }

        // Re-check availability
        await checkCloudAvailability()

        guard isCloudAvailable else {
            return
        }

        isSyncing = true
        syncError = nil
        syncProgress = 0

        defer {
            isSyncing = false
            syncProgress = 1.0
        }

        do {
            // First, fetch changes from cloud
            syncProgress = 0.2
            try await fetchChanges()

            // Then push local changes
            syncProgress = 0.6
            try await pushChanges()

            syncProgress = 1.0
            lastSyncDate = Date()
            UserDefaults.standard.set(lastSyncDate, forKey: "lastCloudSyncDate")
            print("[CloudKit] Sync completed successfully")
        } catch {
            syncError = "Sync failed: \(error.localizedDescription)"
            print("[CloudKit] Sync error: \(error)")
        }
    }

    /// Force a full re-sync by clearing change token
    func forceFullSync() async {
        serverChangeToken = nil
        await sync()
    }

    // MARK: - Fetch Changes

    private func fetchChanges() async throws {
        guard let privateDatabase = privateDatabase, let zoneID = zoneID else { return }

        var changedRecords: [CKRecord] = []
        var deletedRecordIDs: [CKRecord.ID] = []

        // Use CKFetchRecordZoneChangesOperation for incremental sync
        let options = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
        options.previousServerChangeToken = serverChangeToken

        let operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: [zoneID], configurationsByRecordZoneID: [zoneID: options])

        operation.recordWasChangedBlock = { _, result in
            switch result {
            case .success(let record):
                changedRecords.append(record)
            case .failure(let error):
                print("[CloudKit] Error fetching record: \(error)")
            }
        }

        operation.recordWithIDWasDeletedBlock = { recordID, _ in
            deletedRecordIDs.append(recordID)
        }

        operation.recordZoneChangeTokensUpdatedBlock = { [weak self] _, token, _ in
            Task { @MainActor in
                self?.serverChangeToken = token
            }
        }

        operation.recordZoneFetchResultBlock = { [weak self] _, result in
            switch result {
            case .success(let (token, _, _)):
                Task { @MainActor in
                    self?.serverChangeToken = token
                }
            case .failure(let error):
                print("[CloudKit] Zone fetch error: \(error)")
            }
        }

        try await privateDatabase.add(operation)

        // Process fetched changes
        await processChangedRecords(changedRecords)
        await processDeletedRecords(deletedRecordIDs)

        print("[CloudKit] Fetched \(changedRecords.count) changed records, \(deletedRecordIDs.count) deletions")
    }

    private func processChangedRecords(_ records: [CKRecord]) async {
        let dataStore = DataStore.shared

        for record in records {
            guard let recordType = RecordType(rawValue: record.recordType) else { continue }

            switch recordType {
            case .person:
                if let person = Person(from: record) {
                    if let index = dataStore.people.firstIndex(where: { $0.id == person.id }) {
                        // Update if cloud version is newer
                        if person.updatedAt > dataStore.people[index].updatedAt {
                            dataStore.people[index] = person
                        }
                    } else {
                        dataStore.people.append(person)
                    }
                }

            case .meeting:
                if let meeting = Meeting(from: record) {
                    if let index = dataStore.meetings.firstIndex(where: { $0.id == meeting.id }) {
                        if meeting.updatedAt > dataStore.meetings[index].updatedAt {
                            dataStore.meetings[index] = meeting
                        }
                    } else {
                        dataStore.meetings.append(meeting)
                    }
                }

            case .goal:
                if let goal = Goal(from: record) {
                    if let index = dataStore.goals.firstIndex(where: { $0.id == goal.id }) {
                        if goal.updatedAt > dataStore.goals[index].updatedAt {
                            dataStore.goals[index] = goal
                        }
                    } else {
                        dataStore.goals.append(goal)
                    }
                }

            case .template:
                if let template = MeetingTemplate(from: record) {
                    if let index = dataStore.templates.firstIndex(where: { $0.id == template.id }) {
                        dataStore.templates[index] = template
                    } else {
                        dataStore.templates.append(template)
                    }
                }

            case .feedback:
                if let fb = Feedback(from: record) {
                    if let index = dataStore.feedback.firstIndex(where: { $0.id == fb.id }) {
                        if fb.date > dataStore.feedback[index].date {
                            dataStore.feedback[index] = fb
                        }
                    } else {
                        dataStore.feedback.append(fb)
                    }
                }

            case .careerProfile:
                if let profile = CareerProfile(from: record),
                   let personIdString = record["personId"] as? String,
                   let personId = UUID(uuidString: personIdString) {
                    if let existing = dataStore.careerProfiles[personId] {
                        if profile.updatedAt > existing.updatedAt {
                            dataStore.careerProfiles[personId] = profile
                        }
                    } else {
                        dataStore.careerProfiles[personId] = profile
                    }
                }

            case .sentimentEntry:
                if let entry = SentimentEntry(from: record),
                   let personIdString = record["personId"] as? String,
                   let personId = UUID(uuidString: personIdString) {
                    var entries = dataStore.sentimentHistory[personId] ?? []
                    if !entries.contains(where: { $0.id == entry.id }) {
                        entries.append(entry)
                        dataStore.sentimentHistory[personId] = entries
                    }
                }

            case .objective:
                if let objective = Objective(from: record) {
                    if let index = dataStore.objectives.firstIndex(where: { $0.id == objective.id }) {
                        if objective.updatedAt > dataStore.objectives[index].updatedAt {
                            dataStore.objectives[index] = objective
                        }
                    } else {
                        dataStore.objectives.append(objective)
                    }
                }

            case .recording:
                if let recording = Recording(from: record) {
                    if let index = dataStore.recordings.firstIndex(where: { $0.id == recording.id }) {
                        dataStore.recordings[index] = recording
                    } else {
                        dataStore.recordings.append(recording)
                    }
                }
            }
        }

        // Save locally without triggering another sync
        dataStore.saveData()
    }

    private func processDeletedRecords(_ recordIDs: [CKRecord.ID]) async {
        let dataStore = DataStore.shared

        for recordID in recordIDs {
            guard let uuid = UUID(uuidString: recordID.recordName) else { continue }

            dataStore.people.removeAll { $0.id == uuid }
            dataStore.meetings.removeAll { $0.id == uuid }
            dataStore.goals.removeAll { $0.id == uuid }
            dataStore.templates.removeAll { $0.id == uuid }
            dataStore.feedback.removeAll { $0.id == uuid }
            dataStore.objectives.removeAll { $0.id == uuid }
            dataStore.recordings.removeAll { $0.id == uuid }
        }

        dataStore.saveData()
    }

    // MARK: - Push Changes

    private func pushChanges() async throws {
        guard let privateDatabase = privateDatabase, let zoneID = zoneID else { return }

        let dataStore = DataStore.shared
        var recordsToSave: [CKRecord] = []

        // Convert all local data to CKRecords
        for person in dataStore.people {
            recordsToSave.append(person.toCloudKitRecord(zoneID: zoneID))
        }

        for meeting in dataStore.meetings {
            recordsToSave.append(meeting.toCloudKitRecord(zoneID: zoneID))
        }

        for goal in dataStore.goals {
            recordsToSave.append(goal.toCloudKitRecord(zoneID: zoneID))
        }

        for template in dataStore.templates where !template.isBuiltIn {
            recordsToSave.append(template.toCloudKitRecord(zoneID: zoneID))
        }

        for fb in dataStore.feedback {
            recordsToSave.append(fb.toCloudKitRecord(zoneID: zoneID))
        }

        for (personId, profile) in dataStore.careerProfiles {
            recordsToSave.append(profile.toCloudKitRecord(zoneID: zoneID, personId: personId))
        }

        for (personId, entries) in dataStore.sentimentHistory {
            for entry in entries {
                recordsToSave.append(entry.toCloudKitRecord(zoneID: zoneID, personId: personId))
            }
        }

        for objective in dataStore.objectives {
            recordsToSave.append(objective.toCloudKitRecord(zoneID: zoneID))
        }

        for recording in dataStore.recordings {
            recordsToSave.append(recording.toCloudKitRecord(zoneID: zoneID))
        }

        // Use batch operation
        if !recordsToSave.isEmpty {
            let operation = CKModifyRecordsOperation(recordsToSave: recordsToSave, recordIDsToDelete: nil)
            operation.savePolicy = .changedKeys
            operation.isAtomic = false // Allow partial success

            operation.perRecordSaveBlock = { recordID, result in
                switch result {
                case .success:
                    break // Record saved
                case .failure(let error):
                    print("[CloudKit] Failed to save record \(recordID.recordName): \(error)")
                }
            }

            try await privateDatabase.add(operation)
            print("[CloudKit] Pushed \(recordsToSave.count) records")
        }
    }

    // MARK: - Delete Operations

    func deleteFromCloud(_ person: Person) async {
        guard isConfigured, let privateDatabase = privateDatabase, let zoneID = zoneID else { return }
        let recordID = CKRecord.ID(recordName: person.id.uuidString, zoneID: zoneID)
        try? await privateDatabase.deleteRecord(withID: recordID)
    }

    func deleteFromCloud(_ meeting: Meeting) async {
        guard isConfigured, let privateDatabase = privateDatabase, let zoneID = zoneID else { return }
        let recordID = CKRecord.ID(recordName: meeting.id.uuidString, zoneID: zoneID)
        try? await privateDatabase.deleteRecord(withID: recordID)
    }

    func deleteFromCloud(_ goal: Goal) async {
        guard isConfigured, let privateDatabase = privateDatabase, let zoneID = zoneID else { return }
        let recordID = CKRecord.ID(recordName: goal.id.uuidString, zoneID: zoneID)
        try? await privateDatabase.deleteRecord(withID: recordID)
    }

    func deleteFromCloud(_ objective: Objective) async {
        guard isConfigured, let privateDatabase = privateDatabase, let zoneID = zoneID else { return }
        let recordID = CKRecord.ID(recordName: objective.id.uuidString, zoneID: zoneID)
        try? await privateDatabase.deleteRecord(withID: recordID)
    }

    func deleteFromCloud(_ feedback: Feedback) async {
        guard isConfigured, let privateDatabase = privateDatabase, let zoneID = zoneID else { return }
        let recordID = CKRecord.ID(recordName: feedback.id.uuidString, zoneID: zoneID)
        try? await privateDatabase.deleteRecord(withID: recordID)
    }
}

// MARK: - CloudKit Record Conversions

extension Person {
    func toCloudKitRecord(zoneID: CKRecordZone.ID) -> CKRecord {
        let recordID = CKRecord.ID(recordName: id.uuidString, zoneID: zoneID)
        let record = CKRecord(recordType: "Person", recordID: recordID)

        record["name"] = name as CKRecordValue
        record["email"] = email as CKRecordValue?
        record["title"] = title as CKRecordValue?
        record["department"] = department as CKRecordValue?
        record["notes"] = notes as CKRecordValue?
        record["avatarColor"] = avatarColor as CKRecordValue
        record["tags"] = tags as CKRecordValue
        record["meetingFrequency"] = meetingFrequency.rawValue as CKRecordValue
        record["lastMeetingDate"] = lastMeetingDate as CKRecordValue?
        record["nextScheduledMeeting"] = nextScheduledMeeting as CKRecordValue?
        record["createdAt"] = createdAt as CKRecordValue
        record["updatedAt"] = updatedAt as CKRecordValue

        return record
    }

    init?(from record: CKRecord) {
        guard record.recordType == "Person",
              let name = record["name"] as? String,
              let avatarColor = record["avatarColor"] as? String,
              let createdAt = record["createdAt"] as? Date,
              let updatedAt = record["updatedAt"] as? Date,
              let id = UUID(uuidString: record.recordID.recordName) else {
            return nil
        }

        self.id = id
        self.name = name
        self.email = record["email"] as? String
        self.title = record["title"] as? String
        self.department = record["department"] as? String
        self.notes = record["notes"] as? String
        self.avatarColor = avatarColor
        self.tags = record["tags"] as? [String] ?? []
        self.meetingFrequency = MeetingFrequency(rawValue: record["meetingFrequency"] as? String ?? "") ?? .weekly
        self.lastMeetingDate = record["lastMeetingDate"] as? Date
        self.nextScheduledMeeting = record["nextScheduledMeeting"] as? Date
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension Meeting {
    func toCloudKitRecord(zoneID: CKRecordZone.ID) -> CKRecord {
        let recordID = CKRecord.ID(recordName: id.uuidString, zoneID: zoneID)
        let record = CKRecord(recordType: "Meeting", recordID: recordID)

        record["title"] = title as CKRecordValue
        record["date"] = date as CKRecordValue
        record["duration"] = duration as CKRecordValue
        record["attendeeIds"] = attendees.map { $0.uuidString } as CKRecordValue
        record["meetingType"] = meetingType.rawValue as CKRecordValue
        record["location"] = location as CKRecordValue?
        record["calendarEventId"] = calendarEventId as CKRecordValue?
        record["agenda"] = agenda as CKRecordValue?
        record["notes"] = notes as CKRecordValue
        record["summary"] = summary as CKRecordValue?
        record["tags"] = tags as CKRecordValue
        record["mood"] = mood?.rawValue as CKRecordValue?
        record["isRecurring"] = (isRecurring ? 1 : 0) as CKRecordValue
        record["recurringId"] = recurringId?.uuidString as CKRecordValue?
        record["createdAt"] = createdAt as CKRecordValue
        record["updatedAt"] = updatedAt as CKRecordValue

        // Encode complex objects as JSON
        if let actionItemsData = try? JSONEncoder().encode(actionItems),
           let actionItemsString = String(data: actionItemsData, encoding: .utf8) {
            record["actionItemsJson"] = actionItemsString as CKRecordValue
        }

        if let decisionsData = try? JSONEncoder().encode(decisions),
           let decisionsString = String(data: decisionsData, encoding: .utf8) {
            record["decisionsJson"] = decisionsString as CKRecordValue
        }

        if let followUpsData = try? JSONEncoder().encode(followUps),
           let followUpsString = String(data: followUpsData, encoding: .utf8) {
            record["followUpsJson"] = followUpsString as CKRecordValue
        }

        return record
    }

    init?(from record: CKRecord) {
        guard record.recordType == "Meeting",
              let title = record["title"] as? String,
              let date = record["date"] as? Date,
              let duration = record["duration"] as? Double,
              let createdAt = record["createdAt"] as? Date,
              let updatedAt = record["updatedAt"] as? Date,
              let id = UUID(uuidString: record.recordID.recordName) else {
            return nil
        }

        self.id = id
        self.title = title
        self.date = date
        self.duration = duration
        self.attendees = (record["attendeeIds"] as? [String])?.compactMap { UUID(uuidString: $0) } ?? []
        self.meetingType = MeetingType(rawValue: record["meetingType"] as? String ?? "") ?? .oneOnOne
        self.location = record["location"] as? String
        self.calendarEventId = record["calendarEventId"] as? String
        self.agenda = record["agenda"] as? String
        self.notes = record["notes"] as? String ?? ""
        self.summary = record["summary"] as? String
        self.tags = record["tags"] as? [String] ?? []
        self.mood = MeetingMood(rawValue: record["mood"] as? String ?? "")
        self.isRecurring = (record["isRecurring"] as? Int ?? 0) == 1
        self.recurringId = (record["recurringId"] as? String).flatMap { UUID(uuidString: $0) }
        self.createdAt = createdAt
        self.updatedAt = updatedAt

        // Decode complex objects from JSON
        if let actionItemsString = record["actionItemsJson"] as? String,
           let actionItemsData = actionItemsString.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([ActionItem].self, from: actionItemsData) {
            self.actionItems = decoded
        } else {
            self.actionItems = []
        }

        if let decisionsString = record["decisionsJson"] as? String,
           let decisionsData = decisionsString.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([Decision].self, from: decisionsData) {
            self.decisions = decoded
        } else {
            self.decisions = []
        }

        if let followUpsString = record["followUpsJson"] as? String,
           let followUpsData = followUpsString.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([FollowUp].self, from: followUpsData) {
            self.followUps = decoded
        } else {
            self.followUps = []
        }
    }
}

extension Goal {
    func toCloudKitRecord(zoneID: CKRecordZone.ID) -> CKRecord {
        let recordID = CKRecord.ID(recordName: id.uuidString, zoneID: zoneID)
        let record = CKRecord(recordType: "Goal", recordID: recordID)

        record["title"] = title as CKRecordValue
        record["description"] = description as CKRecordValue?
        record["personId"] = personId?.uuidString as CKRecordValue?
        record["category"] = category.rawValue as CKRecordValue
        record["status"] = status.rawValue as CKRecordValue
        record["progress"] = progress as CKRecordValue
        record["targetDate"] = targetDate as CKRecordValue?
        record["relatedMeetingIds"] = relatedMeetingIds.map { $0.uuidString } as CKRecordValue
        record["tags"] = tags as CKRecordValue
        record["createdAt"] = createdAt as CKRecordValue
        record["updatedAt"] = updatedAt as CKRecordValue

        // Encode milestones as JSON
        if let milestonesData = try? JSONEncoder().encode(milestones),
           let milestonesString = String(data: milestonesData, encoding: .utf8) {
            record["milestonesJson"] = milestonesString as CKRecordValue
        }

        return record
    }

    init?(from record: CKRecord) {
        guard record.recordType == "Goal",
              let title = record["title"] as? String,
              let createdAt = record["createdAt"] as? Date,
              let updatedAt = record["updatedAt"] as? Date,
              let id = UUID(uuidString: record.recordID.recordName) else {
            return nil
        }

        self.id = id
        self.title = title
        self.description = record["description"] as? String
        self.personId = (record["personId"] as? String).flatMap { UUID(uuidString: $0) }
        self.category = GoalCategory(rawValue: record["category"] as? String ?? "") ?? .development
        self.status = GoalStatus(rawValue: record["status"] as? String ?? "") ?? .notStarted
        self.progress = record["progress"] as? Double ?? 0
        self.targetDate = record["targetDate"] as? Date
        self.relatedMeetingIds = (record["relatedMeetingIds"] as? [String])?.compactMap { UUID(uuidString: $0) } ?? []
        self.tags = record["tags"] as? [String] ?? []
        self.createdAt = createdAt
        self.updatedAt = updatedAt

        // Decode milestones from JSON
        if let milestonesString = record["milestonesJson"] as? String,
           let milestonesData = milestonesString.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([Milestone].self, from: milestonesData) {
            self.milestones = decoded
        } else {
            self.milestones = []
        }
    }
}

extension MeetingTemplate {
    func toCloudKitRecord(zoneID: CKRecordZone.ID) -> CKRecord {
        let recordID = CKRecord.ID(recordName: id.uuidString, zoneID: zoneID)
        let record = CKRecord(recordType: "MeetingTemplate", recordID: recordID)

        record["name"] = name as CKRecordValue
        record["templateDescription"] = description as CKRecordValue?
        record["meetingType"] = meetingType.rawValue as CKRecordValue
        record["defaultDuration"] = defaultDuration as CKRecordValue
        record["suggestedQuestions"] = suggestedQuestions as CKRecordValue
        record["isBuiltIn"] = (isBuiltIn ? 1 : 0) as CKRecordValue
        record["createdAt"] = createdAt as CKRecordValue
        record["updatedAt"] = updatedAt as CKRecordValue

        // Encode agendaItems as JSON
        if let agendaData = try? JSONEncoder().encode(agendaItems),
           let agendaString = String(data: agendaData, encoding: .utf8) {
            record["agendaItemsJson"] = agendaString as CKRecordValue
        }

        return record
    }

    init?(from record: CKRecord) {
        guard record.recordType == "MeetingTemplate",
              let name = record["name"] as? String,
              let id = UUID(uuidString: record.recordID.recordName) else {
            return nil
        }

        self.id = id
        self.name = name
        self.description = record["templateDescription"] as? String
        self.meetingType = MeetingType(rawValue: record["meetingType"] as? String ?? "") ?? .oneOnOne
        self.defaultDuration = record["defaultDuration"] as? TimeInterval ?? 3600
        self.suggestedQuestions = record["suggestedQuestions"] as? [String] ?? []
        self.isBuiltIn = (record["isBuiltIn"] as? Int ?? 0) == 1
        self.createdAt = record["createdAt"] as? Date ?? Date()
        self.updatedAt = record["updatedAt"] as? Date ?? Date()

        // Decode agendaItems from JSON
        if let agendaString = record["agendaItemsJson"] as? String,
           let agendaData = agendaString.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([AgendaItem].self, from: agendaData) {
            self.agendaItems = decoded
        } else {
            self.agendaItems = []
        }
    }
}

extension Feedback {
    func toCloudKitRecord(zoneID: CKRecordZone.ID) -> CKRecord {
        let recordID = CKRecord.ID(recordName: id.uuidString, zoneID: zoneID)
        let record = CKRecord(recordType: "Feedback", recordID: recordID)

        record["personId"] = personId.uuidString as CKRecordValue
        record["meetingId"] = meetingId?.uuidString as CKRecordValue?
        record["feedbackType"] = type.rawValue as CKRecordValue
        record["direction"] = direction.rawValue as CKRecordValue
        record["content"] = content as CKRecordValue
        record["context"] = context as CKRecordValue?
        record["tags"] = tags as CKRecordValue
        record["date"] = date as CKRecordValue
        record["createdAt"] = createdAt as CKRecordValue

        return record
    }

    init?(from record: CKRecord) {
        guard record.recordType == "Feedback",
              let personIdString = record["personId"] as? String,
              let personId = UUID(uuidString: personIdString),
              let content = record["content"] as? String,
              let date = record["date"] as? Date,
              let id = UUID(uuidString: record.recordID.recordName) else {
            return nil
        }

        self.id = id
        self.personId = personId
        self.meetingId = (record["meetingId"] as? String).flatMap { UUID(uuidString: $0) }
        self.type = FeedbackType(rawValue: record["feedbackType"] as? String ?? "") ?? .praise
        self.direction = FeedbackDirection(rawValue: record["direction"] as? String ?? "") ?? .given
        self.content = content
        self.context = record["context"] as? String
        self.tags = record["tags"] as? [String] ?? []
        self.date = date
        self.createdAt = record["createdAt"] as? Date ?? Date()
    }
}

extension CareerProfile {
    func toCloudKitRecord(zoneID: CKRecordZone.ID, personId: UUID) -> CKRecord {
        let recordID = CKRecord.ID(recordName: "career-\(personId.uuidString)", zoneID: zoneID)
        let record = CKRecord(recordType: "CareerProfile", recordID: recordID)

        record["personId"] = personId.uuidString as CKRecordValue
        record["currentRole"] = currentRole as CKRecordValue?
        record["targetRole"] = targetRole as CKRecordValue?
        record["careerGoals"] = careerGoals as CKRecordValue?
        record["strengths"] = strengths as CKRecordValue
        record["areasForGrowth"] = areasForGrowth as CKRecordValue
        record["promotionReadiness"] = promotionReadiness.rawValue as CKRecordValue
        record["lastReviewDate"] = lastReviewDate as CKRecordValue?
        record["nextReviewDate"] = nextReviewDate as CKRecordValue?
        record["createdAt"] = createdAt as CKRecordValue
        record["updatedAt"] = updatedAt as CKRecordValue

        // Encode skills and trainings as JSON
        if let skillsData = try? JSONEncoder().encode(skills),
           let skillsString = String(data: skillsData, encoding: .utf8) {
            record["skillsJson"] = skillsString as CKRecordValue
        }
        if let trainingsData = try? JSONEncoder().encode(trainings),
           let trainingsString = String(data: trainingsData, encoding: .utf8) {
            record["trainingsJson"] = trainingsString as CKRecordValue
        }

        return record
    }

    init?(from record: CKRecord) {
        guard record.recordType == "CareerProfile",
              let personIdString = record["personId"] as? String,
              let personId = UUID(uuidString: personIdString),
              let createdAt = record["createdAt"] as? Date,
              let updatedAt = record["updatedAt"] as? Date else {
            return nil
        }

        self.id = UUID()
        self.personId = personId
        self.currentRole = record["currentRole"] as? String
        self.targetRole = record["targetRole"] as? String
        self.careerGoals = record["careerGoals"] as? String
        self.strengths = record["strengths"] as? [String] ?? []
        self.areasForGrowth = record["areasForGrowth"] as? [String] ?? []
        self.promotionReadiness = PromotionReadiness(rawValue: record["promotionReadiness"] as? String ?? "") ?? .notReady
        self.lastReviewDate = record["lastReviewDate"] as? Date
        self.nextReviewDate = record["nextReviewDate"] as? Date
        self.createdAt = createdAt
        self.updatedAt = updatedAt

        // Decode skills and trainings from JSON
        if let skillsString = record["skillsJson"] as? String,
           let skillsData = skillsString.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([Skill].self, from: skillsData) {
            self.skills = decoded
        } else {
            self.skills = []
        }
        if let trainingsString = record["trainingsJson"] as? String,
           let trainingsData = trainingsString.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([Training].self, from: trainingsData) {
            self.trainings = decoded
        } else {
            self.trainings = []
        }
    }
}

extension SentimentEntry {
    func toCloudKitRecord(zoneID: CKRecordZone.ID, personId: UUID) -> CKRecord {
        let recordID = CKRecord.ID(recordName: id.uuidString, zoneID: zoneID)
        let record = CKRecord(recordType: "SentimentEntry", recordID: recordID)

        record["personId"] = personId.uuidString as CKRecordValue
        record["meetingId"] = meetingId?.uuidString as CKRecordValue?
        record["sentiment"] = sentiment.rawValue as CKRecordValue
        record["energyLevel"] = energyLevel.rawValue as CKRecordValue
        record["engagementLevel"] = engagementLevel.rawValue as CKRecordValue
        record["stressIndicators"] = stressIndicators.map { $0.rawValue } as CKRecordValue
        record["notes"] = notes as CKRecordValue?
        record["date"] = date as CKRecordValue
        record["createdAt"] = createdAt as CKRecordValue

        return record
    }

    init?(from record: CKRecord) {
        guard record.recordType == "SentimentEntry",
              let personIdString = record["personId"] as? String,
              let personId = UUID(uuidString: personIdString),
              let date = record["date"] as? Date,
              let id = UUID(uuidString: record.recordID.recordName) else {
            return nil
        }

        self.id = id
        self.personId = personId
        self.meetingId = (record["meetingId"] as? String).flatMap { UUID(uuidString: $0) }
        self.sentiment = SentimentLevel(rawValue: record["sentiment"] as? Int ?? 3) ?? .neutral
        self.energyLevel = EnergyLevel(rawValue: record["energyLevel"] as? Int ?? 3) ?? .moderate
        self.engagementLevel = EngagementLevel(rawValue: record["engagementLevel"] as? Int ?? 4) ?? .engaged
        self.stressIndicators = (record["stressIndicators"] as? [String])?.compactMap { StressIndicator(rawValue: $0) } ?? []
        self.notes = record["notes"] as? String
        self.date = date
        self.createdAt = record["createdAt"] as? Date ?? Date()
    }
}

extension Objective {
    func toCloudKitRecord(zoneID: CKRecordZone.ID) -> CKRecord {
        let recordID = CKRecord.ID(recordName: id.uuidString, zoneID: zoneID)
        let record = CKRecord(recordType: "Objective", recordID: recordID)

        record["title"] = title as CKRecordValue
        record["objectiveDescription"] = description as CKRecordValue?
        record["level"] = level.rawValue as CKRecordValue
        record["parentId"] = parentId?.uuidString as CKRecordValue?
        record["ownerId"] = ownerId?.uuidString as CKRecordValue?
        record["quarter"] = quarter as CKRecordValue
        record["status"] = status.rawValue as CKRecordValue
        record["tags"] = tags as CKRecordValue
        record["linkedGoalIds"] = linkedGoalIds.map { $0.uuidString } as CKRecordValue
        record["createdAt"] = createdAt as CKRecordValue
        record["updatedAt"] = updatedAt as CKRecordValue

        // Encode key results as JSON
        if let keyResultsData = try? JSONEncoder().encode(keyResults),
           let keyResultsString = String(data: keyResultsData, encoding: .utf8) {
            record["keyResultsJson"] = keyResultsString as CKRecordValue
        }

        return record
    }

    init?(from record: CKRecord) {
        guard record.recordType == "Objective",
              let title = record["title"] as? String,
              let quarter = record["quarter"] as? String,
              let createdAt = record["createdAt"] as? Date,
              let updatedAt = record["updatedAt"] as? Date,
              let id = UUID(uuidString: record.recordID.recordName) else {
            return nil
        }

        self.id = id
        self.title = title
        self.description = record["objectiveDescription"] as? String
        self.level = OKRLevel(rawValue: record["level"] as? String ?? "") ?? .individual
        self.parentId = (record["parentId"] as? String).flatMap { UUID(uuidString: $0) }
        self.ownerId = (record["ownerId"] as? String).flatMap { UUID(uuidString: $0) }
        self.quarter = quarter
        self.status = OKRStatus(rawValue: record["status"] as? String ?? "") ?? .onTrack
        self.tags = record["tags"] as? [String] ?? []
        self.linkedGoalIds = (record["linkedGoalIds"] as? [String])?.compactMap { UUID(uuidString: $0) } ?? []
        self.createdAt = createdAt
        self.updatedAt = updatedAt

        // Decode key results from JSON
        if let keyResultsString = record["keyResultsJson"] as? String,
           let keyResultsData = keyResultsString.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([KeyResult].self, from: keyResultsData) {
            self.keyResults = decoded
        } else {
            self.keyResults = []
        }
    }
}

extension Recording {
    func toCloudKitRecord(zoneID: CKRecordZone.ID) -> CKRecord {
        let recordID = CKRecord.ID(recordName: id.uuidString, zoneID: zoneID)
        let record = CKRecord(recordType: "Recording", recordID: recordID)

        record["meetingId"] = meetingId.uuidString as CKRecordValue
        record["fileName"] = fileName as CKRecordValue
        record["filePath"] = filePath as CKRecordValue
        record["duration"] = duration as CKRecordValue
        record["fileSize"] = fileSize as CKRecordValue
        record["hasConsent"] = (hasConsent ? 1 : 0) as CKRecordValue
        record["consentNote"] = consentNote as CKRecordValue?
        record["createdAt"] = createdAt as CKRecordValue

        // Encode transcription as JSON
        if let transcription = transcription,
           let transcriptionData = try? JSONEncoder().encode(transcription),
           let transcriptionString = String(data: transcriptionData, encoding: .utf8) {
            record["transcriptionJson"] = transcriptionString as CKRecordValue
        }

        return record
    }

    init?(from record: CKRecord) {
        guard record.recordType == "Recording",
              let meetingIdString = record["meetingId"] as? String,
              let meetingId = UUID(uuidString: meetingIdString),
              let fileName = record["fileName"] as? String,
              let filePath = record["filePath"] as? String,
              let duration = record["duration"] as? TimeInterval,
              let createdAt = record["createdAt"] as? Date,
              let id = UUID(uuidString: record.recordID.recordName) else {
            return nil
        }

        self.id = id
        self.meetingId = meetingId
        self.fileName = fileName
        self.filePath = filePath
        self.duration = duration
        self.fileSize = record["fileSize"] as? Int64 ?? 0
        self.hasConsent = (record["hasConsent"] as? Int ?? 0) == 1
        self.consentNote = record["consentNote"] as? String
        self.createdAt = createdAt

        // Decode transcription from JSON
        if let transcriptionString = record["transcriptionJson"] as? String,
           let transcriptionData = transcriptionString.data(using: .utf8),
           let decoded = try? JSONDecoder().decode(Transcription.self, from: transcriptionData) {
            self.transcription = decoded
        } else {
            self.transcription = nil
        }
    }
}
