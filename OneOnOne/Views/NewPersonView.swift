//
//  NewPersonView.swift
//  OneOnOne
//
//  View for creating a new person
//  Created by Jordan Koch on 2026-02-02.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

struct NewPersonView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var email = ""
    @State private var title = ""
    @State private var department = ""
    @State private var notes = ""
    @State private var meetingFrequency: MeetingFrequency = .weekly
    @State private var avatarColor = Person.randomAvatarColor()
    @State private var tags: [String] = []
    @State private var newTag = ""

    let colorOptions = [
        "#3BDAFC", "#9966FF", "#FF5999", "#FF9933", "#4DE094", "#5AB3FF"
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Avatar preview
                    HStack {
                        Spacer()

                        Text(initials)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 80, height: 80)
                            .background(Color(hex: avatarColor))
                            .cornerRadius(40)

                        Spacer()
                    }

                    // Color picker
                    formSection(title: "Avatar Color") {
                        HStack(spacing: 12) {
                            ForEach(colorOptions, id: \.self) { color in
                                Button {
                                    avatarColor = color
                                } label: {
                                    Circle()
                                        .fill(Color(hex: color))
                                        .frame(width: 36, height: 36)
                                        .overlay(
                                            Circle()
                                                .stroke(avatarColor == color ? Color.white : Color.clear, lineWidth: 3)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Name
                    formSection(title: "Name *") {
                        TextField("Full name", text: $name)
                            .textFieldStyle(.plain)
                            .font(.system(size: 16))
                            .foregroundColor(ModernColors.textPrimary)
                            .padding(12)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(10)
                    }

                    // Email
                    formSection(title: "Email") {
                        TextField("email@example.com", text: $email)
                            .textFieldStyle(.plain)
                            .font(.system(size: 16))
                            .foregroundColor(ModernColors.textPrimary)
                            .padding(12)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(10)
                    }

                    // Title and Department
                    HStack(spacing: 20) {
                        formSection(title: "Job Title") {
                            TextField("Software Engineer", text: $title)
                                .textFieldStyle(.plain)
                                .font(.system(size: 16))
                                .foregroundColor(ModernColors.textPrimary)
                                .padding(12)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(10)
                        }

                        formSection(title: "Department") {
                            TextField("Engineering", text: $department)
                                .textFieldStyle(.plain)
                                .font(.system(size: 16))
                                .foregroundColor(ModernColors.textPrimary)
                                .padding(12)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(10)
                        }
                    }

                    // Meeting Frequency
                    formSection(title: "Meeting Frequency") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 10) {
                            ForEach(MeetingFrequency.allCases, id: \.self) { freq in
                                Button {
                                    meetingFrequency = freq
                                } label: {
                                    Text(freq.rawValue)
                                        .font(.system(size: 13, weight: meetingFrequency == freq ? .semibold : .medium))
                                        .foregroundColor(meetingFrequency == freq ? .white : ModernColors.textSecondary)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(meetingFrequency == freq ? ModernColors.purple : Color.white.opacity(0.05))
                                        .cornerRadius(10)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Tags
                    formSection(title: "Tags") {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 10) {
                                TextField("Add tag...", text: $newTag)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 14))
                                    .foregroundColor(ModernColors.textPrimary)
                                    .padding(10)
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(8)

                                Button {
                                    addTag()
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(ModernColors.accentGreen)
                                }
                                .buttonStyle(.plain)
                                .disabled(newTag.isEmpty)
                            }

                            if !tags.isEmpty {
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 8) {
                                    ForEach(tags, id: \.self) { tag in
                                        HStack(spacing: 4) {
                                            Text(tag)
                                                .font(.system(size: 12))

                                            Button {
                                                tags.removeAll { $0 == tag }
                                            } label: {
                                                Image(systemName: "xmark")
                                                    .font(.system(size: 10))
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        .foregroundColor(ModernColors.textSecondary)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color.white.opacity(0.1))
                                        .cornerRadius(8)
                                    }
                                }
                            }
                        }
                    }

                    // Notes
                    formSection(title: "Notes") {
                        TextEditor(text: $notes)
                            .font(.system(size: 14))
                            .foregroundColor(ModernColors.textPrimary)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 80)
                            .padding(12)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(10)
                    }
                }
                .padding(32)
            }
            .background(GlassmorphicBackground())
            .navigationTitle("New Person")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        createPerson()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }

    private var initials: String {
        let components = name.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
        } else if let first = components.first {
            return String(first.prefix(2)).uppercased()
        }
        return "?"
    }

    private func formSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(ModernColors.textTertiary)

            content()
        }
    }

    private func addTag() {
        let trimmed = newTag.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty && !tags.contains(trimmed) {
            tags.append(trimmed)
            newTag = ""
        }
    }

    private func createPerson() {
        let person = Person(
            name: name,
            email: email.isEmpty ? nil : email,
            title: title.isEmpty ? nil : title,
            department: department.isEmpty ? nil : department,
            notes: notes.isEmpty ? nil : notes,
            avatarColor: avatarColor,
            tags: tags,
            meetingFrequency: meetingFrequency
        )

        dataStore.addPerson(person)
        dismiss()
    }
}

#Preview {
    NewPersonView()
        .environmentObject(DataStore.shared)
}
