//
//  OLMImportView.swift
//  OneOnOne
//
//  Sheet-based UI for importing calendar events from Outlook .olm export files
//  Provides file selection, event preview with filtering, and batch import
//
//  Created by Jordan Koch on 2026-02-19.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI
import UniformTypeIdentifiers

#if os(macOS)

// MARK: - Import Phase

private enum OLMImportPhase {
    case idle
    case extracting
    case preview(OLMParseResult)
    case importing(total: Int, completed: Int)
    case complete(OutlookWebImportResult)
    case error(String)
}

// MARK: - OLM Import View

struct OLMImportView: View {
    @Environment(\.dismiss) var dismiss

    @State private var phase: OLMImportPhase = .idle
    @State private var futureOnly = true
    @State private var skipExisting = true
    @State private var selectedFileName: String?

    private let importService = OLMImportService()

    var body: some View {
        ZStack {
            ModernColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(24)

                Divider()
                    .background(ModernColors.glassBorder)

                content
            }
        }
        .frame(width: 900, height: 700)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    Image(systemName: "doc.zipper")
                        .font(.system(size: 28))
                        .foregroundColor(Color(hex: "#0078D4"))

                    Text("Import OLM File")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(ModernColors.textPrimary)
                }

                Text("Import calendar events from an Outlook for Mac export file")
                    .font(.system(size: 14))
                    .foregroundColor(ModernColors.textSecondary)
            }

            Spacer()

            Button("Cancel") {
                dismiss()
            }
            .buttonStyle(.plain)
            .foregroundColor(ModernColors.textSecondary)
        }
    }

    // MARK: - Content Router

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .idle:
            idleView
        case .extracting:
            extractingView
        case .preview(let result):
            previewView(result)
        case .importing(let total, let completed):
            importingView(total: total, completed: completed)
        case .complete(let result):
            completeView(result)
        case .error(let message):
            errorView(message)
        }
    }

    // MARK: - Idle View

    private var idleView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "doc.zipper")
                .font(.system(size: 64))
                .foregroundColor(ModernColors.textTertiary)

            VStack(spacing: 8) {
                Text("Select an OLM File")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(ModernColors.textPrimary)

                Text("Choose an Outlook for Mac export (.olm) file to import calendar events.\nNo sign-in required — works completely offline.")
                    .font(.system(size: 14))
                    .foregroundColor(ModernColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            Button {
                selectFile()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "folder")
                    Text("Choose OLM File...")
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
                .background(Color(hex: "#0078D4"))
                .cornerRadius(12)
            }
            .buttonStyle(.plain)

            VStack(spacing: 4) {
                Text("How to export from Outlook for Mac:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(ModernColors.textTertiary)

                Text("File → Export... → Select Calendar → Save as .olm")
                    .font(.system(size: 12))
                    .foregroundColor(ModernColors.textTertiary)
            }

            Spacer()
        }
        .padding(48)
    }

    // MARK: - Extracting View

    private var extractingView: some View {
        VStack(spacing: 24) {
            Spacer()

            ProgressView()
                .scaleEffect(1.5)

            VStack(spacing: 8) {
                Text("Extracting Calendar Events...")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(ModernColors.textPrimary)

                if let name = selectedFileName {
                    Text(name)
                        .font(.system(size: 14))
                        .foregroundColor(ModernColors.textSecondary)
                }

                Text("Parsing OLM archive and reading calendar data")
                    .font(.system(size: 13))
                    .foregroundColor(ModernColors.textTertiary)
            }

            Spacer()
        }
    }

    // MARK: - Preview View

    private func previewView(_ result: OLMParseResult) -> some View {
        let filtered = filteredEvents(from: result)

        return VStack(spacing: 0) {
            // Filter bar
            HStack(spacing: 24) {
                // Event count
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(result.events.count) events found")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(ModernColors.textPrimary)

                    if filtered.count != result.events.count {
                        Text("\(filtered.count) after filtering")
                            .font(.system(size: 13))
                            .foregroundColor(ModernColors.textSecondary)
                    }
                }

                Spacer()

                // Toggles
                Toggle("Future events only", isOn: $futureOnly)
                    .toggleStyle(.switch)
                    .font(.system(size: 13))
                    .foregroundColor(ModernColors.textSecondary)

                Toggle("Skip already imported", isOn: $skipExisting)
                    .toggleStyle(.switch)
                    .font(.system(size: 13))
                    .foregroundColor(ModernColors.textSecondary)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color.black.opacity(0.15))

            // Parse errors warning
            if !result.parseErrors.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(ModernColors.orange)
                    Text("\(result.parseErrors.count) file(s) had parse errors")
                        .font(.system(size: 13))
                        .foregroundColor(ModernColors.orange)
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(ModernColors.orange.opacity(0.1))
            }

            // Events list
            if filtered.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 40))
                        .foregroundColor(ModernColors.textTertiary)
                    Text("No events match the current filters")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(ModernColors.textSecondary)
                    Text("Try disabling the filters above")
                        .font(.system(size: 13))
                        .foregroundColor(ModernColors.textTertiary)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(filtered) { event in
                            eventRow(event)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }

            // Import button
            HStack {
                if !result.parseErrors.isEmpty {
                    Text("\(result.totalFilesScanned) files scanned")
                        .font(.system(size: 12))
                        .foregroundColor(ModernColors.textTertiary)
                }

                Spacer()

                Button {
                    if case .preview(let r) = phase {
                        performImport(events: self.filteredEvents(from: r))
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.down")
                        Text("Import \(filtered.count) Events")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(filtered.isEmpty ? Color.gray.opacity(0.3) : Color(hex: "#0078D4"))
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .disabled(filtered.isEmpty)
            }
            .padding(24)
            .background(Color.black.opacity(0.2))
        }
    }

    private func eventRow(_ event: OLMCalendarEvent) -> some View {
        HStack(spacing: 12) {
            // Type icon
            let meetingType = OutlookCalendarService.inferMeetingType(
                subject: event.subject,
                attendeeCount: event.attendees.count
            )
            Image(systemName: meetingType.icon)
                .foregroundColor(ModernColors.cyan)
                .frame(width: 28)

            // Event info
            VStack(alignment: .leading, spacing: 2) {
                Text(event.subject)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ModernColors.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 12) {
                    if let date = event.startDate {
                        Text(date.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 12))
                            .foregroundColor(ModernColors.textTertiary)
                    }

                    if let location = event.location, !location.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 9))
                            Text(location)
                                .lineLimit(1)
                        }
                        .font(.system(size: 11))
                        .foregroundColor(ModernColors.textTertiary)
                    }
                }
            }

            Spacer()

            // Attendee count
            if !event.attendees.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "person.2")
                        .font(.system(size: 11))
                    Text("\(event.attendees.count)")
                        .font(.system(size: 12))
                }
                .foregroundColor(ModernColors.textTertiary)
            }

            // Meeting type badge
            Text(meetingType.rawValue)
                .font(.system(size: 11))
                .foregroundColor(ModernColors.textTertiary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(ModernColors.glassBorder)
                .cornerRadius(6)

            // Recurring badge
            if event.isRecurring {
                Image(systemName: "repeat")
                    .font(.system(size: 11))
                    .foregroundColor(ModernColors.cyan)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
    }

    // MARK: - Importing View

    private func importingView(total: Int, completed: Int) -> some View {
        VStack(spacing: 24) {
            Spacer()

            ProgressView(value: Double(completed), total: Double(max(total, 1)))
                .progressViewStyle(.linear)
                .frame(width: 300)

            VStack(spacing: 8) {
                Text("Importing Events...")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(ModernColors.textPrimary)

                Text("\(completed) of \(total)")
                    .font(.system(size: 14))
                    .foregroundColor(ModernColors.textSecondary)
            }

            Spacer()
        }
    }

    // MARK: - Complete View

    private func completeView(_ result: OutlookWebImportResult) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Summary
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(ModernColors.accentGreen)

                    Text("Import Complete")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(ModernColors.textPrimary)

                    HStack(spacing: 32) {
                        statItem(value: "\(result.importedCount)", label: "Imported", color: ModernColors.accentGreen)
                        statItem(value: "\(result.skippedCount)", label: "Skipped", color: ModernColors.cyan)
                        if result.failedCount > 0 {
                            statItem(value: "\(result.failedCount)", label: "Failed", color: ModernColors.red)
                        }
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .glassCard()

                // Imported meetings list
                if !result.importedMeetings.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Imported Meetings")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(ModernColors.textPrimary)

                        ForEach(result.importedMeetings.prefix(20)) { meeting in
                            HStack(spacing: 12) {
                                Image(systemName: meeting.meetingType.icon)
                                    .foregroundColor(ModernColors.cyan)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(meeting.title)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(ModernColors.textPrimary)

                                    Text(meeting.date.formatted(date: .abbreviated, time: .shortened))
                                        .font(.system(size: 12))
                                        .foregroundColor(ModernColors.textTertiary)
                                }

                                Spacer()

                                Text(meeting.meetingType.rawValue)
                                    .font(.system(size: 11))
                                    .foregroundColor(ModernColors.textTertiary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(ModernColors.glassBorder)
                                    .cornerRadius(6)
                            }
                            .padding(.vertical, 4)
                        }

                        if result.importedMeetings.count > 20 {
                            Text("...and \(result.importedMeetings.count - 20) more")
                                .font(.system(size: 13))
                                .foregroundColor(ModernColors.textTertiary)
                        }
                    }
                    .padding(16)
                    .glassCard()
                }

                // Done button
                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .frame(maxWidth: .infinity)
                        .primaryButton()
                }
                .buttonStyle(.plain)
            }
            .padding(24)
        }
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(ModernColors.red)

            VStack(spacing: 8) {
                Text("Import Failed")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(ModernColors.textPrimary)

                Text(message)
                    .font(.system(size: 14))
                    .foregroundColor(ModernColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            HStack(spacing: 16) {
                Button {
                    phase = .idle
                } label: {
                    Text("Try Again")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Color(hex: "#0078D4"))
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)

                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundColor(ModernColors.textSecondary)
            }

            Spacer()
        }
    }

    // MARK: - Helpers

    private func statItem(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(ModernColors.textSecondary)
        }
    }

    private func filteredEvents(from result: OLMParseResult) -> [OLMCalendarEvent] {
        let dataStore = DataStore.shared
        let existingIds = Set(dataStore.meetings.compactMap { $0.outlookEventId })

        return result.events.filter { event in
            // Future only filter
            if futureOnly {
                guard let start = event.startDate, start > Date() else { return false }
            }

            // Skip already imported
            if skipExisting {
                if existingIds.contains(event.id) { return false }
            }

            return true
        }
    }

    // MARK: - Actions

    private func selectFile() {
        let panel = NSOpenPanel()
        panel.title = "Select Outlook Export File"
        panel.allowedContentTypes = [
            UTType(filenameExtension: "olm") ?? .data
        ]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        selectedFileName = url.lastPathComponent
        phase = .extracting

        Task {
            do {
                let result = try await importService.parseOLMFile(at: url)
                await MainActor.run {
                    phase = .preview(result)
                }
            } catch {
                await MainActor.run {
                    phase = .error(error.localizedDescription)
                }
            }
        }
    }

    private func performImport(events: [OLMCalendarEvent]) {
        let total = events.count
        phase = .importing(total: total, completed: 0)

        Task {
            let dataStore = DataStore.shared
            let existingMeetings = dataStore.meetings
            var importedMeetings: [Meeting] = []
            var skippedCount = 0
            var failedCount = 0

            for (index, event) in events.enumerated() {
                // Skip if already imported
                if existingMeetings.contains(where: { $0.outlookEventId == event.olmMessageId }) {
                    skippedCount += 1
                    await MainActor.run {
                        phase = .importing(total: total, completed: index + 1)
                    }
                    continue
                }

                // Determine meeting type
                let meetingType = OutlookCalendarService.inferMeetingType(
                    subject: event.subject,
                    attendeeCount: event.attendees.count
                )

                // Match attendees to existing People by email
                let matchedAttendees: [UUID] = event.attendees.compactMap { attendee in
                    let email = attendee.email.lowercased()
                    return dataStore.people.first { $0.email?.lowercased() == email }?.id
                }

                // Create meeting
                let meeting = Meeting(
                    id: UUID(),
                    title: event.subject,
                    date: event.startDate ?? Date(),
                    duration: event.duration,
                    attendees: matchedAttendees,
                    meetingType: meetingType,
                    location: event.location,
                    outlookEventId: event.olmMessageId,
                    agenda: event.body,
                    notes: "",
                    isRecurring: event.isRecurring
                )

                await MainActor.run {
                    dataStore.addMeeting(meeting)
                    importedMeetings.append(meeting)
                    phase = .importing(total: total, completed: index + 1)
                }
            }

            // Sync widget data
            await MainActor.run {
                WidgetSyncService.shared.syncToWidget()

                let result = OutlookWebImportResult(
                    importedCount: importedMeetings.count,
                    skippedCount: skippedCount,
                    failedCount: failedCount,
                    importedMeetings: importedMeetings
                )
                phase = .complete(result)

                print("OLMImport: Imported \(importedMeetings.count) meetings, skipped \(skippedCount), failed \(failedCount)")
            }
        }
    }
}

#endif  // os(macOS)
