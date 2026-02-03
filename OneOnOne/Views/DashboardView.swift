//
//  DashboardView.swift
//  OneOnOne
//
//  Dashboard with overview of meetings, tasks, and insights
//  Created by Jordan Koch on 2026-02-02.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var dataStore: DataStore
    @State private var selectedMeeting: Meeting?
    @State private var navigateToMeetings = false
    @State private var navigateToActionItems = false
    @State private var navigateToGoals = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                header

                // Stats cards
                statsRow

                // Main content grid
                HStack(alignment: .top, spacing: 24) {
                    // Left column
                    VStack(spacing: 24) {
                        upcomingMeetingsCard
                        recentMeetingsCard
                    }
                    .frame(maxWidth: .infinity)

                    // Right column
                    VStack(spacing: 24) {
                        actionItemsCard
                        goalsProgressCard
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(32)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Dashboard")
                    .modernHeader(size: .large)

                Text(Date().formatted(date: .complete, time: .omitted))
                    .font(.system(size: 16))
                    .foregroundColor(ModernColors.textSecondary)
            }

            Spacer()

            // Quick actions
            HStack(spacing: 12) {
                quickActionButton(
                    icon: "plus.circle.fill",
                    label: "New Meeting",
                    color: ModernColors.accentBlue
                ) {
                    NotificationCenter.default.post(name: .newMeeting, object: nil)
                }

                quickActionButton(
                    icon: "person.badge.plus",
                    label: "Add Person",
                    color: ModernColors.purple
                ) {
                    NotificationCenter.default.post(name: .newPerson, object: nil)
                }
            }
        }
    }

    private func quickActionButton(
        icon: String,
        label: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(label)
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(color)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 20) {
            statCard(
                title: "Meetings This Week",
                value: "\(dataStore.totalMeetingsThisWeek)",
                icon: "calendar",
                color: ModernColors.accentBlue
            )

            statCard(
                title: "Open Tasks",
                value: "\(dataStore.openActionItems().count)",
                icon: "checklist",
                color: ModernColors.orange
            )

            statCard(
                title: "Active Goals",
                value: "\(dataStore.activeGoals().count)",
                icon: "target",
                color: ModernColors.accentGreen
            )

            statCard(
                title: "People",
                value: "\(dataStore.people.count)",
                icon: "person.2",
                color: ModernColors.purple
            )
        }
    }

    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)

                Spacer()
            }

            Text(value)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(ModernColors.textPrimary)

            Text(title)
                .font(.system(size: 14))
                .foregroundColor(ModernColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    // MARK: - Upcoming Meetings

    private var upcomingMeetingsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .foregroundColor(ModernColors.accentBlue)
                Text("Upcoming Meetings")
                    .modernHeader(size: .medium)
                Spacer()
            }

            let upcoming = dataStore.upcomingMeetings(limit: 5)
            if upcoming.isEmpty {
                emptyState(
                    icon: "calendar",
                    message: "No upcoming meetings"
                )
            } else {
                ForEach(upcoming) { meeting in
                    meetingRow(meeting)
                }
            }
        }
        .glassCard()
    }

    // MARK: - Recent Meetings

    private var recentMeetingsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundColor(ModernColors.cyan)
                Text("Recent Meetings")
                    .modernHeader(size: .medium)
                Spacer()
            }

            let recent = dataStore.recentMeetings(limit: 5)
            if recent.isEmpty {
                emptyState(
                    icon: "calendar",
                    message: "No recent meetings"
                )
            } else {
                ForEach(recent) { meeting in
                    meetingRow(meeting)
                }
            }
        }
        .glassCard()
    }

    private func meetingRow(_ meeting: Meeting) -> some View {
        HStack(spacing: 12) {
            // Type icon
            Image(systemName: meeting.meetingType.icon)
                .font(.system(size: 16))
                .foregroundColor(ModernColors.accentBlue)
                .frame(width: 32, height: 32)
                .background(ModernColors.accentBlue.opacity(0.2))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 2) {
                Text(meeting.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ModernColors.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(meeting.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 12))
                        .foregroundColor(ModernColors.textTertiary)

                    if meeting.attendees.count > 0 {
                        Text("\(meeting.attendees.count) attendees")
                            .font(.system(size: 12))
                            .foregroundColor(ModernColors.textTertiary)
                    }
                }
            }

            Spacer()

            // Action items badge
            if meeting.openActionItemsCount > 0 {
                Text("\(meeting.openActionItemsCount)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(ModernColors.orange)
                    .cornerRadius(6)
            }

            // Chevron indicator
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(ModernColors.textTertiary)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color.white.opacity(0.01))
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onTapGesture {
            NotificationCenter.default.post(name: .selectMeeting, object: meeting)
        }
        .onHover { hovering in
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }

    // MARK: - Action Items

    private var actionItemsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "checklist")
                    .foregroundColor(ModernColors.orange)
                Text("Open Tasks")
                    .modernHeader(size: .medium)
                Spacer()

                if dataStore.overdueActionItems.count > 0 {
                    Text("\(dataStore.overdueActionItems.count) overdue")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ModernColors.statusCritical)
                }
            }

            let items = Array(dataStore.openActionItems().prefix(5))
            if items.isEmpty {
                emptyState(
                    icon: "checkmark.circle",
                    message: "All tasks completed!"
                )
            } else {
                ForEach(items) { item in
                    actionItemRow(item)
                }
            }
        }
        .glassCard()
    }

    private func actionItemRow(_ item: ActionItem) -> some View {
        HStack(spacing: 12) {
            // Priority indicator
            Circle()
                .fill(Color(hex: item.priority.color))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ModernColors.textPrimary)
                    .lineLimit(1)

                if let dueDate = item.dueDate {
                    Text("Due: \(dueDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.system(size: 12))
                        .foregroundColor(item.isOverdue ? ModernColors.statusCritical : ModernColors.textTertiary)
                }
            }

            Spacer()

            // Assignee
            if let assigneeId = item.assigneeId,
               let person = dataStore.person(for: assigneeId) {
                Text(person.initials)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .background(Color(hex: person.avatarColor))
                    .cornerRadius(12)
            }

            // Chevron indicator
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(ModernColors.textTertiary)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color.white.opacity(0.01))
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onTapGesture {
            NotificationCenter.default.post(name: .navigateToActionItems, object: nil)
        }
        .onHover { hovering in
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }

    // MARK: - Goals Progress

    private var goalsProgressCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "target")
                    .foregroundColor(ModernColors.accentGreen)
                Text("Goals Progress")
                    .modernHeader(size: .medium)
                Spacer()
            }

            let goals = Array(dataStore.activeGoals().prefix(4))
            if goals.isEmpty {
                emptyState(
                    icon: "target",
                    message: "No active goals"
                )
            } else {
                ForEach(goals) { goal in
                    goalRow(goal)
                }
            }
        }
        .glassCard()
    }

    private func goalRow(_ goal: Goal) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: goal.category.icon)
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: goal.category.color))

                Text(goal.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ModernColors.textPrimary)
                    .lineLimit(1)

                Spacer()

                Text("\(Int(goal.progress * 100))%")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(hex: goal.status.color))

                // Chevron indicator
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(ModernColors.textTertiary)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: goal.category.color))
                        .frame(width: geometry.size.width * goal.progress, height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color.white.opacity(0.01))
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onTapGesture {
            NotificationCenter.default.post(name: .navigateToGoals, object: goal)
        }
        .onHover { hovering in
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }

    // MARK: - Empty State

    private func emptyState(icon: String, message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(ModernColors.textTertiary)

            Text(message)
                .font(.system(size: 14))
                .foregroundColor(ModernColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    DashboardView()
        .environmentObject(DataStore.shared)
}
