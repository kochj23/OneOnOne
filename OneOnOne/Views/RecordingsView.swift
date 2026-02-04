//
//  RecordingsView.swift
//  OneOnOne
//
//  Voice recording and transcription view
//  Created by Jordan Koch on 2026-02-02.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

#if os(macOS)
import AVFoundation

struct RecordingsView: View {
    @EnvironmentObject var dataStore: DataStore
    @StateObject private var recordingService = RecordingService.shared
    @State private var selectedRecording: Recording?
    @State private var selectedMeeting: UUID?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
                .padding(24)

            Divider()
                .background(ModernColors.glassBorder)

            // Content
            HStack(spacing: 0) {
                // Recordings list
                recordingsList
                    .frame(maxWidth: .infinity)

                Divider()
                    .background(ModernColors.glassBorder)

                // Active recording / details sidebar
                recordingSidebar
                    .frame(width: 320)
            }
        }
        .sheet(item: $selectedRecording) { recording in
            TranscriptionView(recording: recording)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Recordings")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(ModernColors.textPrimary)

                Text("Voice recordings and transcriptions")
                    .font(.system(size: 14))
                    .foregroundColor(ModernColors.textSecondary)
            }

            Spacer()

            // Meeting selector for recording
            if !recordingService.isRecording {
                Menu {
                    ForEach(dataStore.meetings.sorted { $0.date > $1.date }.prefix(10)) { meeting in
                        Button {
                            selectedMeeting = meeting.id
                        } label: {
                            Text(meeting.title)
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "calendar")
                        Text(selectedMeeting.flatMap { id in
                            dataStore.meetings.first { $0.id == id }?.title
                        } ?? "Select Meeting")
                    }
                    .foregroundColor(ModernColors.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(8)
                }
            }
        }
    }

    // MARK: - Recordings List

    private var recordingsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if dataStore.recordings.isEmpty {
                    emptyState
                } else {
                    ForEach(dataStore.recordings.sorted { $0.createdAt > $1.createdAt }) { recording in
                        RecordingRow(recording: recording) {
                            selectedRecording = recording
                        }
                    }
                }
            }
            .padding(24)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform")
                .font(.system(size: 48))
                .foregroundColor(ModernColors.textTertiary)

            Text("No recordings yet")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(ModernColors.textSecondary)

            Text("Record meetings to automatically generate transcriptions and extract action items")
                .font(.system(size: 14))
                .foregroundColor(ModernColors.textTertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
        }
        .frame(maxWidth: .infinity)
        .padding(60)
    }

    // MARK: - Recording Sidebar

    private var recordingSidebar: some View {
        VStack(spacing: 0) {
            if recordingService.isRecording {
                activeRecordingView
            } else {
                startRecordingView
            }
        }
        .background(Color.black.opacity(0.2))
    }

    private var activeRecordingView: some View {
        VStack(spacing: 24) {
            Spacer()

            // Waveform visualization
            HStack(spacing: 4) {
                ForEach(0..<20, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(ModernColors.red)
                        .frame(width: 4, height: CGFloat.random(in: 10...50) * CGFloat(recordingService.audioLevel + 0.3))
                }
            }
            .frame(height: 60)
            .animation(.easeInOut(duration: 0.1), value: recordingService.audioLevel)

            // Duration
            Text(formatDuration(recordingService.recordingDuration))
                .font(.system(size: 48, weight: .bold, design: .monospaced))
                .foregroundColor(ModernColors.textPrimary)

            Text("Recording...")
                .font(.system(size: 14))
                .foregroundColor(ModernColors.red)

            Spacer()

            // Controls
            HStack(spacing: 24) {
                Button {
                    // Pause/Resume (not fully implemented)
                } label: {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 24))
                        .foregroundColor(ModernColors.textSecondary)
                        .frame(width: 56, height: 56)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(28)
                }
                .buttonStyle(.plain)

                Button {
                    stopRecording()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.white)
                        .frame(width: 72, height: 72)
                        .background(ModernColors.red)
                        .cornerRadius(36)
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(24)
    }

    private var startRecordingView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "mic.fill")
                .font(.system(size: 48))
                .foregroundColor(ModernColors.textTertiary)

            Text("Ready to Record")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(ModernColors.textSecondary)

            // Consent notice
            VStack(spacing: 12) {
                Image(systemName: "info.circle")
                    .foregroundColor(ModernColors.orange)
                Text("Please ensure all participants consent to being recorded")
                    .font(.system(size: 12))
                    .foregroundColor(ModernColors.textTertiary)
                    .multilineTextAlignment(.center)
            }
            .padding(16)
            .background(ModernColors.orange.opacity(0.1))
            .cornerRadius(12)

            Spacer()

            Button {
                startRecording()
            } label: {
                HStack {
                    Image(systemName: "mic.fill")
                    Text("Start Recording")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(selectedMeeting != nil ? ModernColors.red : ModernColors.textTertiary)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
            .disabled(selectedMeeting == nil)

            if selectedMeeting == nil {
                Text("Select a meeting first")
                    .font(.system(size: 12))
                    .foregroundColor(ModernColors.textTertiary)
            }

            Spacer()
        }
        .padding(24)
    }

    // MARK: - Actions

    private func startRecording() {
        guard let meetingId = selectedMeeting else { return }

        do {
            try recordingService.startRecording(for: meetingId, hasConsent: true)
        } catch {
            print("Failed to start recording: \(error)")
        }
    }

    private func stopRecording() {
        if let recording = recordingService.stopRecording() {
            dataStore.addRecording(recording)
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Recording Row

struct RecordingRow: View {
    let recording: Recording
    let action: () -> Void
    @EnvironmentObject var dataStore: DataStore

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: recording.transcription != nil ? "doc.text" : "waveform")
                    .font(.system(size: 24))
                    .foregroundColor(recording.transcription != nil ? ModernColors.accentGreen : ModernColors.cyan)
                    .frame(width: 48, height: 48)
                    .background((recording.transcription != nil ? ModernColors.accentGreen : ModernColors.cyan).opacity(0.15))
                    .cornerRadius(12)

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    if let meeting = dataStore.meetings.first(where: { $0.id == recording.meetingId }) {
                        Text(meeting.title)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(ModernColors.textPrimary)
                            .lineLimit(1)
                    } else {
                        Text("Unknown Meeting")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(ModernColors.textPrimary)
                    }

                    HStack(spacing: 12) {
                        Label(recording.formattedDuration, systemImage: "clock")
                        Label(recording.formattedFileSize, systemImage: "doc")
                        if recording.transcription != nil {
                            Label("Transcribed", systemImage: "checkmark.circle")
                                .foregroundColor(ModernColors.accentGreen)
                        }
                    }
                    .font(.system(size: 12))
                    .foregroundColor(ModernColors.textTertiary)
                }

                Spacer()

                Text(recording.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 12))
                    .foregroundColor(ModernColors.textTertiary)

                Image(systemName: "chevron.right")
                    .foregroundColor(ModernColors.textTertiary)
            }
            .padding(16)
            .glassCard()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Transcription View

struct TranscriptionView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var dataStore: DataStore
    @StateObject private var recordingService = RecordingService.shared
    let recording: Recording
    @State private var editedRecording: Recording
    @State private var isTranscribing = false
    @State private var transcriptionError: String?

    init(recording: Recording) {
        self.recording = recording
        _editedRecording = State(initialValue: recording)
    }

    var body: some View {
        ZStack {
            ModernColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Recording Details")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(ModernColors.textPrimary)

                    Spacer()

                    if editedRecording.transcription == nil && !isTranscribing {
                        Button {
                            transcribe()
                        } label: {
                            Label("Transcribe", systemImage: "waveform")
                                .primaryButton()
                        }
                        .buttonStyle(.plain)
                    }

                    Button("Done") {
                        dataStore.updateRecording(editedRecording)
                        dismiss()
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(ModernColors.cyan)
                }
                .padding(24)

                Divider()
                    .background(ModernColors.glassBorder)

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Recording info
                        HStack(spacing: 20) {
                            infoCard("Duration", value: recording.formattedDuration, icon: "clock")
                            infoCard("Size", value: recording.formattedFileSize, icon: "doc")
                            infoCard("Created", value: recording.createdAt.formatted(date: .abbreviated, time: .shortened), icon: "calendar")
                        }

                        // Transcription status
                        if isTranscribing {
                            VStack(spacing: 12) {
                                ProgressView()
                                Text("Transcribing audio...")
                                    .font(.system(size: 14))
                                    .foregroundColor(ModernColors.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(40)
                            .glassCard()
                        } else if let error = transcriptionError {
                            VStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 32))
                                    .foregroundColor(ModernColors.red)
                                Text(error)
                                    .font(.system(size: 14))
                                    .foregroundColor(ModernColors.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(40)
                            .glassCard()
                        } else if let transcription = editedRecording.transcription {
                            // Transcription content
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Text("Transcription")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(ModernColors.textPrimary)

                                    Spacer()

                                    HStack(spacing: 12) {
                                        Text("\(transcription.wordCount) words")
                                        Text("•")
                                        Text(transcription.language.uppercased())
                                        Text("•")
                                        Text(String(format: "%.1fs processing", transcription.processingTime))
                                    }
                                    .font(.system(size: 12))
                                    .foregroundColor(ModernColors.textTertiary)
                                }

                                Text(transcription.text)
                                    .font(.system(size: 14))
                                    .foregroundColor(ModernColors.textSecondary)
                                    .lineSpacing(6)
                                    .textSelection(.enabled)
                            }
                            .padding(20)
                            .glassCard()

                            // Segments (if available)
                            if !transcription.segments.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Timeline")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(ModernColors.textPrimary)

                                    ForEach(transcription.segments) { segment in
                                        HStack(alignment: .top, spacing: 12) {
                                            Text(segment.formattedTimeRange)
                                                .font(.system(size: 11, design: .monospaced))
                                                .foregroundColor(ModernColors.cyan)
                                                .frame(width: 80, alignment: .leading)

                                            Text(segment.text)
                                                .font(.system(size: 13))
                                                .foregroundColor(ModernColors.textSecondary)
                                        }
                                        .padding(8)
                                        .background(Color.white.opacity(0.02))
                                        .cornerRadius(6)
                                    }
                                }
                                .padding(20)
                                .glassCard()
                            }
                        } else {
                            // No transcription yet
                            VStack(spacing: 12) {
                                Image(systemName: "waveform")
                                    .font(.system(size: 32))
                                    .foregroundColor(ModernColors.textTertiary)
                                Text("No transcription yet")
                                    .font(.system(size: 14))
                                    .foregroundColor(ModernColors.textSecondary)
                                Text("Click 'Transcribe' to generate a transcription using AI")
                                    .font(.system(size: 12))
                                    .foregroundColor(ModernColors.textTertiary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(40)
                            .glassCard()
                        }

                        // Delete button
                        Button {
                            deleteRecording()
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                Text("Delete Recording")
                            }
                            .foregroundColor(ModernColors.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(ModernColors.red.opacity(0.1))
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(24)
                }
            }
        }
        .frame(width: 700, height: 700)
    }

    private func infoCard(_ title: String, value: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(ModernColors.cyan)

            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(ModernColors.textPrimary)

            Text(title)
                .font(.system(size: 11))
                .foregroundColor(ModernColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .glassCard()
    }

    private func transcribe() {
        isTranscribing = true
        transcriptionError = nil

        Task {
            do {
                let transcription = try await recordingService.transcribe(recording: recording)
                editedRecording.transcription = transcription
                dataStore.updateRecording(editedRecording)
            } catch {
                transcriptionError = error.localizedDescription
            }
            isTranscribing = false
        }
    }

    private func deleteRecording() {
        recordingService.deleteRecording(recording)
        dataStore.deleteRecording(id: recording.id)
        dismiss()
    }
}

#Preview {
    RecordingsView()
        .environmentObject(DataStore.shared)
}
#endif  // os(macOS)
