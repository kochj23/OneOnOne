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
    @StateObject private var calendarService = CalendarService.shared
    @StateObject private var syncService = SyncService.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataStore)
                .environmentObject(calendarService)
                .environmentObject(syncService)
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
            }
        }

        Settings {
            SettingsView()
        }
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
