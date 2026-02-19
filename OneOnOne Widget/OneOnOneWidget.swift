//
//  OneOnOneWidget.swift
//  OneOnOne Widget
//
//  WidgetKit widgets for OneOnOne app showing upcoming meetings,
//  action items, streaks, notes, mood, and lock screen info
//  Created by Jordan Koch on 2026-02-04.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Configuration Intent

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "OneOnOne Widget" }
    static var description: IntentDescription { "Shows your upcoming 1:1 meetings and action items." }

    @Parameter(title: "Show Action Items", default: true)
    var showActionItems: Bool

    @Parameter(title: "Show Overdue People", default: true)
    var showOverduePeople: Bool
}

// ============================================================================
// MARK: - Shared Provider Helper
// ============================================================================

private func loadEntry(for configuration: ConfigurationAppIntent) -> OneOnOneEntry {
    let data = SharedDataManager.shared.readWidgetData()
    return OneOnOneEntry(
        date: Date(),
        upcomingMeetings: data.upcomingMeetings,
        overdueActionItemsCount: data.overdueActionItemsCount,
        peopleToMeetSoon: data.peopleToMeetSoon,
        configuration: configuration,
        actionItems: data.actionItems,
        todayMeetings: data.todayMeetings,
        streakPeople: data.streakPeople,
        recentNotes: data.recentNotes,
        moodHistory: data.moodHistory
    )
}

// ============================================================================
// MARK: - Widget Colors
// ============================================================================

struct WidgetColors {
    static let gradientStart = Color(red: 0.08, green: 0.12, blue: 0.22)
    static let gradientMid = Color(red: 0.10, green: 0.15, blue: 0.28)
    static let gradientEnd = Color(red: 0.12, green: 0.18, blue: 0.32)

    static let cyan = Color(red: 0.3, green: 0.85, blue: 0.95)
    static let purple = Color(red: 0.6, green: 0.4, blue: 0.95)
    static let pink = Color(red: 1.0, green: 0.35, blue: 0.65)
    static let orange = Color(red: 1.0, green: 0.6, blue: 0.2)
    static let green = Color(red: 0.3, green: 0.9, blue: 0.5)
    static let red = Color(red: 1.0, green: 0.3, blue: 0.3)

    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.7)
    static let textTertiary = Color.white.opacity(0.5)
    static let glassBackground = Color.white.opacity(0.08)
    static let glassBorder = Color.white.opacity(0.15)

    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [gradientStart, gradientMid, gradientEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func colorFromHex(_ hex: String) -> Color {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        return Color(
            red: Double((rgb & 0xFF0000) >> 16) / 255.0,
            green: Double((rgb & 0x00FF00) >> 8) / 255.0,
            blue: Double(rgb & 0x0000FF) / 255.0
        )
    }
}

// ============================================================================
// MARK: - Shared Supporting Views
// ============================================================================

struct PersonAvatar: View {
    let initials: String
    let color: String
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(WidgetColors.colorFromHex(color))
            Text(initials)
                .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .frame(width: size, height: size)
    }
}

struct StatBadge: View {
    let icon: String
    let count: Int
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text("\(count)")
                .font(.system(size: 11, weight: .bold))
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.2))
        .clipShape(Capsule())
    }
}

// ============================================================================
// MARK: - 1. MAIN WIDGET (OneOnOneWidget) - Existing
// ============================================================================

struct OneOnOneWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> OneOnOneEntry { .placeholder }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> OneOnOneEntry {
        loadEntry(for: configuration)
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<OneOnOneEntry> {
        let entry = loadEntry(for: configuration)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }
}

// Small
struct SmallWidgetView: View {
    let entry: OneOnOneEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(WidgetColors.cyan)
                Text("1:1s")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(WidgetColors.textPrimary)
                Spacer()
            }

            Spacer()

            if let nextMeeting = entry.upcomingMeetings.first {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Next")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(WidgetColors.textTertiary)
                    Text(nextMeeting.title)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(WidgetColors.textPrimary)
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        PersonAvatar(initials: nextMeeting.personInitials, color: nextMeeting.personColor, size: 16)
                        Text(nextMeeting.timeString)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(WidgetColors.textSecondary)
                    }
                }
            } else {
                Text("No upcoming meetings")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(WidgetColors.textSecondary)
            }

            Spacer()

            HStack(spacing: 12) {
                if entry.overdueActionItemsCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(WidgetColors.orange)
                        Text("\(entry.overdueActionItemsCount)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(WidgetColors.orange)
                    }
                }
                if !entry.peopleToMeetSoon.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "person.crop.circle.badge.clock")
                            .font(.system(size: 10))
                            .foregroundColor(WidgetColors.pink)
                        Text("\(entry.peopleToMeetSoon.count)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(WidgetColors.pink)
                    }
                }
            }
        }
        .padding(12)
    }
}

// Medium
struct MediumWidgetView: View {
    let entry: OneOnOneEntry

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "calendar")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(WidgetColors.cyan)
                    Text("Upcoming")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(WidgetColors.textPrimary)
                }
                if entry.upcomingMeetings.isEmpty {
                    Spacer()
                    Text("No meetings scheduled")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(WidgetColors.textSecondary)
                    Spacer()
                } else {
                    ForEach(entry.upcomingMeetings.prefix(3)) { meeting in
                        MeetingRowView(meeting: meeting)
                    }
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Rectangle()
                .fill(WidgetColors.glassBorder)
                .frame(width: 1)

            VStack(alignment: .leading, spacing: 12) {
                if entry.configuration.showActionItems {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 11))
                                .foregroundColor(entry.overdueActionItemsCount > 0 ? WidgetColors.orange : WidgetColors.green)
                            Text("Action Items")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(WidgetColors.textSecondary)
                        }
                        if entry.overdueActionItemsCount > 0 {
                            Text("\(entry.overdueActionItemsCount) overdue")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(WidgetColors.orange)
                        } else {
                            Text("All clear")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(WidgetColors.green)
                        }
                    }
                }
                if entry.configuration.showOverduePeople && !entry.peopleToMeetSoon.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "person.crop.circle.badge.clock")
                                .font(.system(size: 11))
                                .foregroundColor(WidgetColors.pink)
                            Text("Overdue")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(WidgetColors.textSecondary)
                        }
                        HStack(spacing: -6) {
                            ForEach(entry.peopleToMeetSoon.prefix(3)) { person in
                                PersonAvatar(initials: person.initials, color: person.color, size: 24)
                                    .overlay(Circle().stroke(WidgetColors.gradientStart, lineWidth: 2))
                            }
                        }
                    }
                }
                Spacer()
            }
            .frame(width: 100)
        }
        .padding(12)
    }
}

// Large
struct LargeWidgetView: View {
    let entry: OneOnOneEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(WidgetColors.cyan)
                Text("OneOnOne")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(WidgetColors.textPrimary)
                Spacer()
                HStack(spacing: 8) {
                    if entry.overdueActionItemsCount > 0 {
                        StatBadge(icon: "exclamationmark.circle.fill", count: entry.overdueActionItemsCount, color: WidgetColors.orange)
                    }
                    if !entry.peopleToMeetSoon.isEmpty {
                        StatBadge(icon: "person.crop.circle.badge.clock", count: entry.peopleToMeetSoon.count, color: WidgetColors.pink)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Upcoming Meetings")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(WidgetColors.textSecondary)
                if entry.upcomingMeetings.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 4) {
                            Image(systemName: "calendar.badge.checkmark")
                                .font(.system(size: 24))
                                .foregroundColor(WidgetColors.textTertiary)
                            Text("No upcoming meetings")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(WidgetColors.textTertiary)
                        }
                        .padding(.vertical, 16)
                        Spacer()
                    }
                } else {
                    ForEach(entry.upcomingMeetings.prefix(4)) { meeting in
                        LargeMeetingRowView(meeting: meeting)
                    }
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 16).fill(WidgetColors.glassBackground))

            if entry.configuration.showOverduePeople && !entry.peopleToMeetSoon.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Need to Meet")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(WidgetColors.textSecondary)
                    ForEach(entry.peopleToMeetSoon.prefix(3)) { person in
                        PersonRowView(person: person)
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 16).fill(WidgetColors.glassBackground))
            }

            Spacer()
        }
        .padding(16)
    }
}

struct MeetingRowView: View {
    let meeting: WidgetMeeting
    var body: some View {
        HStack(spacing: 8) {
            PersonAvatar(initials: meeting.personInitials, color: meeting.personColor, size: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(meeting.title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(WidgetColors.textPrimary)
                    .lineLimit(1)
                Text("\(meeting.dayString), \(meeting.timeString)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(WidgetColors.textTertiary)
            }
            Spacer()
        }
    }
}

struct LargeMeetingRowView: View {
    let meeting: WidgetMeeting
    var body: some View {
        HStack(spacing: 12) {
            PersonAvatar(initials: meeting.personInitials, color: meeting.personColor, size: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(meeting.title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(WidgetColors.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text(meeting.personName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(WidgetColors.textSecondary)
                    Text(meeting.meetingType)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(WidgetColors.cyan)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(WidgetColors.cyan.opacity(0.2))
                        .clipShape(Capsule())
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(meeting.dayString)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(meeting.isToday ? WidgetColors.cyan : WidgetColors.textSecondary)
                Text(meeting.timeString)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(WidgetColors.textTertiary)
            }
        }
    }
}

struct PersonRowView: View {
    let person: WidgetPerson
    var body: some View {
        HStack(spacing: 12) {
            PersonAvatar(initials: person.initials, color: person.color, size: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(person.name)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(WidgetColors.textPrimary)
                    .lineLimit(1)
                Text(person.overdueText)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(WidgetColors.pink)
            }
            Spacer()
            Text(person.meetingFrequency)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(WidgetColors.textSecondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(WidgetColors.glassBackground)
                .clipShape(Capsule())
        }
    }
}

struct OneOnOneWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: OneOnOneEntry

    var body: some View {
        Group {
            switch family {
            case .systemSmall: SmallWidgetView(entry: entry)
            case .systemMedium: MediumWidgetView(entry: entry)
            case .systemLarge: LargeWidgetView(entry: entry)
            default: SmallWidgetView(entry: entry)
            }
        }
        .containerBackground(for: .widget) { WidgetColors.backgroundGradient }
    }
}

struct OneOnOneWidget: Widget {
    let kind: String = "OneOnOneWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: OneOnOneWidgetProvider()) { entry in
            OneOnOneWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("OneOnOne")
        .description("View your upcoming 1:1 meetings, action items, and people to meet with.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

// ============================================================================
// MARK: - 2. ACTION ITEMS WIDGET
// ============================================================================

struct ActionItemsWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> OneOnOneEntry { .placeholder }
    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> OneOnOneEntry { loadEntry(for: configuration) }
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<OneOnOneEntry> {
        let entry = loadEntry(for: configuration)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }
}

// Small - counts
struct ActionItemsSmallView: View {
    let entry: OneOnOneEntry

    var overdueItems: [WidgetActionItem] { entry.actionItems.filter { $0.isOverdue } }
    var dueSoonItems: [WidgetActionItem] { entry.actionItems.filter { !$0.isOverdue && $0.dueDate != nil } }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "checklist")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(WidgetColors.orange)
                Text("Tasks")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(WidgetColors.textPrimary)
                Spacer()
            }

            Spacer()

            if entry.actionItems.isEmpty {
                VStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(WidgetColors.green)
                    Text("All clear!")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(WidgetColors.green)
                }
                .frame(maxWidth: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    if !overdueItems.isEmpty {
                        HStack(spacing: 6) {
                            Circle().fill(WidgetColors.red).frame(width: 8, height: 8)
                            Text("\(overdueItems.count) overdue")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(WidgetColors.red)
                        }
                    }
                    HStack(spacing: 6) {
                        Circle().fill(WidgetColors.cyan).frame(width: 8, height: 8)
                        Text("\(entry.actionItems.count) open")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(WidgetColors.cyan)
                    }
                }
            }

            Spacer()
        }
        .padding(12)
    }
}

// Medium - list of 3-4
struct ActionItemsMediumView: View {
    let entry: OneOnOneEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "checklist")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(WidgetColors.orange)
                Text("Action Items")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(WidgetColors.textPrimary)
                Spacer()
                if !entry.actionItems.isEmpty {
                    Text("\(entry.actionItems.count) open")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(WidgetColors.textTertiary)
                }
            }

            if entry.actionItems.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(WidgetColors.green)
                        Text("No open action items")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(WidgetColors.textSecondary)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                ForEach(Array(entry.actionItems.prefix(4))) { item in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(WidgetColors.colorFromHex(item.priorityColor))
                            .frame(width: 6, height: 6)
                        Text(item.title)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(item.isOverdue ? WidgetColors.red : WidgetColors.textPrimary)
                            .lineLimit(1)
                        Spacer()
                        Text(item.dueDateString)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(item.isOverdue ? WidgetColors.red : WidgetColors.textTertiary)
                    }
                }
                Spacer()
            }
        }
        .padding(12)
    }
}

// Large - full list
struct ActionItemsLargeView: View {
    let entry: OneOnOneEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "checklist")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(WidgetColors.orange)
                Text("Action Items")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(WidgetColors.textPrimary)
                Spacer()
                if entry.actionItems.filter({ $0.isOverdue }).count > 0 {
                    StatBadge(icon: "exclamationmark.circle.fill", count: entry.actionItems.filter({ $0.isOverdue }).count, color: WidgetColors.red)
                }
            }

            if entry.actionItems.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(WidgetColors.green)
                        Text("All action items complete!")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(WidgetColors.textSecondary)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                VStack(spacing: 6) {
                    ForEach(Array(entry.actionItems.prefix(8))) { item in
                        HStack(spacing: 10) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(WidgetColors.colorFromHex(item.priorityColor))
                                .frame(width: 3, height: 28)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(item.isOverdue ? WidgetColors.red : WidgetColors.textPrimary)
                                    .lineLimit(1)
                                HStack(spacing: 8) {
                                    if let assignee = item.assigneeName {
                                        Text(assignee)
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundColor(WidgetColors.textSecondary)
                                    }
                                    Text(item.meetingTitle)
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(WidgetColors.textTertiary)
                                        .lineLimit(1)
                                }
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text(item.priority)
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(WidgetColors.colorFromHex(item.priorityColor))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(WidgetColors.colorFromHex(item.priorityColor).opacity(0.2))
                                    .clipShape(Capsule())
                                Text(item.dueDateString)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(item.isOverdue ? WidgetColors.red : WidgetColors.textTertiary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 16).fill(WidgetColors.glassBackground))
            }

            Spacer()
        }
        .padding(16)
    }
}

struct ActionItemsWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: OneOnOneEntry

    var body: some View {
        Group {
            switch family {
            case .systemSmall: ActionItemsSmallView(entry: entry)
            case .systemMedium: ActionItemsMediumView(entry: entry)
            case .systemLarge: ActionItemsLargeView(entry: entry)
            default: ActionItemsSmallView(entry: entry)
            }
        }
        .containerBackground(for: .widget) { WidgetColors.backgroundGradient }
    }
}

struct ActionItemsWidget: Widget {
    let kind: String = "ActionItemsWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: ActionItemsWidgetProvider()) { entry in
            ActionItemsWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Action Items")
        .description("Track your open action items and overdue tasks from meetings.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

// ============================================================================
// MARK: - 3. MEETING STREAK WIDGET
// ============================================================================

struct MeetingStreakWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> OneOnOneEntry { .placeholder }
    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> OneOnOneEntry { loadEntry(for: configuration) }
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<OneOnOneEntry> {
        let entry = loadEntry(for: configuration)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }
}

// Small - top streak
struct MeetingStreakSmallView: View {
    let entry: OneOnOneEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "flame.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(WidgetColors.orange)
                Text("Streak")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(WidgetColors.textPrimary)
                Spacer()
            }

            Spacer()

            if let top = entry.streakPeople.first {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        PersonAvatar(initials: top.initials, color: top.color, size: 24)
                        Text(top.name.components(separatedBy: " ").first ?? top.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(WidgetColors.textPrimary)
                            .lineLimit(1)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 16))
                            .foregroundColor(WidgetColors.orange)
                        Text("\(top.currentStreak)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(WidgetColors.textPrimary)
                        Text("weeks")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(WidgetColors.textTertiary)
                    }
                }
            } else {
                VStack(spacing: 4) {
                    Image(systemName: "flame")
                        .font(.system(size: 20))
                        .foregroundColor(WidgetColors.textTertiary)
                    Text("No streaks yet")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(WidgetColors.textTertiary)
                }
                .frame(maxWidth: .infinity)
            }

            Spacer()
        }
        .padding(12)
    }
}

// Medium - top 3 people
struct MeetingStreakMediumView: View {
    let entry: OneOnOneEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "flame.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(WidgetColors.orange)
                Text("Meeting Streaks")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(WidgetColors.textPrimary)
                Spacer()
            }

            if entry.streakPeople.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "flame")
                            .font(.system(size: 20))
                            .foregroundColor(WidgetColors.textTertiary)
                        Text("Start meeting regularly to build streaks")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(WidgetColors.textTertiary)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                ForEach(Array(entry.streakPeople.prefix(3))) { person in
                    HStack(spacing: 10) {
                        PersonAvatar(initials: person.initials, color: person.color, size: 24)
                        Text(person.name.components(separatedBy: " ").first ?? person.name)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(WidgetColors.textPrimary)
                            .lineLimit(1)

                        Spacer()

                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 10))
                                .foregroundColor(WidgetColors.orange)
                            Text("\(person.currentStreak)w")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(WidgetColors.textPrimary)
                        }

                        Image(systemName: person.isOnTrack ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(person.isOnTrack ? WidgetColors.green : WidgetColors.orange)
                    }
                }
                Spacer()
            }
        }
        .padding(12)
    }
}

struct MeetingStreakWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: OneOnOneEntry

    var body: some View {
        Group {
            switch family {
            case .systemSmall: MeetingStreakSmallView(entry: entry)
            case .systemMedium: MeetingStreakMediumView(entry: entry)
            default: MeetingStreakSmallView(entry: entry)
            }
        }
        .containerBackground(for: .widget) { WidgetColors.backgroundGradient }
    }
}

struct MeetingStreakWidget: Widget {
    let kind: String = "MeetingStreakWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: MeetingStreakWidgetProvider()) { entry in
            MeetingStreakWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Meeting Streaks")
        .description("Track your consecutive meeting weeks with each person.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

// ============================================================================
// MARK: - 4. TODAY'S SCHEDULE WIDGET
// ============================================================================

struct TodayScheduleWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> OneOnOneEntry { .placeholder }
    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> OneOnOneEntry { loadEntry(for: configuration) }
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<OneOnOneEntry> {
        let entry = loadEntry(for: configuration)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }
}

// Small - next today
struct TodayScheduleSmallView: View {
    let entry: OneOnOneEntry

    var nextMeeting: WidgetMeeting? {
        entry.todayMeetings.first { $0.date > Date() } ?? entry.todayMeetings.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(WidgetColors.cyan)
                Text("Today")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(WidgetColors.textPrimary)
                Spacer()
                Text("\(entry.todayMeetings.count)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(WidgetColors.textTertiary)
            }

            Spacer()

            if let meeting = nextMeeting {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Up Next")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(WidgetColors.textTertiary)
                    Text(meeting.title)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(WidgetColors.textPrimary)
                        .lineLimit(2)
                    HStack(spacing: 4) {
                        PersonAvatar(initials: meeting.personInitials, color: meeting.personColor, size: 16)
                        Text(meeting.timeString)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(WidgetColors.textSecondary)
                    }
                }
            } else {
                VStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(WidgetColors.green)
                    Text("Free today!")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(WidgetColors.green)
                }
                .frame(maxWidth: .infinity)
            }

            Spacer()
        }
        .padding(12)
    }
}

// Medium - timeline
struct TodayScheduleMediumView: View {
    let entry: OneOnOneEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(WidgetColors.cyan)
                Text("Today's Schedule")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(WidgetColors.textPrimary)
                Spacer()
                Text("\(entry.todayMeetings.count) meetings")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(WidgetColors.textTertiary)
            }

            if entry.todayMeetings.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "sun.max.fill")
                            .font(.system(size: 20))
                            .foregroundColor(WidgetColors.green)
                        Text("No meetings today")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(WidgetColors.textSecondary)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                HStack(alignment: .top, spacing: 0) {
                    // Timeline
                    ForEach(Array(entry.todayMeetings.prefix(4).enumerated()), id: \.element.id) { index, meeting in
                        VStack(spacing: 4) {
                            Text(meeting.timeString)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(meeting.date > Date() ? WidgetColors.cyan : WidgetColors.textTertiary)

                            Circle()
                                .fill(meeting.date > Date() ? WidgetColors.cyan : WidgetColors.textTertiary)
                                .frame(width: 8, height: 8)

                            Text(meeting.title)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(WidgetColors.textPrimary)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)

                            PersonAvatar(initials: meeting.personInitials, color: meeting.personColor, size: 20)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                Spacer()
            }
        }
        .padding(12)
    }
}

// Large - full agenda
struct TodayScheduleLargeView: View {
    let entry: OneOnOneEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(WidgetColors.cyan)
                Text("Today's Schedule")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(WidgetColors.textPrimary)
                Spacer()
                Text("\(entry.todayMeetings.count) meetings")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(WidgetColors.textTertiary)
            }

            if entry.todayMeetings.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "sun.max.fill")
                            .font(.system(size: 32))
                            .foregroundColor(WidgetColors.green)
                        Text("Your day is clear!")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(WidgetColors.green)
                        Text("No meetings scheduled for today")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(WidgetColors.textTertiary)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(entry.todayMeetings.prefix(6).enumerated()), id: \.element.id) { index, meeting in
                        HStack(spacing: 12) {
                            // Time column
                            Text(meeting.timeString)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(meeting.date > Date() ? WidgetColors.cyan : WidgetColors.textTertiary)
                                .frame(width: 60, alignment: .trailing)

                            // Timeline dot and line
                            VStack(spacing: 0) {
                                if index > 0 {
                                    Rectangle()
                                        .fill(WidgetColors.glassBorder)
                                        .frame(width: 1, height: 8)
                                }
                                Circle()
                                    .fill(meeting.date > Date() ? WidgetColors.cyan : WidgetColors.textTertiary)
                                    .frame(width: 10, height: 10)
                                if index < entry.todayMeetings.prefix(6).count - 1 {
                                    Rectangle()
                                        .fill(WidgetColors.glassBorder)
                                        .frame(width: 1, height: 8)
                                }
                            }

                            // Meeting info
                            VStack(alignment: .leading, spacing: 2) {
                                Text(meeting.title)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(WidgetColors.textPrimary)
                                    .lineLimit(1)
                                HStack(spacing: 6) {
                                    PersonAvatar(initials: meeting.personInitials, color: meeting.personColor, size: 16)
                                    Text(meeting.personName)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(WidgetColors.textSecondary)
                                    Text(meeting.meetingType)
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundColor(WidgetColors.purple)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1)
                                        .background(WidgetColors.purple.opacity(0.2))
                                        .clipShape(Capsule())
                                }
                            }

                            Spacer()
                        }
                        .padding(.vertical, 6)
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 16).fill(WidgetColors.glassBackground))
            }

            Spacer()
        }
        .padding(16)
    }
}

struct TodayScheduleWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: OneOnOneEntry

    var body: some View {
        Group {
            switch family {
            case .systemSmall: TodayScheduleSmallView(entry: entry)
            case .systemMedium: TodayScheduleMediumView(entry: entry)
            case .systemLarge: TodayScheduleLargeView(entry: entry)
            default: TodayScheduleSmallView(entry: entry)
            }
        }
        .containerBackground(for: .widget) { WidgetColors.backgroundGradient }
    }
}

struct TodayScheduleWidget: Widget {
    let kind: String = "TodayScheduleWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: TodayScheduleWidgetProvider()) { entry in
            TodayScheduleWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Today's Schedule")
        .description("See your meetings for today at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

// ============================================================================
// MARK: - 5. QUICK NOTES WIDGET
// ============================================================================

struct QuickNotesWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> OneOnOneEntry { .placeholder }
    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> OneOnOneEntry { loadEntry(for: configuration) }
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<OneOnOneEntry> {
        let entry = loadEntry(for: configuration)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }
}

// Medium - last meeting notes
struct QuickNotesMediumView: View {
    let entry: OneOnOneEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "note.text")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(WidgetColors.purple)
                Text("Recent Notes")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(WidgetColors.textPrimary)
                Spacer()
            }

            if let note = entry.recentNotes.first {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        PersonAvatar(initials: note.personInitials, color: note.personColor, size: 20)
                        Text(note.meetingTitle)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(WidgetColors.textPrimary)
                            .lineLimit(1)
                        Spacer()
                        Text(note.dateString)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(WidgetColors.textTertiary)
                    }
                    Text(note.notePreview)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(WidgetColors.textSecondary)
                        .lineLimit(3)
                }
            } else {
                Spacer()
                HStack {
                    Spacer()
                    Text("No meeting notes yet")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(WidgetColors.textTertiary)
                    Spacer()
                }
                Spacer()
            }

            Spacer()
        }
        .padding(12)
    }
}

// Large - last 3 meetings
struct QuickNotesLargeView: View {
    let entry: OneOnOneEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "note.text")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(WidgetColors.purple)
                Text("Recent Notes")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(WidgetColors.textPrimary)
                Spacer()
            }

            if entry.recentNotes.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "note.text")
                            .font(.system(size: 32))
                            .foregroundColor(WidgetColors.textTertiary)
                        Text("No meeting notes yet")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(WidgetColors.textTertiary)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                ForEach(Array(entry.recentNotes.prefix(3))) { note in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            PersonAvatar(initials: note.personInitials, color: note.personColor, size: 24)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(note.meetingTitle)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(WidgetColors.textPrimary)
                                    .lineLimit(1)
                                HStack(spacing: 6) {
                                    Text(note.personName)
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(WidgetColors.textSecondary)
                                    Text(note.dateString)
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(WidgetColors.textTertiary)
                                }
                            }
                            Spacer()
                        }
                        Text(note.notePreview)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(WidgetColors.textSecondary)
                            .lineLimit(2)
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 12).fill(WidgetColors.glassBackground))
                }
            }

            Spacer()
        }
        .padding(16)
    }
}

struct QuickNotesWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: OneOnOneEntry

    var body: some View {
        Group {
            switch family {
            case .systemMedium: QuickNotesMediumView(entry: entry)
            case .systemLarge: QuickNotesLargeView(entry: entry)
            default: QuickNotesMediumView(entry: entry)
            }
        }
        .containerBackground(for: .widget) { WidgetColors.backgroundGradient }
    }
}

struct QuickNotesWidget: Widget {
    let kind: String = "QuickNotesWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: QuickNotesWidgetProvider()) { entry in
            QuickNotesWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Quick Notes")
        .description("See recent meeting notes at a glance.")
        .supportedFamilies([.systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

// ============================================================================
// MARK: - 6. MOOD TRACKER WIDGET
// ============================================================================

struct MoodTrackerWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> OneOnOneEntry { .placeholder }
    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> OneOnOneEntry { loadEntry(for: configuration) }
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<OneOnOneEntry> {
        let entry = loadEntry(for: configuration)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }
}

// Small - most recent mood
struct MoodTrackerSmallView: View {
    let entry: OneOnOneEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "heart.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(WidgetColors.pink)
                Text("Mood")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(WidgetColors.textPrimary)
                Spacer()
            }

            Spacer()

            if let latest = entry.moodHistory.first {
                VStack(spacing: 6) {
                    Image(systemName: latest.moodIcon)
                        .font(.system(size: 28))
                        .foregroundColor(WidgetColors.colorFromHex(latest.moodColor))
                    Text(latest.mood)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(WidgetColors.textPrimary)
                    Text("Last meeting")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(WidgetColors.textTertiary)
                }
                .frame(maxWidth: .infinity)
            } else {
                VStack(spacing: 4) {
                    Image(systemName: "heart")
                        .font(.system(size: 20))
                        .foregroundColor(WidgetColors.textTertiary)
                    Text("No mood data")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(WidgetColors.textTertiary)
                }
                .frame(maxWidth: .infinity)
            }

            Spacer()
        }
        .padding(12)
    }
}

// Medium - mood timeline
struct MoodTrackerMediumView: View {
    let entry: OneOnOneEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "heart.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(WidgetColors.pink)
                Text("Meeting Moods")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(WidgetColors.textPrimary)
                Spacer()
                if let latest = entry.moodHistory.first {
                    Text(latest.mood)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(WidgetColors.colorFromHex(latest.moodColor))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(WidgetColors.colorFromHex(latest.moodColor).opacity(0.2))
                        .clipShape(Capsule())
                }
            }

            if entry.moodHistory.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    Text("Set meeting moods to track trends")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(WidgetColors.textTertiary)
                    Spacer()
                }
                Spacer()
            } else {
                Spacer()
                // Mood dots timeline (most recent on right)
                HStack(spacing: 0) {
                    ForEach(Array(entry.moodHistory.prefix(7).reversed().enumerated()), id: \.offset) { index, mood in
                        VStack(spacing: 4) {
                            Image(systemName: mood.moodIcon)
                                .font(.system(size: 16))
                                .foregroundColor(WidgetColors.colorFromHex(mood.moodColor))
                            Text(mood.dayLabel)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(WidgetColors.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                Spacer()
            }
        }
        .padding(12)
    }
}

struct MoodTrackerWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: OneOnOneEntry

    var body: some View {
        Group {
            switch family {
            case .systemSmall: MoodTrackerSmallView(entry: entry)
            case .systemMedium: MoodTrackerMediumView(entry: entry)
            default: MoodTrackerSmallView(entry: entry)
            }
        }
        .containerBackground(for: .widget) { WidgetColors.backgroundGradient }
    }
}

struct MoodTrackerWidget: Widget {
    let kind: String = "MoodTrackerWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: MoodTrackerWidgetProvider()) { entry in
            MoodTrackerWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Mood Tracker")
        .description("Track the mood and sentiment of your recent meetings.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

// ============================================================================
// MARK: - 7. LOCK SCREEN WIDGET (iOS only)
// ============================================================================

#if os(iOS)
struct LockScreenWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> OneOnOneEntry { .placeholder }
    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> OneOnOneEntry { loadEntry(for: configuration) }
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<OneOnOneEntry> {
        let entry = loadEntry(for: configuration)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }
}

// Circular - next meeting time
struct LockScreenCircularView: View {
    let entry: OneOnOneEntry

    var body: some View {
        if let next = entry.upcomingMeetings.first {
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 2) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 10))
                    Text(next.timeString)
                        .font(.system(size: 12, weight: .bold))
                        .minimumScaleFactor(0.6)
                }
            }
        } else {
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 2) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 10))
                    Text("Free")
                        .font(.system(size: 12, weight: .bold))
                }
            }
        }
    }
}

// Rectangular - next meeting details
struct LockScreenRectangularView: View {
    let entry: OneOnOneEntry

    var body: some View {
        if let next = entry.upcomingMeetings.first {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 10))
                    Text("Next 1:1")
                        .font(.system(size: 11, weight: .semibold))
                }
                Text(next.title)
                    .font(.system(size: 13, weight: .bold))
                    .lineLimit(1)
                Text("\(next.personName) \u{2022} \(next.dayString) \(next.timeString)")
                    .font(.system(size: 11))
                    .lineLimit(1)
            }
        } else {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 10))
                    Text("OneOnOne")
                        .font(.system(size: 11, weight: .semibold))
                }
                Text("No upcoming meetings")
                    .font(.system(size: 13, weight: .bold))
            }
        }
    }
}

// Inline - one-line summary
struct LockScreenInlineView: View {
    let entry: OneOnOneEntry

    var body: some View {
        if let next = entry.upcomingMeetings.first {
            Text("Next: \(next.title) at \(next.timeString)")
        } else {
            Text("No upcoming 1:1 meetings")
        }
    }
}

struct LockScreenWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: OneOnOneEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            LockScreenCircularView(entry: entry)
        case .accessoryRectangular:
            LockScreenRectangularView(entry: entry)
        case .accessoryInline:
            LockScreenInlineView(entry: entry)
        default:
            LockScreenCircularView(entry: entry)
        }
    }
}

struct LockScreenWidget: Widget {
    let kind: String = "LockScreenWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: LockScreenWidgetProvider()) { entry in
            LockScreenWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("OneOnOne Lock Screen")
        .description("See your next meeting on the lock screen.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}
#endif

// ============================================================================
// MARK: - Widget Bundle
// ============================================================================

@main
struct OneOnOneWidgetBundle: WidgetBundle {
    var body: some Widget {
        OneOnOneWidget()
        ActionItemsWidget()
        MeetingStreakWidget()
        TodayScheduleWidget()
        QuickNotesWidget()
        MoodTrackerWidget()
        #if os(iOS)
        LockScreenWidget()
        #endif
    }
}

// ============================================================================
// MARK: - Previews
// ============================================================================

#Preview(as: .systemSmall) {
    OneOnOneWidget()
} timeline: {
    OneOnOneEntry.placeholder
}

#Preview(as: .systemMedium) {
    OneOnOneWidget()
} timeline: {
    OneOnOneEntry.placeholder
}

#Preview(as: .systemLarge) {
    OneOnOneWidget()
} timeline: {
    OneOnOneEntry.placeholder
}

#Preview(as: .systemSmall) {
    ActionItemsWidget()
} timeline: {
    OneOnOneEntry.placeholder
}

#Preview(as: .systemMedium) {
    ActionItemsWidget()
} timeline: {
    OneOnOneEntry.placeholder
}

#Preview(as: .systemSmall) {
    MeetingStreakWidget()
} timeline: {
    OneOnOneEntry.placeholder
}

#Preview(as: .systemMedium) {
    MeetingStreakWidget()
} timeline: {
    OneOnOneEntry.placeholder
}

#Preview(as: .systemSmall) {
    TodayScheduleWidget()
} timeline: {
    OneOnOneEntry.placeholder
}

#Preview(as: .systemMedium) {
    TodayScheduleWidget()
} timeline: {
    OneOnOneEntry.placeholder
}

#Preview(as: .systemMedium) {
    QuickNotesWidget()
} timeline: {
    OneOnOneEntry.placeholder
}

#Preview(as: .systemLarge) {
    QuickNotesWidget()
} timeline: {
    OneOnOneEntry.placeholder
}

#Preview(as: .systemSmall) {
    MoodTrackerWidget()
} timeline: {
    OneOnOneEntry.placeholder
}

#Preview(as: .systemMedium) {
    MoodTrackerWidget()
} timeline: {
    OneOnOneEntry.placeholder
}
