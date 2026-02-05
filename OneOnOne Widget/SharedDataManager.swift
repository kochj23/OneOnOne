//
//  SharedDataManager.swift
//  OneOnOne Widget
//
//  Manages data sharing between the main app and widget via App Groups
//  Created by Jordan Koch on 2026-02-04.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation
import WidgetKit

/// Manages shared data between the main app and widget extension using App Groups
class SharedDataManager {
    static let shared = SharedDataManager()

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

    // MARK: - Read Data

    /// Reads the shared widget data from the app group container
    func readWidgetData() -> SharedWidgetData {
        guard let fileURL = sharedDataFileURL else {
            print("SharedDataManager: Could not get shared container URL")
            return .empty
        }

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("SharedDataManager: Widget data file does not exist")
            return .empty
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let widgetData = try decoder.decode(SharedWidgetData.self, from: data)
            print("SharedDataManager: Successfully read widget data with \(widgetData.upcomingMeetings.count) meetings")
            return widgetData
        } catch {
            print("SharedDataManager: Error reading widget data: \(error)")
            return .empty
        }
    }

    // MARK: - Write Data

    /// Writes the shared widget data to the app group container
    func writeWidgetData(_ data: SharedWidgetData) {
        guard let fileURL = sharedDataFileURL else {
            print("SharedDataManager: Could not get shared container URL")
            return
        }

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let jsonData = try encoder.encode(data)
            try jsonData.write(to: fileURL)
            print("SharedDataManager: Successfully wrote widget data")

            // Reload widget timelines
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            print("SharedDataManager: Error writing widget data: \(error)")
        }
    }

    // MARK: - Convenience Methods

    /// Creates widget data from app models
    func createWidgetData(
        people: [Person],
        meetings: [Meeting],
        actionItems: [ActionItem]
    ) -> SharedWidgetData {
        let now = Date()
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now

        // Get upcoming meetings (next 7 days)
        let upcomingMeetings = meetings
            .filter { $0.date > now }
            .sorted { $0.date < $1.date }
            .prefix(10)
            .map { meeting -> WidgetMeeting in
                let firstAttendee = meeting.attendees.first.flatMap { attendeeId in
                    people.first { $0.id == attendeeId }
                }
                return WidgetMeeting(
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
            .compactMap { person -> WidgetPerson? in
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

                return WidgetPerson(
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

        return SharedWidgetData(
            upcomingMeetings: Array(upcomingMeetings),
            overdueActionItemsCount: overdueCount,
            peopleToMeetSoon: Array(peopleToMeetSoon),
            totalPeople: people.count,
            totalMeetingsThisWeek: meetingsThisWeek,
            lastUpdated: now
        )
    }

    /// Refreshes widget data from the main app
    static func refreshWidgetData() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}

// MARK: - Person Model Extension (for widget data creation)

extension Person {
    /// Used by SharedDataManager for widget data creation
}

// MARK: - Meeting Model Extension (for widget data creation)

extension Meeting {
    /// Used by SharedDataManager for widget data creation
}

// MARK: - ActionItem Model Extension (for widget data creation)

extension ActionItem {
    /// Used by SharedDataManager for widget data creation
}
