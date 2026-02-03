//
//  FeedbackView.swift
//  OneOnOne
//
//  Feedback and praise tracking view
//  Created by Jordan Koch on 2026-02-02.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

struct FeedbackView: View {
    @EnvironmentObject var dataStore: DataStore
    @State private var selectedFeedback: Feedback?
    @State private var showNewFeedback = false
    @State private var filterType: FeedbackType?
    @State private var filterPerson: UUID?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
                .padding(24)

            Divider()
                .background(ModernColors.glassBorder)

            // Content
            HStack(spacing: 0) {
                // Feedback list
                feedbackList
                    .frame(maxWidth: .infinity)

                Divider()
                    .background(ModernColors.glassBorder)

                // Stats sidebar
                statsSidebar
                    .frame(width: 280)
            }
        }
        .sheet(isPresented: $showNewFeedback) {
            NewFeedbackView()
        }
        .sheet(item: $selectedFeedback) { feedback in
            FeedbackDetailView(feedback: feedback)
        }
    }

    private var filteredFeedback: [Feedback] {
        var result = dataStore.feedback

        if let type = filterType {
            result = result.filter { $0.type == type }
        }

        if let personId = filterPerson {
            result = result.filter { $0.personId == personId }
        }

        return result.sorted { $0.date > $1.date }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Feedback & Recognition")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(ModernColors.textPrimary)

                Text("Track praise, recognition, and constructive feedback")
                    .font(.system(size: 14))
                    .foregroundColor(ModernColors.textSecondary)
            }

            Spacer()

            // Filter by type
            Menu {
                Button("All Types") { filterType = nil }
                Divider()
                ForEach(FeedbackType.allCases, id: \.self) { type in
                    Button {
                        filterType = type
                    } label: {
                        Label(type.rawValue, systemImage: type.icon)
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                    Text(filterType?.rawValue ?? "All Types")
                }
                .foregroundColor(ModernColors.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.05))
                .cornerRadius(8)
            }

            // Filter by person
            Menu {
                Button("All People") { filterPerson = nil }
                Divider()
                ForEach(dataStore.people) { person in
                    Button(person.name) {
                        filterPerson = person.id
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "person")
                    Text(filterPerson.flatMap { dataStore.person(for: $0)?.name } ?? "All People")
                }
                .foregroundColor(ModernColors.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.05))
                .cornerRadius(8)
            }

            Button {
                showNewFeedback = true
            } label: {
                Label("Give Feedback", systemImage: "plus")
                    .primaryButton()
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Feedback List

    private var feedbackList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if filteredFeedback.isEmpty {
                    emptyState
                } else {
                    ForEach(filteredFeedback) { feedback in
                        FeedbackRow(feedback: feedback) {
                            selectedFeedback = feedback
                        }
                    }
                }
            }
            .padding(24)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "star.bubble")
                .font(.system(size: 48))
                .foregroundColor(ModernColors.textTertiary)

            Text("No feedback recorded")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(ModernColors.textSecondary)

            Text("Start tracking praise, recognition, and feedback for your team")
                .font(.system(size: 14))
                .foregroundColor(ModernColors.textTertiary)
                .multilineTextAlignment(.center)

            Button {
                showNewFeedback = true
            } label: {
                Label("Give First Feedback", systemImage: "plus")
                    .primaryButton()
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(60)
    }

    // MARK: - Stats Sidebar

    private var statsSidebar: some View {
        ScrollView {
            VStack(spacing: 20) {
                // This month summary
                VStack(alignment: .leading, spacing: 12) {
                    Text("This Month")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(ModernColors.textSecondary)

                    HStack(spacing: 16) {
                        statItem(
                            value: dataStore.totalFeedbackThisMonth,
                            label: "Total",
                            color: ModernColors.cyan
                        )
                        statItem(
                            value: monthlyFeedbackByType(.praise),
                            label: "Praise",
                            color: ModernColors.accentGreen
                        )
                        statItem(
                            value: monthlyFeedbackByType(.constructive),
                            label: "Constructive",
                            color: ModernColors.orange
                        )
                    }
                }
                .padding(16)
                .glassCard()

                // By type breakdown
                VStack(alignment: .leading, spacing: 12) {
                    Text("By Type")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(ModernColors.textSecondary)

                    ForEach(FeedbackType.allCases, id: \.self) { type in
                        let count = dataStore.feedback.filter { $0.type == type }.count
                        HStack {
                            Image(systemName: type.icon)
                                .foregroundColor(Color(hex: type.color))
                                .frame(width: 20)
                            Text(type.rawValue)
                                .font(.system(size: 13))
                                .foregroundColor(ModernColors.textSecondary)
                            Spacer()
                            Text("\(count)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(ModernColors.textPrimary)
                        }
                    }
                }
                .padding(16)
                .glassCard()

                // Top recipients
                VStack(alignment: .leading, spacing: 12) {
                    Text("Top Recipients")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(ModernColors.textSecondary)

                    let topPeople = topFeedbackRecipients(limit: 5)
                    if topPeople.isEmpty {
                        Text("No data yet")
                            .font(.system(size: 13))
                            .foregroundColor(ModernColors.textTertiary)
                    } else {
                        ForEach(topPeople, id: \.person.id) { item in
                            HStack {
                                Text(item.person.initials)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 28, height: 28)
                                    .background(Circle().fill(ModernColors.purple))

                                Text(item.person.name)
                                    .font(.system(size: 13))
                                    .foregroundColor(ModernColors.textSecondary)
                                    .lineLimit(1)

                                Spacer()

                                Text("\(item.count)")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(ModernColors.textPrimary)
                            }
                        }
                    }
                }
                .padding(16)
                .glassCard()
            }
            .padding(20)
        }
        .background(Color.black.opacity(0.2))
    }

    private func statItem(value: Int, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(ModernColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private func monthlyFeedbackByType(_ type: FeedbackType) -> Int {
        let monthAgo = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        return dataStore.feedback.filter { $0.type == type && $0.date >= monthAgo }.count
    }

    private func topFeedbackRecipients(limit: Int) -> [(person: Person, count: Int)] {
        var counts: [UUID: Int] = [:]
        for feedback in dataStore.feedback {
            counts[feedback.personId, default: 0] += 1
        }

        return counts.sorted { $0.value > $1.value }
            .prefix(limit)
            .compactMap { personId, count in
                guard let person = dataStore.person(for: personId) else { return nil }
                return (person: person, count: count)
            }
    }
}

// MARK: - Feedback Row

struct FeedbackRow: View {
    let feedback: Feedback
    let action: () -> Void
    @EnvironmentObject var dataStore: DataStore

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Type icon
                Image(systemName: feedback.type.icon)
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: feedback.type.color))
                    .frame(width: 44, height: 44)
                    .background(Color(hex: feedback.type.color).opacity(0.15))
                    .cornerRadius(12)

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(feedback.type.rawValue)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(hex: feedback.type.color))

                        Text(feedback.direction.rawValue)
                            .font(.system(size: 10))
                            .foregroundColor(ModernColors.textTertiary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(4)

                        Spacer()

                        Text(feedback.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.system(size: 12))
                            .foregroundColor(ModernColors.textTertiary)
                    }

                    Text(feedback.content)
                        .font(.system(size: 14))
                        .foregroundColor(ModernColors.textPrimary)
                        .lineLimit(2)

                    if let person = dataStore.person(for: feedback.personId) {
                        HStack(spacing: 6) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 10))
                            Text(person.name)
                                .font(.system(size: 12))
                        }
                        .foregroundColor(ModernColors.textTertiary)
                    }
                }

                Image(systemName: "chevron.right")
                    .foregroundColor(ModernColors.textTertiary)
            }
            .padding(16)
            .glassCard()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Feedback Detail View

struct FeedbackDetailView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var dataStore: DataStore
    let feedback: Feedback
    @State private var showDeleteAlert = false

    var body: some View {
        ZStack {
            ModernColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    HStack(spacing: 12) {
                        Image(systemName: feedback.type.icon)
                            .font(.system(size: 24))
                            .foregroundColor(Color(hex: feedback.type.color))

                        Text(feedback.type.rawValue)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(ModernColors.textPrimary)
                    }

                    Spacer()

                    Button {
                        showDeleteAlert = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(ModernColors.red)
                    }
                    .buttonStyle(.plain)

                    Button("Done") {
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
                        // Person
                        if let person = dataStore.person(for: feedback.personId) {
                            HStack(spacing: 12) {
                                Text(person.initials)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 44)
                                    .background(Circle().fill(ModernColors.purple))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(person.name)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(ModernColors.textPrimary)

                                    if let title = person.title {
                                        Text(title)
                                            .font(.system(size: 13))
                                            .foregroundColor(ModernColors.textSecondary)
                                    }
                                }

                                Spacer()

                                Text(feedback.date.formatted(date: .long, time: .omitted))
                                    .font(.system(size: 13))
                                    .foregroundColor(ModernColors.textTertiary)
                            }
                            .padding(16)
                            .glassCard()
                        }

                        // Content
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Feedback")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(ModernColors.textSecondary)

                            Text(feedback.content)
                                .font(.system(size: 15))
                                .foregroundColor(ModernColors.textPrimary)
                                .lineSpacing(4)
                        }
                        .padding(16)
                        .glassCard()

                        // Context
                        if let context = feedback.context {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Context")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(ModernColors.textSecondary)

                                Text(context)
                                    .font(.system(size: 14))
                                    .foregroundColor(ModernColors.textSecondary)
                                    .lineSpacing(4)
                            }
                            .padding(16)
                            .glassCard()
                        }

                        // Metadata
                        VStack(spacing: 12) {
                            if let meetingId = feedback.meetingId,
                               let meeting = dataStore.meetings.first(where: { $0.id == meetingId }) {
                                HStack {
                                    Label("Meeting", systemImage: "calendar")
                                        .font(.system(size: 13))
                                        .foregroundColor(ModernColors.textTertiary)
                                    Spacer()
                                    Text(meeting.title)
                                        .font(.system(size: 13))
                                        .foregroundColor(ModernColors.textSecondary)
                                }
                            }

                            HStack {
                                Label("Direction", systemImage: "arrow.left.arrow.right")
                                    .font(.system(size: 13))
                                    .foregroundColor(ModernColors.textTertiary)
                                Spacer()
                                Text(feedback.direction.rawValue)
                                    .font(.system(size: 13))
                                    .foregroundColor(ModernColors.textSecondary)
                            }

                            HStack {
                                Label("Created", systemImage: "clock")
                                    .font(.system(size: 13))
                                    .foregroundColor(ModernColors.textTertiary)
                                Spacer()
                                Text(feedback.createdAt.formatted())
                                    .font(.system(size: 13))
                                    .foregroundColor(ModernColors.textSecondary)
                            }
                        }
                        .padding(16)
                        .glassCard()
                    }
                    .padding(24)
                }
            }
        }
        .frame(width: 500, height: 600)
        .alert("Delete Feedback?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                dataStore.deleteFeedback(id: feedback.id)
                dismiss()
            }
        } message: {
            Text("This action cannot be undone.")
        }
    }
}

// MARK: - New Feedback View

struct NewFeedbackView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var dataStore: DataStore

    @State private var personId: UUID?
    @State private var type: FeedbackType = .praise
    @State private var direction: FeedbackDirection = .given
    @State private var content = ""
    @State private var context = ""
    @State private var meetingId: UUID?

    var body: some View {
        ZStack {
            ModernColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Give Feedback")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(ModernColors.textPrimary)

                    Spacer()

                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(ModernColors.textSecondary)
                }
                .padding(24)

                Divider()
                    .background(ModernColors.glassBorder)

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Person
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Person")
                                .formLabel()
                            Picker("", selection: $personId) {
                                Text("Select a person").tag(nil as UUID?)
                                ForEach(dataStore.people) { person in
                                    Text(person.name).tag(person.id as UUID?)
                                }
                            }
                            .pickerStyle(.menu)
                        }

                        // Direction
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Direction")
                                .formLabel()
                            Picker("", selection: $direction) {
                                ForEach(FeedbackDirection.allCases, id: \.self) { dir in
                                    Text(dir.rawValue).tag(dir)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        // Type
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Feedback Type")
                                .formLabel()

                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 12) {
                                ForEach(FeedbackType.allCases, id: \.self) { feedbackType in
                                    Button {
                                        type = feedbackType
                                    } label: {
                                        VStack(spacing: 8) {
                                            Image(systemName: feedbackType.icon)
                                                .font(.system(size: 20))
                                            Text(feedbackType.rawValue)
                                                .font(.system(size: 12))
                                        }
                                        .foregroundColor(type == feedbackType ? Color(hex: feedbackType.color) : ModernColors.textTertiary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(type == feedbackType ? Color(hex: feedbackType.color).opacity(0.15) : Color.white.opacity(0.05))
                                        .cornerRadius(10)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(type == feedbackType ? Color(hex: feedbackType.color) : Color.clear, lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        // Content
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Feedback")
                                .formLabel()
                            TextEditor(text: $content)
                                .font(.system(size: 14))
                                .frame(height: 120)
                                .scrollContentBackground(.hidden)
                                .padding(12)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(12)
                        }

                        // Context
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Context (optional)")
                                .formLabel()
                            TextField("When/where did this happen?", text: $context)
                                .formTextField()
                        }

                        // Meeting link
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Related Meeting (optional)")
                                .formLabel()
                            Picker("", selection: $meetingId) {
                                Text("None").tag(nil as UUID?)
                                ForEach(dataStore.recentMeetings(limit: 10)) { meeting in
                                    Text(meeting.title).tag(meeting.id as UUID?)
                                }
                            }
                            .pickerStyle(.menu)
                        }

                        // Save Button
                        Button {
                            saveFeedback()
                        } label: {
                            Text("Save Feedback")
                                .frame(maxWidth: .infinity)
                                .primaryButton()
                        }
                        .buttonStyle(.plain)
                        .disabled(personId == nil || content.isEmpty)
                    }
                    .padding(24)
                }
            }
        }
        .frame(width: 500, height: 700)
    }

    private func saveFeedback() {
        guard let personId = personId else { return }

        let feedback = Feedback(
            personId: personId,
            type: type,
            direction: direction,
            content: content,
            context: context.isEmpty ? nil : context,
            meetingId: meetingId
        )

        dataStore.addFeedback(feedback)
        dismiss()
    }
}

#Preview {
    FeedbackView()
        .environmentObject(DataStore.shared)
}
