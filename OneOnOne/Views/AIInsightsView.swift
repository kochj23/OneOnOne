//
//  AIInsightsView.swift
//  OneOnOne
//
//  AI-powered insights and recommendations
//  Created by Jordan Koch on 2026-02-02.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

struct AIInsightsView: View {
    @EnvironmentObject var dataStore: DataStore
    @State private var weeklyRecap: String?
    @State private var conversationTopics: [(person: Person, topics: [String])] = []
    @State private var isLoading = false
    @State private var selectedInsightType: InsightType = .weeklyRecap

    enum InsightType: String, CaseIterable {
        case weeklyRecap = "Weekly Recap"
        case conversationStarters = "Conversation Starters"
        case actionSummary = "Action Summary"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
                .padding(24)

            // Insight type tabs
            insightTabs
                .padding(.horizontal, 24)
                .padding(.bottom, 16)

            Divider()
                .background(ModernColors.glassBorder)

            // Content
            ScrollView {
                VStack(spacing: 24) {
                    switch selectedInsightType {
                    case .weeklyRecap:
                        weeklyRecapContent
                    case .conversationStarters:
                        conversationStartersContent
                    case .actionSummary:
                        actionSummaryContent
                    }
                }
                .padding(24)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 24))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [ModernColors.pink, ModernColors.purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Text("AI Insights")
                        .modernHeader(size: .large)
                }

                Text("Powered by local AI models")
                    .font(.system(size: 14))
                    .foregroundColor(ModernColors.textTertiary)
            }

            Spacer()

            // Refresh button
            Button {
                refreshInsights()
            } label: {
                HStack(spacing: 6) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                    Text("Generate")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(ModernColors.pink)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
            .disabled(isLoading)
        }
    }

    // MARK: - Insight Tabs

    private var insightTabs: some View {
        HStack(spacing: 12) {
            ForEach(InsightType.allCases, id: \.self) { type in
                Button {
                    withAnimation {
                        selectedInsightType = type
                    }
                } label: {
                    Text(type.rawValue)
                        .font(.system(size: 14, weight: selectedInsightType == type ? .semibold : .medium))
                        .foregroundColor(selectedInsightType == type ? ModernColors.pink : ModernColors.textSecondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            selectedInsightType == type ? ModernColors.pink.opacity(0.2) : Color.white.opacity(0.05)
                        )
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
    }

    // MARK: - Weekly Recap Content

    private var weeklyRecapContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Stats summary
            weeklyStatsCard

            // AI recap
            if let recap = weeklyRecap {
                aiRecapCard(recap)
            } else {
                generatePromptCard(
                    icon: "doc.text",
                    title: "Generate Weekly Recap",
                    description: "Get an AI-generated summary of your meetings, action items, and key discussions from the past week."
                )
            }

            // Meeting timeline
            weeklyTimelineCard
        }
    }

    private var weeklyStatsCard: some View {
        HStack(spacing: 20) {
            statItem(
                value: "\(dataStore.totalMeetingsThisWeek)",
                label: "Meetings",
                icon: "calendar",
                color: ModernColors.accentBlue
            )

            statItem(
                value: "\(dataStore.allActionItems().filter { $0.createdAt > Calendar.current.date(byAdding: .day, value: -7, to: Date())! }.count)",
                label: "New Tasks",
                icon: "checklist",
                color: ModernColors.orange
            )

            statItem(
                value: "\(dataStore.allActionItems().filter { $0.isCompleted && $0.completedDate ?? Date.distantPast > Calendar.current.date(byAdding: .day, value: -7, to: Date())! }.count)",
                label: "Completed",
                icon: "checkmark.circle",
                color: ModernColors.accentGreen
            )

            statItem(
                value: "\(Set(dataStore.recentMeetings(limit: 100).filter { $0.date > Calendar.current.date(byAdding: .day, value: -7, to: Date())! }.flatMap { $0.attendees }).count)",
                label: "People Met",
                icon: "person.2",
                color: ModernColors.purple
            )
        }
        .glassCard()
    }

    private func statItem(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(ModernColors.textPrimary)

            Text(label)
                .font(.system(size: 12))
                .foregroundColor(ModernColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private func aiRecapCard(_ recap: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundColor(ModernColors.pink)
                Text("AI Weekly Recap")
                    .modernHeader(size: .small)
            }

            Text(recap)
                .font(.system(size: 14))
                .lineSpacing(6)
                .foregroundColor(ModernColors.textSecondary)
        }
        .glassCard()
    }

    private var weeklyTimelineCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("This Week's Meetings")
                .modernHeader(size: .small)

            let weekMeetings = dataStore.meetings.filter {
                $0.date > Calendar.current.date(byAdding: .day, value: -7, to: Date())! &&
                $0.date <= Date()
            }.sorted { $0.date < $1.date }

            if weekMeetings.isEmpty {
                Text("No meetings this week")
                    .font(.system(size: 14))
                    .foregroundColor(ModernColors.textTertiary)
            } else {
                ForEach(weekMeetings) { meeting in
                    HStack(spacing: 12) {
                        // Day badge
                        VStack(spacing: 2) {
                            Text(meeting.date.formatted(.dateTime.weekday(.abbreviated)))
                                .font(.system(size: 10, weight: .medium))
                            Text(meeting.date.formatted(.dateTime.day()))
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundColor(ModernColors.accentBlue)
                        .frame(width: 40)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(meeting.title)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(ModernColors.textPrimary)

                            Text(meeting.date.formatted(date: .omitted, time: .shortened))
                                .font(.system(size: 12))
                                .foregroundColor(ModernColors.textTertiary)
                        }

                        Spacer()

                        if meeting.openActionItemsCount > 0 {
                            Text("\(meeting.openActionItemsCount) tasks")
                                .font(.system(size: 12))
                                .foregroundColor(ModernColors.orange)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .glassCard()
    }

    // MARK: - Conversation Starters Content

    private var conversationStartersContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            if conversationTopics.isEmpty {
                generatePromptCard(
                    icon: "bubble.left.and.bubble.right",
                    title: "Generate Conversation Topics",
                    description: "Get AI-suggested topics for your upcoming 1:1 meetings based on past conversations and action items."
                )
            } else {
                ForEach(conversationTopics, id: \.person.id) { item in
                    conversationTopicsCard(person: item.person, topics: item.topics)
                }
            }

            // People due for a meeting
            peopleDueCard
        }
    }

    private func conversationTopicsCard(person: Person, topics: [String]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Text(person.initials)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Color(hex: person.avatarColor))
                    .cornerRadius(20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(person.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(ModernColors.textPrimary)

                    if let lastMeeting = person.lastMeetingDate {
                        Text("Last met: \(lastMeeting.formatted(.relative(presentation: .named)))")
                            .font(.system(size: 12))
                            .foregroundColor(ModernColors.textTertiary)
                    }
                }

                Spacer()

                Image(systemName: "sparkles")
                    .foregroundColor(ModernColors.pink)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(topics, id: \.self) { topic in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10))
                            .foregroundColor(ModernColors.pink)
                            .padding(.top, 4)

                        Text(topic)
                            .font(.system(size: 14))
                            .foregroundColor(ModernColors.textSecondary)
                    }
                }
            }
        }
        .glassCard()
    }

    private var peopleDueCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Due for a Meeting")
                .modernHeader(size: .small)

            let peopleDue = dataStore.people.filter { person in
                guard let lastMeeting = person.lastMeetingDate,
                      let days = person.meetingFrequency.calendarDays else {
                    return person.lastMeetingDate == nil
                }
                let nextDue = Calendar.current.date(byAdding: .day, value: days, to: lastMeeting)!
                return nextDue < Date()
            }

            if peopleDue.isEmpty {
                Text("Everyone is up to date!")
                    .font(.system(size: 14))
                    .foregroundColor(ModernColors.textTertiary)
            } else {
                ForEach(peopleDue) { person in
                    HStack(spacing: 12) {
                        Text(person.initials)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(Color(hex: person.avatarColor))
                            .cornerRadius(16)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(person.name)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(ModernColors.textPrimary)

                            Text(person.meetingFrequency.rawValue)
                                .font(.system(size: 12))
                                .foregroundColor(ModernColors.textTertiary)
                        }

                        Spacer()

                        if let lastMeeting = person.lastMeetingDate {
                            Text(lastMeeting.formatted(.relative(presentation: .named)))
                                .font(.system(size: 12))
                                .foregroundColor(ModernColors.statusCritical)
                        } else {
                            Text("Never met")
                                .font(.system(size: 12))
                                .foregroundColor(ModernColors.orange)
                        }
                    }
                }
            }
        }
        .glassCard()
    }

    // MARK: - Action Summary Content

    private var actionSummaryContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Priority breakdown
            priorityBreakdownCard

            // Overdue items
            overdueItemsCard

            // By assignee
            byAssigneeCard
        }
    }

    private var priorityBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Tasks by Priority")
                .modernHeader(size: .small)

            let openItems = dataStore.openActionItems()

            ForEach(Priority.allCases, id: \.self) { priority in
                let count = openItems.filter { $0.priority == priority }.count
                let percentage = openItems.isEmpty ? 0 : Double(count) / Double(openItems.count)

                HStack(spacing: 12) {
                    HStack(spacing: 6) {
                        Image(systemName: priority.icon)
                        Text(priority.rawValue)
                    }
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: priority.color))
                    .frame(width: 100, alignment: .leading)

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.1))

                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(hex: priority.color))
                                .frame(width: geometry.size.width * percentage)
                        }
                    }
                    .frame(height: 8)

                    Text("\(count)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(ModernColors.textSecondary)
                        .frame(width: 30, alignment: .trailing)
                }
            }
        }
        .glassCard()
    }

    private var overdueItemsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Overdue Items")
                    .modernHeader(size: .small)

                Spacer()

                if !dataStore.overdueActionItems.isEmpty {
                    Text("\(dataStore.overdueActionItems.count)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(ModernColors.statusCritical)
                        .cornerRadius(8)
                }
            }

            if dataStore.overdueActionItems.isEmpty {
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(ModernColors.accentGreen)
                    Text("No overdue items!")
                        .font(.system(size: 14))
                        .foregroundColor(ModernColors.textSecondary)
                }
            } else {
                ForEach(dataStore.overdueActionItems.prefix(5)) { item in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(Color(hex: item.priority.color))
                            .frame(width: 8, height: 8)

                        Text(item.title)
                            .font(.system(size: 14))
                            .foregroundColor(ModernColors.textPrimary)
                            .lineLimit(1)

                        Spacer()

                        if let dueDate = item.dueDate {
                            Text(dueDate.formatted(.relative(presentation: .named)))
                                .font(.system(size: 12))
                                .foregroundColor(ModernColors.statusCritical)
                        }
                    }
                }
            }
        }
        .glassCard()
    }

    private var byAssigneeCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Tasks by Assignee")
                .modernHeader(size: .small)

            let openItems = dataStore.openActionItems()
            let byAssignee = Dictionary(grouping: openItems) { $0.assigneeId }

            ForEach(dataStore.people) { person in
                let count = byAssignee[person.id]?.count ?? 0
                if count > 0 {
                    HStack(spacing: 12) {
                        Text(person.initials)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 28, height: 28)
                            .background(Color(hex: person.avatarColor))
                            .cornerRadius(14)

                        Text(person.name)
                            .font(.system(size: 14))
                            .foregroundColor(ModernColors.textPrimary)

                        Spacer()

                        Text("\(count) tasks")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(ModernColors.textSecondary)
                    }
                }
            }

            // Unassigned
            let unassigned = byAssignee[nil]?.count ?? 0
            if unassigned > 0 {
                HStack(spacing: 12) {
                    Image(systemName: "person.fill.questionmark")
                        .font(.system(size: 14))
                        .foregroundColor(ModernColors.textTertiary)
                        .frame(width: 28, height: 28)

                    Text("Unassigned")
                        .font(.system(size: 14))
                        .foregroundColor(ModernColors.textTertiary)

                    Spacer()

                    Text("\(unassigned) tasks")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(ModernColors.textTertiary)
                }
            }
        }
        .glassCard()
    }

    // MARK: - Generate Prompt Card

    private func generatePromptCard(icon: String, title: String, description: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(ModernColors.pink.opacity(0.6))

            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(ModernColors.textPrimary)

            Text(description)
                .font(.system(size: 14))
                .foregroundColor(ModernColors.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                refreshInsights()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                    Text("Generate")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(ModernColors.pink)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .glassCard()
    }

    // MARK: - Actions

    private func refreshInsights() {
        isLoading = true

        Task {
            switch selectedInsightType {
            case .weeklyRecap:
                await generateWeeklyRecap()
            case .conversationStarters:
                await generateConversationTopics()
            case .actionSummary:
                // Action summary is computed, no AI needed
                break
            }

            await MainActor.run {
                isLoading = false
            }
        }
    }

    private func generateWeeklyRecap() async {
        do {
            let weekMeetings = dataStore.meetings.filter {
                $0.date > Calendar.current.date(byAdding: .day, value: -7, to: Date())!
            }
            let openItems = dataStore.openActionItems()

            let recap = try await AIService.shared.generateWeeklyRecap(
                meetings: weekMeetings,
                openActionItems: Array(openItems.prefix(20))
            )

            await MainActor.run {
                weeklyRecap = recap
            }
        } catch {
            print("Weekly recap error: \(error)")
        }
    }

    private func generateConversationTopics() async {
        var topics: [(person: Person, topics: [String])] = []

        for person in dataStore.people.prefix(5) {
            do {
                let meetings = dataStore.meetings(for: person.id)
                let suggestions = try await AIService.shared.suggestConversationTopics(
                    for: person,
                    recentMeetings: Array(meetings.prefix(5))
                )
                topics.append((person: person, topics: suggestions))
            } catch {
                print("Conversation topics error for \(person.name): \(error)")
            }
        }

        await MainActor.run {
            conversationTopics = topics
        }
    }
}

#Preview {
    AIInsightsView()
        .environmentObject(DataStore.shared)
}
