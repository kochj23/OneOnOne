//
//  GoalsView.swift
//  OneOnOne
//
//  View for managing goals
//  Created by Jordan Koch on 2026-02-02.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

struct GoalsView: View {
    @EnvironmentObject var dataStore: DataStore
    @State private var selectedGoal: Goal?
    @State private var showNewGoal = false
    @State private var filterCategory: GoalCategory?
    @State private var filterStatus: GoalStatus?

    var filteredGoals: [Goal] {
        var goals = dataStore.goals

        if let category = filterCategory {
            goals = goals.filter { $0.category == category }
        }

        if let status = filterStatus {
            goals = goals.filter { $0.status == status }
        }

        return goals.sorted { g1, g2 in
            // Active goals first, then by progress
            if g1.status != g2.status {
                return g1.status.rawValue < g2.status.rawValue
            }
            return g1.progress > g2.progress
        }
    }

    var body: some View {
        HSplitView {
            // Goals list
            goalsList
                .frame(minWidth: 400, maxWidth: 500)

            // Goal detail
            if let goal = selectedGoal {
                GoalDetailView(goal: binding(for: goal))
            } else {
                emptyDetailView
            }
        }
        .sheet(isPresented: $showNewGoal) {
            NewGoalView()
        }
    }

    // MARK: - Goals List

    private var goalsList: some View {
        VStack(spacing: 0) {
            // Header
            listHeader
                .padding(20)

            // Filters
            filtersBar
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

            Divider()
                .background(ModernColors.glassBorder)

            // Stats
            statsRow
                .padding(20)

            // List
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(filteredGoals) { goal in
                        goalCard(goal)
                            .onTapGesture {
                                selectedGoal = goal
                            }
                    }

                    if filteredGoals.isEmpty {
                        emptyListState
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .background(Color.black.opacity(0.2))
    }

    private var listHeader: some View {
        HStack {
            Text("Goals")
                .modernHeader(size: .large)

            Spacer()

            Button {
                showNewGoal = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                    Text("New Goal")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(ModernColors.accentGreen)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
        }
    }

    private var filtersBar: some View {
        HStack(spacing: 12) {
            // Category filter
            Menu {
                Button("All Categories") {
                    filterCategory = nil
                }
                Divider()
                ForEach(GoalCategory.allCases, id: \.self) { category in
                    Button {
                        filterCategory = category
                    } label: {
                        Label(category.rawValue, systemImage: category.icon)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: filterCategory?.icon ?? "folder")
                    Text(filterCategory?.rawValue ?? "All Categories")
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))
                }
                .font(.system(size: 13))
                .foregroundColor(ModernColors.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.05))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)

            // Status filter
            Menu {
                Button("All Statuses") {
                    filterStatus = nil
                }
                Divider()
                ForEach(GoalStatus.allCases, id: \.self) { status in
                    Button {
                        filterStatus = status
                    } label: {
                        Label(status.rawValue, systemImage: status.icon)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: filterStatus?.icon ?? "circle")
                    Text(filterStatus?.rawValue ?? "All Statuses")
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))
                }
                .font(.system(size: 13))
                .foregroundColor(ModernColors.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.05))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }

    private var statsRow: some View {
        HStack(spacing: 16) {
            statCard(
                value: dataStore.goals.filter { $0.status == .inProgress }.count,
                label: "In Progress",
                color: ModernColors.accentBlue
            )

            statCard(
                value: dataStore.goals.filter { $0.status == .completed }.count,
                label: "Completed",
                color: ModernColors.accentGreen
            )

            statCard(
                value: dataStore.goals.filter { $0.isOverdue }.count,
                label: "Overdue",
                color: ModernColors.statusCritical
            )
        }
    }

    private func statCard(value: Int, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(ModernColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }

    private func goalCard(_ goal: Goal) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // Category icon
                Image(systemName: goal.category.icon)
                    .font(.system(size: 18))
                    .foregroundColor(Color(hex: goal.category.color))
                    .frame(width: 36, height: 36)
                    .background(Color(hex: goal.category.color).opacity(0.2))
                    .cornerRadius(10)

                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(ModernColors.textPrimary)
                        .lineLimit(1)

                    Text(goal.category.rawValue)
                        .font(.system(size: 12))
                        .foregroundColor(ModernColors.textTertiary)
                }

                Spacer()

                // Status badge
                HStack(spacing: 4) {
                    Image(systemName: goal.status.icon)
                    Text(goal.status.rawValue)
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color(hex: goal.status.color))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(hex: goal.status.color).opacity(0.2))
                .cornerRadius(8)
            }

            // Progress bar
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("\(Int(goal.progress * 100))% complete")
                        .font(.system(size: 12))
                        .foregroundColor(ModernColors.textSecondary)

                    Spacer()

                    if let targetDate = goal.targetDate {
                        Text("Due: \(targetDate.formatted(date: .abbreviated, time: .omitted))")
                            .font(.system(size: 12))
                            .foregroundColor(goal.isOverdue ? ModernColors.statusCritical : ModernColors.textTertiary)
                    }
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.1))

                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(hex: goal.category.color))
                            .frame(width: geometry.size.width * goal.progress)
                    }
                }
                .frame(height: 6)
            }

            // Milestones summary
            if !goal.milestones.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "flag")
                        .font(.system(size: 12))

                    Text("\(goal.completedMilestones)/\(goal.milestones.count) milestones")
                        .font(.system(size: 12))
                }
                .foregroundColor(ModernColors.textTertiary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(selectedGoal?.id == goal.id ? ModernColors.accentGreen.opacity(0.15) : Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(selectedGoal?.id == goal.id ? ModernColors.accentGreen.opacity(0.5) : Color.clear, lineWidth: 1)
                )
        )
    }

    private var emptyListState: some View {
        VStack(spacing: 16) {
            Image(systemName: "target")
                .font(.system(size: 40))
                .foregroundColor(ModernColors.textTertiary)

            Text("No goals yet")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(ModernColors.textSecondary)

            Text("Create a goal to track progress")
                .font(.system(size: 14))
                .foregroundColor(ModernColors.textTertiary)
        }
        .padding(.vertical, 40)
    }

    private var emptyDetailView: some View {
        VStack(spacing: 16) {
            Image(systemName: "target")
                .font(.system(size: 48))
                .foregroundColor(ModernColors.textTertiary)

            Text("Select a goal")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(ModernColors.textSecondary)

            Text("Choose a goal from the list to view details")
                .font(.system(size: 14))
                .foregroundColor(ModernColors.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func binding(for goal: Goal) -> Binding<Goal> {
        Binding(
            get: {
                dataStore.goals.first { $0.id == goal.id } ?? goal
            },
            set: { newValue in
                dataStore.updateGoal(newValue)
            }
        )
    }
}

// MARK: - Goal Detail View

struct GoalDetailView: View {
    @Binding var goal: Goal
    @EnvironmentObject var dataStore: DataStore
    @State private var showDeleteConfirmation = false
    @State private var newMilestoneTitle = ""
    @State private var showAIAnalysis = false
    @State private var aiAnalysis: String?
    @State private var isAnalyzing = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                header

                // Progress overview
                progressCard

                // Milestones
                milestonesCard

                // Related meetings
                relatedMeetingsCard

                // AI Analysis
                if let analysis = aiAnalysis {
                    aiAnalysisCard(analysis)
                }

                // Delete button
                deleteButton
            }
            .padding(32)
        }
        .alert("Delete Goal", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                dataStore.deleteGoal(id: goal.id)
            }
        } message: {
            Text("Are you sure you want to delete this goal? This cannot be undone.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: goal.category.icon)
                    .font(.system(size: 24))
                    .foregroundColor(Color(hex: goal.category.color))

                Text(goal.title)
                    .modernHeader(size: .large)

                Spacer()

                // AI Analysis button
                Button {
                    analyzeGoal()
                } label: {
                    HStack(spacing: 6) {
                        if isAnalyzing {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "sparkles")
                        }
                        Text("AI Analysis")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(ModernColors.pink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(ModernColors.pink.opacity(0.2))
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .disabled(isAnalyzing)
            }

            if let description = goal.description {
                Text(description)
                    .font(.system(size: 15))
                    .foregroundColor(ModernColors.textSecondary)
            }

            HStack(spacing: 16) {
                Label(goal.category.rawValue, systemImage: goal.category.icon)

                HStack(spacing: 4) {
                    Image(systemName: goal.status.icon)
                    Text(goal.status.rawValue)
                }
                .foregroundColor(Color(hex: goal.status.color))

                if let targetDate = goal.targetDate {
                    Label(targetDate.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                        .foregroundColor(goal.isOverdue ? ModernColors.statusCritical : ModernColors.textSecondary)
                }
            }
            .font(.system(size: 14))
            .foregroundColor(ModernColors.textSecondary)
        }
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Progress")
                    .modernHeader(size: .small)

                Spacer()

                Text("\(Int(goal.progress * 100))%")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: goal.category.color))
            }

            // Large progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.1))

                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: goal.category.color))
                        .frame(width: geometry.size.width * goal.progress)
                }
            }
            .frame(height: 12)

            // Status selector
            HStack(spacing: 8) {
                Text("Status:")
                    .font(.system(size: 14))
                    .foregroundColor(ModernColors.textTertiary)

                ForEach(GoalStatus.allCases, id: \.self) { status in
                    Button {
                        goal.status = status
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: status.icon)
                            Text(status.rawValue)
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(goal.status == status ? .white : Color(hex: status.color))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(goal.status == status ? Color(hex: status.color) : Color(hex: status.color).opacity(0.2))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .glassCard()
    }

    private var milestonesCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Milestones")
                    .modernHeader(size: .small)

                Spacer()

                Text("\(goal.completedMilestones)/\(goal.milestones.count)")
                    .font(.system(size: 14))
                    .foregroundColor(ModernColors.textTertiary)
            }

            // Add milestone
            HStack(spacing: 10) {
                TextField("Add milestone...", text: $newMilestoneTitle)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .foregroundColor(ModernColors.textPrimary)
                    .padding(10)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(10)

                Button {
                    addMilestone()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(ModernColors.accentGreen)
                }
                .buttonStyle(.plain)
                .disabled(newMilestoneTitle.isEmpty)
            }

            // Milestones list
            ForEach(goal.milestones.indices, id: \.self) { index in
                milestoneRow(index: index)
            }
        }
        .glassCard()
    }

    private func milestoneRow(index: Int) -> some View {
        let milestone = goal.milestones[index]
        return HStack(spacing: 12) {
            Button {
                goal.milestones[index].isCompleted.toggle()
                if goal.milestones[index].isCompleted {
                    goal.milestones[index].completedDate = Date()
                } else {
                    goal.milestones[index].completedDate = nil
                }
                goal.updateProgress()
            } label: {
                Image(systemName: milestone.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(milestone.isCompleted ? ModernColors.accentGreen : ModernColors.textTertiary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(milestone.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(milestone.isCompleted ? ModernColors.textTertiary : ModernColors.textPrimary)
                    .strikethrough(milestone.isCompleted)

                if let completedDate = milestone.completedDate {
                    Text("Completed \(completedDate.formatted(.relative(presentation: .named)))")
                        .font(.system(size: 12))
                        .foregroundColor(ModernColors.textTertiary)
                }
            }

            Spacer()

            // Delete milestone
            Button {
                goal.milestones.remove(at: index)
                goal.updateProgress()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12))
                    .foregroundColor(ModernColors.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    private var relatedMeetingsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Related Meetings")
                .modernHeader(size: .small)

            let meetings = goal.relatedMeetingIds.compactMap { id in
                dataStore.meetings.first { $0.id == id }
            }

            if meetings.isEmpty {
                Text("No meetings linked to this goal")
                    .font(.system(size: 14))
                    .foregroundColor(ModernColors.textTertiary)
            } else {
                ForEach(meetings) { meeting in
                    HStack(spacing: 10) {
                        Image(systemName: meeting.meetingType.icon)
                            .foregroundColor(ModernColors.accentBlue)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(meeting.title)
                                .font(.system(size: 14))
                                .foregroundColor(ModernColors.textPrimary)

                            Text(meeting.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 12))
                                .foregroundColor(ModernColors.textTertiary)
                        }

                        Spacer()
                    }
                }
            }
        }
        .glassCard()
    }

    private func aiAnalysisCard(_ analysis: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .foregroundColor(ModernColors.pink)
                Text("AI Analysis")
                    .modernHeader(size: .small)
            }

            Text(analysis)
                .font(.system(size: 14))
                .foregroundColor(ModernColors.textSecondary)
        }
        .glassCard()
    }

    private var deleteButton: some View {
        Button {
            showDeleteConfirmation = true
        } label: {
            HStack {
                Image(systemName: "trash")
                Text("Delete Goal")
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(ModernColors.statusCritical)
        }
        .buttonStyle(.plain)
    }

    private func addMilestone() {
        let milestone = Milestone(title: newMilestoneTitle)
        goal.milestones.append(milestone)
        goal.updateProgress()
        newMilestoneTitle = ""
    }

    private func analyzeGoal() {
        isAnalyzing = true
        Task {
            do {
                let meetings = goal.relatedMeetingIds.compactMap { id in
                    dataStore.meetings.first { $0.id == id }
                }
                let analysis = try await AIService.shared.analyzeGoalProgress(
                    goal: goal,
                    relatedMeetings: meetings
                )
                await MainActor.run {
                    aiAnalysis = analysis
                    isAnalyzing = false
                }
            } catch {
                await MainActor.run {
                    isAnalyzing = false
                }
                print("AI Analysis error: \(error)")
            }
        }
    }
}

#Preview {
    GoalsView()
        .environmentObject(DataStore.shared)
}
