//
//  OneOnOneApp.swift
//  OneOnOne
//
//  AI-assisted app for managing 1:1 and team meetings
//  Created by Jordan Koch on 2026-02-02.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

@main
struct OneOnOneApp: App {
    @StateObject private var dataStore = DataStore.shared
    @StateObject private var syncService = SyncService.shared
    @StateObject private var cloudKitService = CloudKitService.shared

    #if !os(tvOS)
    @StateObject private var calendarService = CalendarService.shared
    #endif

    init() {
        // Trigger initial iCloud sync on launch
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000) // Wait 2 seconds for app to settle
            await CloudKitService.shared.sync()
        }
    }

    var body: some Scene {
        #if os(macOS)
        WindowGroup {
            ContentView()
                .environmentObject(dataStore)
                .environmentObject(calendarService)
                .environmentObject(syncService)
                .environmentObject(cloudKitService)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1400, height: 900)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Meeting") {
                    NotificationCenter.default.post(name: .newMeeting, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("New Person") {
                    NotificationCenter.default.post(name: .newPerson, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])

                Button("New Goal") {
                    NotificationCenter.default.post(name: .newGoal, object: nil)
                }
                .keyboardShortcut("g", modifiers: [.command, .shift])
            }

            CommandGroup(after: .importExport) {
                Button("Export Data...") {
                    Task {
                        await syncService.exportData()
                    }
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])

                Button("Import Data...") {
                    Task {
                        await syncService.importData()
                    }
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])

                Divider()

                Button("Create Backup") {
                    Task {
                        try? await syncService.createBackup()
                    }
                }

                Divider()

                Button("Sync with iCloud") {
                    Task {
                        await cloudKitService.sync()
                    }
                }
                .keyboardShortcut("s", modifiers: [.command, .option])
            }
        }

        Settings {
            SettingsView()
                .environmentObject(calendarService)
                .environmentObject(syncService)
        }

        #elseif os(iOS)
        WindowGroup {
            ContentView()
                .environmentObject(dataStore)
                .environmentObject(calendarService)
                .environmentObject(syncService)
                .environmentObject(cloudKitService)
                .preferredColorScheme(.dark)
        }

        #elseif os(tvOS)
        WindowGroup {
            ContentView()
                .environmentObject(dataStore)
                .environmentObject(syncService)
                .environmentObject(cloudKitService)
                .preferredColorScheme(.dark)
        }
        #endif
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let newMeeting = Notification.Name("newMeeting")
    static let newPerson = Notification.Name("newPerson")
    static let newGoal = Notification.Name("newGoal")
    static let selectMeeting = Notification.Name("selectMeeting")
    static let navigateToActionItems = Notification.Name("navigateToActionItems")
    static let navigateToGoals = Notification.Name("navigateToGoals")
}
