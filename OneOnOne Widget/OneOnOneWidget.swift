//
//  OneOnOneWidget.swift
//  OneOnOne Widget
//
//  WidgetKit widget for OneOnOne app showing upcoming meetings,
//  overdue action items, and people to meet with soon
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

// MARK: - Widget Provider

struct OneOnOneWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> OneOnOneEntry {
        .placeholder
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> OneOnOneEntry {
        let data = SharedDataManager.shared.readWidgetData()
        return OneOnOneEntry(
            date: Date(),
            upcomingMeetings: data.upcomingMeetings,
            overdueActionItemsCount: data.overdueActionItemsCount,
            peopleToMeetSoon: data.peopleToMeetSoon,
            configuration: configuration
        )
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<OneOnOneEntry> {
        let data = SharedDataManager.shared.readWidgetData()

        let entry = OneOnOneEntry(
            date: Date(),
            upcomingMeetings: data.upcomingMeetings,
            overdueActionItemsCount: data.overdueActionItemsCount,
            peopleToMeetSoon: data.peopleToMeetSoon,
            configuration: configuration
        )

        // Update timeline every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()

        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }
}

// MARK: - Widget Colors

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

// MARK: - Small Widget View

struct SmallWidgetView: View {
    let entry: OneOnOneEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
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

            // Next meeting
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

            // Stats row
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

// MARK: - Medium Widget View

struct MediumWidgetView: View {
    let entry: OneOnOneEntry

    var body: some View {
        HStack(spacing: 16) {
            // Left side - Upcoming meetings
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

            // Divider
            Rectangle()
                .fill(WidgetColors.glassBorder)
                .frame(width: 1)

            // Right side - Stats and alerts
            VStack(alignment: .leading, spacing: 12) {
                // Overdue action items
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

                // People to meet
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
                                    .overlay(
                                        Circle()
                                            .stroke(WidgetColors.gradientStart, lineWidth: 2)
                                    )
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

// MARK: - Large Widget View

struct LargeWidgetView: View {
    let entry: OneOnOneEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(WidgetColors.cyan)
                Text("OneOnOne")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(WidgetColors.textPrimary)
                Spacer()

                // Stats badges
                HStack(spacing: 8) {
                    if entry.overdueActionItemsCount > 0 {
                        StatBadge(
                            icon: "exclamationmark.circle.fill",
                            count: entry.overdueActionItemsCount,
                            color: WidgetColors.orange
                        )
                    }
                    if !entry.peopleToMeetSoon.isEmpty {
                        StatBadge(
                            icon: "person.crop.circle.badge.clock",
                            count: entry.peopleToMeetSoon.count,
                            color: WidgetColors.pink
                        )
                    }
                }
            }

            // Upcoming meetings section
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
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(WidgetColors.glassBackground)
            )

            // People to meet section
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
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(WidgetColors.glassBackground)
                )
            }

            Spacer()
        }
        .padding(16)
    }
}

// MARK: - Supporting Views

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

// MARK: - Widget Entry View

struct OneOnOneWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: OneOnOneEntry

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                SmallWidgetView(entry: entry)
            case .systemMedium:
                MediumWidgetView(entry: entry)
            case .systemLarge:
                LargeWidgetView(entry: entry)
            default:
                SmallWidgetView(entry: entry)
            }
        }
        .containerBackground(for: .widget) {
            WidgetColors.backgroundGradient
        }
    }
}

// MARK: - Widget Definition

struct OneOnOneWidget: Widget {
    let kind: String = "OneOnOneWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: ConfigurationAppIntent.self,
            provider: OneOnOneWidgetProvider()
        ) { entry in
            OneOnOneWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("OneOnOne")
        .description("View your upcoming 1:1 meetings, action items, and people to meet with.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

// MARK: - Widget Bundle

@main
struct OneOnOneWidgetBundle: WidgetBundle {
    var body: some Widget {
        OneOnOneWidget()
    }
}

// MARK: - Preview

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
