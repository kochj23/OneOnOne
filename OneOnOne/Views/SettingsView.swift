//
//  SettingsView.swift
//  OneOnOne
//
//  Settings view for the app
//  Created by Jordan Koch on 2026-02-02.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

struct SettingsView: View {
    #if !os(tvOS)
    @EnvironmentObject var calendarService: CalendarService
    #endif
    @EnvironmentObject var syncService: SyncService
    @State private var aiModelPath = "~/.mlx/models/Llama-3.2-3B-Instruct-4bit"
    @State private var autoBackupEnabled = true
    @State private var backupFrequency = "Daily"

    var body: some View {
        TabView {
            // General
            generalSettings
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            // Calendar
            calendarSettings
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }

            // AI
            aiSettings
                .tabItem {
                    Label("AI", systemImage: "sparkles")
                }

            // Backup
            backupSettings
                .tabItem {
                    Label("Backup", systemImage: "externaldrive")
                }
        }
        .frame(width: 500, height: 400)
    }

    // MARK: - General Settings

    private var generalSettings: some View {
        Form {
            Section("Data") {
                LabeledContent("People") {
                    Text("\(DataStore.shared.people.count)")
                }

                LabeledContent("Meetings") {
                    Text("\(DataStore.shared.meetings.count)")
                }

                LabeledContent("Goals") {
                    Text("\(DataStore.shared.goals.count)")
                }
            }

            Section("Actions") {
                Button("Export Data...") {
                    Task {
                        await syncService.exportData()
                    }
                }

                Button("Import Data...") {
                    Task {
                        await syncService.importData()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - Calendar Settings

    #if !os(tvOS)
    private var calendarSettings: some View {
        Form {
            Section("Calendar Access") {
                if calendarService.isAuthorized {
                    Label("Calendar access granted", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Label("Calendar access required", systemImage: "exclamationmark.circle.fill")
                        .foregroundColor(.orange)

                    Button("Grant Access") {
                        Task {
                            await calendarService.requestAccess()
                        }
                    }
                }
            }

            if calendarService.isAuthorized {
                Section("Default Calendar") {
                    Picker("Calendar", selection: $calendarService.selectedCalendarId) {
                        ForEach(calendarService.calendars, id: \.calendarIdentifier) { calendar in
                            Text(calendar.title)
                                .tag(calendar.calendarIdentifier as String?)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
    #else
    private var calendarSettings: some View {
        VStack {
            Text("Calendar")
                .font(.title2)
            Text("Calendar integration is not available on tvOS")
                .foregroundColor(.secondary)
        }
        .padding()
    }
    #endif

    // MARK: - AI Settings

    private var aiSettings: some View {
        Form {
            Section("Model") {
                TextField("Model Path", text: $aiModelPath)
                    .textFieldStyle(.roundedBorder)

                Text("Supported models: Llama 3.2, Qwen 2.5, Mistral, Phi-3.5")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("About") {
                Text("AI features use local MLX models for privacy-focused, offline inference.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - Backup Settings

    private var backupSettings: some View {
        Form {
            Section("Automatic Backup") {
                Toggle("Enable Auto-Backup", isOn: $autoBackupEnabled)

                if autoBackupEnabled {
                    Picker("Frequency", selection: $backupFrequency) {
                        Text("Daily").tag("Daily")
                        Text("Weekly").tag("Weekly")
                        Text("Monthly").tag("Monthly")
                    }
                }
            }

            Section("Manual Backup") {
                Button("Create Backup Now") {
                    Task {
                        try? await syncService.createBackup()
                    }
                }
            }

            Section("Backup History") {
                let backups = syncService.listBackups()
                if backups.isEmpty {
                    Text("No backups found")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(backups.prefix(5), id: \.url) { backup in
                        HStack {
                            Text(backup.date.formatted())
                            Spacer()
                            Button("Restore") {
                                Task {
                                    try? await syncService.restoreBackup(from: backup.url)
                                }
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

#Preview {
    SettingsView()
        .environmentObject(CalendarService.shared)
        .environmentObject(SyncService.shared)
}
