//
//  WidgetData.swift
//  OneOnOne Widget
//
//  Widget data models for sharing between app and widget
//  Created by Jordan Koch on 2026-02-04.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation
import WidgetKit

// MARK: - Widget Entry

struct OneOnOneEntry: TimelineEntry {
    let date: Date
    let upcomingMeetings: [WidgetMeeting]
    let overdueActionItemsCount: Int
    let peopleToMeetSoon: [WidgetPerson]
    let configuration: ConfigurationAppIntent

    static var placeholder: OneOnOneEntry {
        OneOnOneEntry(
            date: Date(),
            upcomingMeetings: [
                WidgetMeeting(
                    id: UUID(),
                    title: "Weekly 1:1",
                    personName: "Alex Johnson",
                    personInitials: "AJ",
                    personColor: "#3BDAFC",
                    date: Date().addingTimeInterval(3600),
                    meetingType: "1:1"
                ),
                WidgetMeeting(
                    id: UUID(),
                    title: "Team Standup",
                    personName: "Team",
                    personInitials: "TS",
                    personColor: "#9966FF",
                    date: Date().addingTimeInterval(7200),
                    meetingType: "Stand-up"
                )
            ],
            overdueActionItemsCount: 3,
            peopleToMeetSoon: [
                WidgetPerson(
                    id: UUID(),
                    name: "Sarah Miller",
                    initials: "SM",
                    color: "#FF5999",
                    daysSinceLastMeeting: 7,
                    meetingFrequency: "Weekly"
                )
            ],
            configuration: ConfigurationAppIntent()
        )
    }

    static var empty: OneOnOneEntry {
        OneOnOneEntry(
            date: Date(),
            upcomingMeetings: [],
            overdueActionItemsCount: 0,
            peopleToMeetSoon: [],
            configuration: ConfigurationAppIntent()
        )
    }
}

// MARK: - Widget Meeting

struct WidgetMeeting: Codable, Identifiable {
    let id: UUID
    let title: String
    let personName: String
    let personInitials: String
    let personColor: String
    let date: Date
    let meetingType: String

    var relativeTimeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    var isTomorrow: Bool {
        Calendar.current.isDateInTomorrow(date)
    }

    var dayString: String {
        if isToday { return "Today" }
        if isTomorrow { return "Tomorrow" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
}

// MARK: - Widget Person

struct WidgetPerson: Codable, Identifiable {
    let id: UUID
    let name: String
    let initials: String
    let color: String
    let daysSinceLastMeeting: Int
    let meetingFrequency: String

    var overdueText: String {
        if daysSinceLastMeeting == 1 {
            return "1 day overdue"
        }
        return "\(daysSinceLastMeeting) days overdue"
    }
}

// MARK: - Shared Widget Data

struct SharedWidgetData: Codable {
    let upcomingMeetings: [WidgetMeeting]
    let overdueActionItemsCount: Int
    let peopleToMeetSoon: [WidgetPerson]
    let totalPeople: Int
    let totalMeetingsThisWeek: Int
    let lastUpdated: Date

    static var empty: SharedWidgetData {
        SharedWidgetData(
            upcomingMeetings: [],
            overdueActionItemsCount: 0,
            peopleToMeetSoon: [],
            totalPeople: 0,
            totalMeetingsThisWeek: 0,
            lastUpdated: Date()
        )
    }
}
