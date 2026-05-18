//
//  WidgetSyncService.swift
//  OneOnOne
//
//  Syncs meeting data to the widget extension via App Groups
//  Created by Jordan Koch on 2026-02-04.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation
import WidgetKit

/// Service for syncing data between the main app and the widget extension
@MainActor
class WidgetSyncService {
    static let shared = WidgetSyncService()

    /// App Group identifier for data sharing
    private let appGroupIdentifier = "group.com.jkoch.oneonone"

    /// File name for shared widget data
    private let sharedDataFileName = "widget_data.json"

    private init() {}

    // MARK: - App Group Container

    /// Returns the shared container URL for the app group
    private var sharedContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }

    /// Returns the URL for the shared data file
    private var sharedDataFileURL: URL? {
        sharedContainerURL?.appendingPathComponent(sharedDataFileName)
    }

    // MARK: - Sync Data

    /// Syncs the current app data to the widget
    func syncToWidget() {
        let dataStore = DataStore.shared

        let widgetData = createWidgetData(
            people: dataStore.people,
            meetings: dataStore.meetings,
            actionItems: dataStore.allActionItems()
        )

        writeWidgetData(widgetData)
    }

    /// Creates widget data from app models
    private func createWidgetData(
        people: [Person],
        meetings: [Meeting],
        actionItems: [ActionItem]
    ) -> WidgetSharedData {
        let now = Date()
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now

        // Get upcoming meetings (next 7 days)
        let upcomingMeetings = meetings
            .filter { $0.date > now }
            .sorted { $0.date < $1.date }
            .prefix(10)
            .map { meeting -> WidgetMeetingData in
                let firstAttendee = meeting.attendees.first.flatMap { attendeeId in
                    people.first { $0.id == attendeeId }
                }
                return WidgetMeetingData(
                    id: meeting.id,
                    title: meeting.title,
                    personName: firstAttendee?.name ?? "Meeting",
                    personInitials: firstAttendee?.initials ?? "M",
                    personColor: firstAttendee?.avatarColor ?? "#3BDAFC",
                    date: meeting.date,
                    meetingType: meeting.meetingType.rawValue
                )
            }

        // Count overdue action items
        let overdueCount = actionItems.filter { $0.isOverdue }.count

        // Find people who need meetings based on their frequency
        let peopleToMeetSoon = people
            .compactMap { person -> WidgetPersonData? in
                guard let calendarDays = person.meetingFrequency.calendarDays else {
                    return nil // "As Needed" frequency
                }

                let daysSinceLastMeeting: Int
                if let lastMeeting = person.lastMeetingDate {
                    daysSinceLastMeeting = calendar.dateComponents([.day], from: lastMeeting, to: now).day ?? 0
                } else {
                    daysSinceLastMeeting = calendarDays + 1 // Never met, mark as overdue
                }

                // Only include if overdue for meeting
                guard daysSinceLastMeeting >= calendarDays else {
                    return nil
                }

                return WidgetPersonData(
                    id: person.id,
                    name: person.name,
                    initials: person.initials,
                    color: person.avatarColor,
                    daysSinceLastMeeting: daysSinceLastMeeting,
                    meetingFrequency: person.meetingFrequency.rawValue
                )
            }
            .sorted { $0.daysSinceLastMeeting > $1.daysSinceLastMeeting }
            .prefix(5)

        // Count meetings this week
        let meetingsThisWeek = meetings.filter { $0.date >= weekAgo && $0.date <= now }.count

        // --- New widget data ---

        // Action items (open, sorted by priority then due date)
        let widgetActionItems: [WidgetActionItemData] = actionItems
            .filter { !$0.isCompleted }
            .sorted { a, b in
                if a.priority.sortOrder != b.priority.sortOrder {
                    return a.priority.sortOrder < b.priority.sortOrder
                }
                let aDate = a.dueDate ?? Date.distantFuture
                let bDate = b.dueDate ?? Date.distantFuture
                return aDate < bDate
            }
            .prefix(10)
            .map { item in
                let assignee = item.assigneeId.flatMap { id in people.first { $0.id == id } }
                let meetingTitle = meetings.first { $0.id == item.meetingId }?.title ?? ""
                return WidgetActionItemData(
                    id: item.id,
                    title: item.title,
                    priority: item.priority.rawValue,
                    priorityColor: item.priority.color,
                    dueDate: item.dueDate,
                    assigneeName: assignee?.name.components(separatedBy: " ").first,
                    isOverdue: item.isOverdue,
                    meetingTitle: meetingTitle
                )
            }

        // Today's meetings
        let todayMeetings = meetings
            .filter { calendar.isDateInToday($0.date) }
            .sorted { $0.date < $1.date }
            .map { meeting -> WidgetMeetingData in
                let firstAttendee = meeting.attendees.first.flatMap { attendeeId in
                    people.first { $0.id == attendeeId }
                }
                return WidgetMeetingData(
                    id: meeting.id,
                    title: meeting.title,
                    personName: firstAttendee?.name ?? "Meeting",
                    personInitials: firstAttendee?.initials ?? "M",
                    personColor: firstAttendee?.avatarColor ?? "#3BDAFC",
                    date: meeting.date,
                    meetingType: meeting.meetingType.rawValue
                )
            }

        // Streak data: consecutive weeks with meetings per person
        let streakPeople: [WidgetStreakPersonData] = people.compactMap { person in
            guard let calendarDays = person.meetingFrequency.calendarDays, calendarDays > 0 else { return nil }

            let personMeetings = meetings
                .filter { $0.attendees.contains(person.id) && $0.date <= now }
                .sorted { $0.date > $1.date }

            guard !personMeetings.isEmpty else { return nil }

            // Calculate streak: how many consecutive frequency periods had meetings
            var streak = 0
            var checkDate = now
            let periodDays = calendarDays

            for _ in 0..<52 { // Check up to a year
                let periodStart = calendar.date(byAdding: .day, value: -periodDays, to: checkDate) ?? checkDate
                let hadMeeting = personMeetings.contains { $0.date >= periodStart && $0.date <= checkDate }
                if hadMeeting {
                    streak += 1
                    checkDate = periodStart
                } else {
                    break
                }
            }

            guard streak > 0 else { return nil }

            // Check if on track (had a meeting in the current period)
            let currentPeriodStart = calendar.date(byAdding: .day, value: -periodDays, to: now) ?? now
            let isOnTrack = personMeetings.contains { $0.date >= currentPeriodStart }

            return WidgetStreakPersonData(
                id: person.id,
                name: person.name,
                initials: person.initials,
                color: person.avatarColor,
                currentStreak: streak,
                frequency: person.meetingFrequency.rawValue,
                isOnTrack: isOnTrack
            )
        }
        .sorted { $0.currentStreak > $1.currentStreak }
        .prefix(5)
        .map { $0 }

        // Recent meeting notes (last 5 meetings with non-empty notes)
        let recentNotes: [WidgetQuickNoteData] = meetings
            .filter { !$0.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.date <= now }
            .sorted { $0.date > $1.date }
            .prefix(5)
            .map { meeting in
                let firstAttendee = meeting.attendees.first.flatMap { attendeeId in
                    people.first { $0.id == attendeeId }
                }
                let preview = String(meeting.notes.prefix(150)).trimmingCharacters(in: .whitespacesAndNewlines)
                return WidgetQuickNoteData(
                    id: meeting.id,
                    personName: firstAttendee?.name ?? "Meeting",
                    personInitials: firstAttendee?.initials ?? "M",
                    personColor: firstAttendee?.avatarColor ?? "#3BDAFC",
                    meetingTitle: meeting.title,
                    meetingDate: meeting.date,
                    notePreview: preview
                )
            }

        // Mood history (last 10 meetings with mood set)
        let moodHistory: [WidgetMoodEntryData] = meetings
            .compactMap { meeting -> WidgetMoodEntryData? in
                guard let mood = meeting.mood else { return nil }
                return WidgetMoodEntryData(
                    date: meeting.date,
                    mood: mood.rawValue,
                    moodIcon: mood.icon,
                    moodColor: mood.color
                )
            }
            .sorted { $0.date > $1.date }
            .prefix(10)
            .map { $0 }

        return WidgetSharedData(
            upcomingMeetings: Array(upcomingMeetings),
            overdueActionItemsCount: overdueCount,
            peopleToMeetSoon: Array(peopleToMeetSoon),
            totalPeople: people.count,
            totalMeetingsThisWeek: meetingsThisWeek,
            lastUpdated: now,
            actionItems: widgetActionItems,
            todayMeetings: todayMeetings,
            streakPeople: streakPeople,
            recentNotes: recentNotes,
            moodHistory: moodHistory
        )
    }

    /// Writes the shared widget data to the app group container
    private func writeWidgetData(_ data: WidgetSharedData) {
        guard let fileURL = sharedDataFileURL else {
            print("WidgetSyncService: Could not get shared container URL")
            return
        }

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let jsonData = try encoder.encode(data)
            try jsonData.write(to: fileURL)
            print("WidgetSyncService: Successfully wrote widget data to \(fileURL.path)")

            // Reload widget timelines
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            print("WidgetSyncService: Error writing widget data: \(error)")
        }
    }

    /// Refreshes all widget timelines
    func refreshWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}

// MARK: - Widget Data Models (for main app)

struct WidgetSharedData: Codable {
    let upcomingMeetings: [WidgetMeetingData]
    let overdueActionItemsCount: Int
    let peopleToMeetSoon: [WidgetPersonData]
    let totalPeople: Int
    let totalMeetingsThisWeek: Int
    let lastUpdated: Date

    // New widget data
    let actionItems: [WidgetActionItemData]
    let todayMeetings: [WidgetMeetingData]
    let streakPeople: [WidgetStreakPersonData]
    let recentNotes: [WidgetQuickNoteData]
    let moodHistory: [WidgetMoodEntryData]
}

struct WidgetMeetingData: Codable {
    let id: UUID
    let title: String
    let personName: String
    let personInitials: String
    let personColor: String
    let date: Date
    let meetingType: String
}

struct WidgetPersonData: Codable {
    let id: UUID
    let name: String
    let initials: String
    let color: String
    let daysSinceLastMeeting: Int
    let meetingFrequency: String
}

struct WidgetActionItemData: Codable {
    let id: UUID
    let title: String
    let priority: String
    let priorityColor: String
    let dueDate: Date?
    let assigneeName: String?
    let isOverdue: Bool
    let meetingTitle: String
}

struct WidgetStreakPersonData: Codable {
    let id: UUID
    let name: String
    let initials: String
    let color: String
    let currentStreak: Int
    let frequency: String
    let isOnTrack: Bool
}

struct WidgetQuickNoteData: Codable {
    let id: UUID
    let personName: String
    let personInitials: String
    let personColor: String
    let meetingTitle: String
    let meetingDate: Date
    let notePreview: String
}

struct WidgetMoodEntryData: Codable {
    let date: Date
    let mood: String
    let moodIcon: String
    let moodColor: String
}
