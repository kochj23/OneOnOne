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
/// Note: iCloud container "iCloud.com.jordankoch.OneOnOne" must be created in Apple Developer Portal
/// and added to the app's entitlements before sync will function.
@MainActor
class CloudKitService: ObservableObject {
    static let shared = CloudKitService()

    // MARK: - Published Properties

    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?
    @Published var isCloudAvailable = false

    // MARK: - CloudKit Properties

    private var container: CKContainer?
    private var privateDatabase: CKDatabase?
    private var zoneID: CKRecordZone.ID?
    private let subscriptionID = "OneOnOne-Changes"
    private var isConfigured = false

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
        // Check if iCloud container is configured in entitlements
        // For now, iCloud sync is disabled until the container is created
        // in Apple Developer Portal and entitlements are updated
        isConfigured = false
        isCloudAvailable = false
        syncError = "iCloud sync not configured. Add iCloud capability to enable sync."

        // Uncomment once iCloud is configured:
        // setupContainer()
    }

    private func setupContainer() {
        container = CKContainer(identifier: "iCloud.com.jordankoch.OneOnOne")
        if let container = container {
            privateDatabase = container.privateCloudDatabase
            zoneID = CKRecordZone.ID(zoneName: "OneOnOneZone", ownerName: CKCurrentUserDefaultName)
            isConfigured = true

            Task {
                await checkCloudAvailability()
                await setupCloudKit()
            }
        }
    }

    // MARK: - Setup

    private func checkCloudAvailability() async {
        guard isConfigured, let container = container else {
            isCloudAvailable = false
            return
        }

        do {
            let status = try await container.accountStatus()
            isCloudAvailable = status == .available
            if !isCloudAvailable {
                syncError = "iCloud account not available. Sign in to iCloud to enable sync."
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
        } catch let error as CKError where error.code == .serverRecordChanged {
            // Zone already exists, that's fine
        } catch {
            print("Failed to create zone: \(error)")
        }

        // Subscribe to changes
        await subscribeToChanges()
    }

    private func subscribeToChanges() async {
        guard let privateDatabase = privateDatabase else { return }

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
        guard isConfigured && isCloudAvailable else {
            syncError = "iCloud sync not available"
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
        guard isConfigured else { return }
        // Implementation deferred until iCloud is configured
    }

    /// Pushes local changes to iCloud
    private func pushChanges() async throws {
        guard isConfigured else { return }
        // Implementation deferred until iCloud is configured
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
}
