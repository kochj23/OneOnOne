//
//  OneOnOneApp.swift
//  OneOnOne
//
//  AI-assisted app for managing 1:1 and team meetings
//  Created by Jordan Koch on 2026-02-02.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI
import CloudKit

@main
struct OneOnOneApp: App {
    @StateObject private var dataStore = DataStore.shared
    @StateObject private var syncService = SyncService.shared
    @StateObject private var cloudKitService = CloudKitService.shared

    #if !os(tvOS)
    @StateObject private var calendarService = CalendarService.shared
    #endif

    #if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #elseif os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Trigger initial iCloud sync on launch
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
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
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        Task { await cloudKitService.handleRemoteNotification() }
                    }
                }
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
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        Task { await cloudKitService.handleRemoteNotification() }
                    }
                }
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

// MARK: - App Delegate for Remote Notification Handling

#if os(iOS)
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        application.registerForRemoteNotifications()
        return true
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        let notification = CKNotification(fromRemoteNotificationDictionary: userInfo)
        if notification?.subscriptionID == "OneOnOne-Changes" {
            Task { @MainActor in
                await CloudKitService.shared.handleRemoteNotification()
                completionHandler(.newData)
            }
        } else {
            completionHandler(.noData)
        }
    }
}
#elseif os(macOS)
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.registerForRemoteNotifications()
    }

    func application(_ application: NSApplication, didReceiveRemoteNotification userInfo: [String: Any]) {
        let notification = CKNotification(fromRemoteNotificationDictionary: userInfo)
        if notification?.subscriptionID == "OneOnOne-Changes" {
            Task { @MainActor in
                await CloudKitService.shared.handleRemoteNotification()
            }
        }
    }
}
#endif

// MARK: - Notification Names

extension Notification.Name {
    static let newMeeting = Notification.Name("newMeeting")
    static let newPerson = Notification.Name("newPerson")
    static let newGoal = Notification.Name("newGoal")
    static let selectMeeting = Notification.Name("selectMeeting")
    static let navigateToActionItems = Notification.Name("navigateToActionItems")
    static let navigateToGoals = Notification.Name("navigateToGoals")
}
