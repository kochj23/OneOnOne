//
//  NewGoalView.swift
//  OneOnOne
//
//  View for creating a new goal
//  Created by Jordan Koch on 2026-02-02.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

struct NewGoalView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var category: GoalCategory = .development
    @State private var assignedPerson: UUID?
    @State private var targetDate: Date = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    @State private var hasTargetDate = false
    @State private var milestones: [String] = []
    @State private var newMilestone = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Title
                    formSection(title: "Goal Title *") {
                        TextField("What do you want to achieve?", text: $title)
                            .textFieldStyle(.plain)
                            .font(.system(size: 16))
                            .foregroundColor(ModernColors.textPrimary)
                            .padding(12)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(10)
                    }

                    // Description
                    formSection(title: "Description") {
                        TextEditor(text: $description)
                            .font(.system(size: 14))
                            .foregroundColor(ModernColors.textPrimary)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 80)
                            .padding(12)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(10)
                    }

                    // Category
                    formSection(title: "Category") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110))], spacing: 10) {
                            ForEach(GoalCategory.allCases, id: \.self) { cat in
                                Button {
                                    category = cat
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: cat.icon)
                                        Text(cat.rawValue)
                                    }
                                    .font(.system(size: 13, weight: category == cat ? .semibold : .medium))
                                    .foregroundColor(category == cat ? .white : Color(hex: cat.color))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(category == cat ? Color(hex: cat.color) : Color(hex: cat.color).opacity(0.2))
                                    .cornerRadius(10)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Assigned Person
                    formSection(title: "Assign to Person (Optional)") {
                        HStack(spacing: 10) {
                            Button {
                                assignedPerson = nil
                            } label: {
                                Text("None")
                                    .font(.system(size: 13, weight: assignedPerson == nil ? .semibold : .medium))
                                    .foregroundColor(assignedPerson == nil ? .white : ModernColors.textSecondary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(assignedPerson == nil ? ModernColors.purple : Color.white.opacity(0.05))
                                    .cornerRadius(10)
                            }
                            .buttonStyle(.plain)

                            ForEach(dataStore.people) { person in
                                Button {
                                    assignedPerson = person.id
                                } label: {
                                    HStack(spacing: 6) {
                                        Text(person.initials)
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.white)
                                            .frame(width: 24, height: 24)
                                            .background(Color(hex: person.avatarColor))
                                            .cornerRadius(12)

                                        Text(person.name.components(separatedBy: " ").first ?? "")
                                            .font(.system(size: 13))
                                    }
                                    .foregroundColor(assignedPerson == person.id ? .white : ModernColors.textSecondary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(assignedPerson == person.id ? ModernColors.purple : Color.white.opacity(0.05))
                                    .cornerRadius(10)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Target Date
                    formSection(title: "Target Date") {
                        HStack {
                            Toggle("Set target date", isOn: $hasTargetDate)
                                #if os(macOS)
                                .toggleStyle(.checkbox)
                                #endif
                                .foregroundColor(ModernColors.textSecondary)

                            if hasTargetDate {
                                DatePicker("", selection: $targetDate, displayedComponents: .date)
                                    .datePickerStyle(.compact)
                                    .labelsHidden()
                            }

                            Spacer()
                        }
                    }

                    // Milestones
                    formSection(title: "Milestones") {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 10) {
                                TextField("Add milestone...", text: $newMilestone)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 14))
                                    .foregroundColor(ModernColors.textPrimary)
                                    .padding(10)
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(8)

                                Button {
                                    addMilestone()
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(ModernColors.accentGreen)
                                }
                                .buttonStyle(.plain)
                                .disabled(newMilestone.isEmpty)
                            }

                            ForEach(milestones, id: \.self) { milestone in
                                HStack(spacing: 10) {
                                    Image(systemName: "flag")
                                        .foregroundColor(ModernColors.textTertiary)

                                    Text(milestone)
                                        .font(.system(size: 14))
                                        .foregroundColor(ModernColors.textPrimary)

                                    Spacer()

                                    Button {
                                        milestones.removeAll { $0 == milestone }
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 12))
                                            .foregroundColor(ModernColors.textTertiary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(10)
                                .background(Color.white.opacity(0.03))
                                .cornerRadius(8)
                            }
                        }
                    }
                }
                .padding(32)
            }
            .background(GlassmorphicBackground())
            .navigationTitle("New Goal")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createGoal()
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

    private func addMilestone() {
        let trimmed = newMilestone.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            milestones.append(trimmed)
            newMilestone = ""
        }
    }

    private func createGoal() {
        let goal = Goal(
            title: title,
            description: description.isEmpty ? nil : description,
            personId: assignedPerson,
            category: category,
            status: .notStarted,
            targetDate: hasTargetDate ? targetDate : nil,
            milestones: milestones.map { Milestone(title: $0) }
        )

        dataStore.addGoal(goal)
        dismiss()
    }
}

#Preview {
    NewGoalView()
        .environmentObject(DataStore.shared)
}
