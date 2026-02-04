//
//  NewMeetingView.swift
//  OneOnOne
//
//  View for creating a new meeting
//  Created by Jordan Koch on 2026-02-02.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

struct NewMeetingView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var meetingType: MeetingType = .oneOnOne
    @State private var date = Date()
    @State private var duration: TimeInterval = 3600
    @State private var selectedAttendees: Set<UUID> = []
    @State private var location = ""
    @State private var agenda = ""
    @State private var isRecurring = false
    @State private var frequency: MeetingFrequency = .weekly

    let durationOptions: [(label: String, value: TimeInterval)] = [
        ("15 min", 900),
        ("30 min", 1800),
        ("45 min", 2700),
        ("1 hour", 3600),
        ("1.5 hours", 5400),
        ("2 hours", 7200)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Title
                    formSection(title: "Meeting Title") {
                        TextField("What's this meeting about?", text: $title)
                            .textFieldStyle(.plain)
                            .font(.system(size: 16))
                            .foregroundColor(ModernColors.textPrimary)
                            .padding(12)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(10)
                    }

                    // Type
                    formSection(title: "Meeting Type") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 10) {
                            ForEach(MeetingType.allCases, id: \.self) { type in
                                Button {
                                    meetingType = type
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: type.icon)
                                        Text(type.rawValue)
                                    }
                                    .font(.system(size: 13, weight: meetingType == type ? .semibold : .medium))
                                    .foregroundColor(meetingType == type ? .white : ModernColors.textSecondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(meetingType == type ? ModernColors.accentBlue : Color.white.opacity(0.05))
                                    .cornerRadius(10)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Date and Duration
                    HStack(spacing: 20) {
                        formSection(title: "Date & Time") {
                            DatePicker("", selection: $date)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                        }

                        formSection(title: "Duration") {
                            Picker("Duration", selection: $duration) {
                                ForEach(durationOptions, id: \.value) { option in
                                    Text(option.label).tag(option.value)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }

                    // Attendees
                    formSection(title: "Attendees") {
                        if dataStore.people.isEmpty {
                            Text("No people added yet")
                                .font(.system(size: 14))
                                .foregroundColor(ModernColors.textTertiary)
                        } else {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 10) {
                                ForEach(dataStore.people) { person in
                                    Button {
                                        if selectedAttendees.contains(person.id) {
                                            selectedAttendees.remove(person.id)
                                        } else {
                                            selectedAttendees.insert(person.id)
                                        }
                                    } label: {
                                        HStack(spacing: 8) {
                                            Text(person.initials)
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(.white)
                                                .frame(width: 28, height: 28)
                                                .background(Color(hex: person.avatarColor))
                                                .cornerRadius(14)

                                            Text(person.name.components(separatedBy: " ").first ?? "")
                                                .font(.system(size: 13))
                                                .foregroundColor(selectedAttendees.contains(person.id) ? .white : ModernColors.textSecondary)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(selectedAttendees.contains(person.id) ? ModernColors.purple : Color.white.opacity(0.05))
                                        .cornerRadius(10)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    // Location
                    formSection(title: "Location (Optional)") {
                        TextField("Office, Zoom, etc.", text: $location)
                            .textFieldStyle(.plain)
                            .font(.system(size: 16))
                            .foregroundColor(ModernColors.textPrimary)
                            .padding(12)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(10)
                    }

                    // Agenda
                    formSection(title: "Agenda (Optional)") {
                        TextEditor(text: $agenda)
                            .font(.system(size: 14))
                            .foregroundColor(ModernColors.textPrimary)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 100)
                            .padding(12)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(10)
                    }

                    // Recurring
                    formSection(title: "Recurring") {
                        HStack {
                            Toggle("Make this a recurring meeting", isOn: $isRecurring)
                                #if os(macOS)
                                .toggleStyle(.checkbox)
                                #endif
                                .foregroundColor(ModernColors.textSecondary)

                            if isRecurring {
                                Picker("", selection: $frequency) {
                                    ForEach(MeetingFrequency.allCases, id: \.self) { freq in
                                        Text(freq.rawValue).tag(freq)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(width: 120)
                            }

                            Spacer()
                        }
                    }
                }
                .padding(32)
            }
            .background(GlassmorphicBackground())
            .navigationTitle("New Meeting")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createMeeting()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }

    private func formSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(ModernColors.textTertiary)

            content()
        }
    }

    private func createMeeting() {
        let meeting = Meeting(
            title: title,
            date: date,
            duration: duration,
            attendees: Array(selectedAttendees),
            meetingType: meetingType,
            location: location.isEmpty ? nil : location,
            agenda: agenda.isEmpty ? nil : agenda,
            isRecurring: isRecurring,
            recurringId: isRecurring ? UUID() : nil
        )

        dataStore.addMeeting(meeting)
        dismiss()
    }
}

#Preview {
    NewMeetingView()
        .environmentObject(DataStore.shared)
}
