//
//  EditMeetingView.swift
//  OneOnOne
//
//  View for editing existing meeting details
//  Created by Jordan Koch on 2026-02-19.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

struct EditMeetingView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.dismiss) private var dismiss
    @Binding var meeting: Meeting

    @State private var title: String
    @State private var meetingType: MeetingType
    @State private var date: Date
    @State private var duration: TimeInterval
    @State private var selectedAttendees: Set<UUID>
    @State private var location: String
    @State private var agenda: String
    @State private var isRecurring: Bool
    @State private var frequency: MeetingFrequency
    @State private var mood: MeetingMood?

    let durationOptions: [(label: String, value: TimeInterval)] = [
        ("15 min", 900),
        ("30 min", 1800),
        ("45 min", 2700),
        ("1 hour", 3600),
        ("1.5 hours", 5400),
        ("2 hours", 7200)
    ]

    init(meeting: Binding<Meeting>) {
        _meeting = meeting
        let m = meeting.wrappedValue
        _title = State(initialValue: m.title)
        _meetingType = State(initialValue: m.meetingType)
        _date = State(initialValue: m.date)
        _duration = State(initialValue: m.duration)
        _selectedAttendees = State(initialValue: Set(m.attendees))
        _location = State(initialValue: m.location ?? "")
        _agenda = State(initialValue: m.agenda ?? "")
        _isRecurring = State(initialValue: m.isRecurring)
        _frequency = State(initialValue: .weekly)
        _mood = State(initialValue: m.mood)
    }

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

                    // Mood
                    formSection(title: "Meeting Mood (Optional)") {
                        HStack(spacing: 10) {
                            // None option
                            Button {
                                mood = nil
                            } label: {
                                Text("None")
                                    .font(.system(size: 13, weight: mood == nil ? .semibold : .medium))
                                    .foregroundColor(mood == nil ? .white : ModernColors.textSecondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(mood == nil ? ModernColors.accentBlue : Color.white.opacity(0.05))
                                    .cornerRadius(10)
                            }
                            .buttonStyle(.plain)

                            ForEach(MeetingMood.allCases, id: \.self) { m in
                                Button {
                                    mood = m
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: m.icon)
                                        Text(m.rawValue)
                                    }
                                    .font(.system(size: 13, weight: mood == m ? .semibold : .medium))
                                    .foregroundColor(mood == m ? .white : ModernColors.textSecondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(mood == m ? Color(hex: m.color) : Color.white.opacity(0.05))
                                    .cornerRadius(10)
                                }
                                .buttonStyle(.plain)
                            }
                        }
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
            .navigationTitle("Edit Meeting")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveMeeting()
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

    private func saveMeeting() {
        meeting.title = title
        meeting.meetingType = meetingType
        meeting.date = date
        meeting.duration = duration
        meeting.attendees = Array(selectedAttendees)
        meeting.location = location.isEmpty ? nil : location
        meeting.agenda = agenda.isEmpty ? nil : agenda
        meeting.mood = mood
        meeting.isRecurring = isRecurring
        if isRecurring && meeting.recurringId == nil {
            meeting.recurringId = UUID()
        } else if !isRecurring {
            meeting.recurringId = nil
        }
        meeting.updatedAt = Date()
        dismiss()
    }
}

#Preview {
    EditMeetingView(meeting: .constant(Meeting(title: "Test Meeting")))
        .environmentObject(DataStore.shared)
}
