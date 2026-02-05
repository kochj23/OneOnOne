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
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now

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
                    daysSinceLastMeeting = Calendar.current.dateComponents([.day], from: lastMeeting, to: now).day ?? 0
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

        return WidgetSharedData(
            upcomingMeetings: Array(upcomingMeetings),
            overdueActionItemsCount: overdueCount,
            peopleToMeetSoon: Array(peopleToMeetSoon),
            totalPeople: people.count,
            totalMeetingsThisWeek: meetingsThisWeek,
            lastUpdated: now
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
