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

    // New widget data
    let actionItems: [WidgetActionItem]
    let todayMeetings: [WidgetMeeting]
    let streakPeople: [WidgetStreakPerson]
    let recentNotes: [WidgetQuickNote]
    let moodHistory: [WidgetMoodEntry]

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
            configuration: ConfigurationAppIntent(),
            actionItems: [
                WidgetActionItem(id: UUID(), title: "Review Q1 goals", priority: "High", priorityColor: "#FF9933", dueDate: Date().addingTimeInterval(-86400), assigneeName: "Alex", isOverdue: true, meetingTitle: "Weekly 1:1"),
                WidgetActionItem(id: UUID(), title: "Send feedback doc", priority: "Medium", priorityColor: "#3BDAFC", dueDate: Date().addingTimeInterval(86400), assigneeName: "Sarah", isOverdue: false, meetingTitle: "Team Standup")
            ],
            todayMeetings: [
                WidgetMeeting(id: UUID(), title: "Weekly 1:1", personName: "Alex Johnson", personInitials: "AJ", personColor: "#3BDAFC", date: Date().addingTimeInterval(3600), meetingType: "1:1")
            ],
            streakPeople: [
                WidgetStreakPerson(id: UUID(), name: "Alex Johnson", initials: "AJ", color: "#3BDAFC", currentStreak: 8, frequency: "Weekly", isOnTrack: true)
            ],
            recentNotes: [
                WidgetQuickNote(id: UUID(), personName: "Alex Johnson", personInitials: "AJ", personColor: "#3BDAFC", meetingTitle: "Weekly 1:1", meetingDate: Date().addingTimeInterval(-86400), notePreview: "Discussed project timeline and upcoming milestones...")
            ],
            moodHistory: [
                WidgetMoodEntry(date: Date(), mood: "Productive", moodIcon: "bolt.fill", moodColor: "#4DE094"),
                WidgetMoodEntry(date: Date().addingTimeInterval(-604800), mood: "Positive", moodIcon: "face.smiling", moodColor: "#3BDAFC")
            ]
        )
    }

    static var empty: OneOnOneEntry {
        OneOnOneEntry(
            date: Date(),
            upcomingMeetings: [],
            overdueActionItemsCount: 0,
            peopleToMeetSoon: [],
            configuration: ConfigurationAppIntent(),
            actionItems: [],
            todayMeetings: [],
            streakPeople: [],
            recentNotes: [],
            moodHistory: []
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

// MARK: - Widget Action Item

struct WidgetActionItem: Codable, Identifiable {
    let id: UUID
    let title: String
    let priority: String
    let priorityColor: String
    let dueDate: Date?
    let assigneeName: String?
    let isOverdue: Bool
    let meetingTitle: String

    var dueDateString: String {
        guard let dueDate else { return "No due date" }
        if Calendar.current.isDateInToday(dueDate) { return "Today" }
        if Calendar.current.isDateInTomorrow(dueDate) { return "Tomorrow" }
        if Calendar.current.isDateInYesterday(dueDate) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: dueDate)
    }
}

// MARK: - Widget Streak Person

struct WidgetStreakPerson: Codable, Identifiable {
    let id: UUID
    let name: String
    let initials: String
    let color: String
    let currentStreak: Int // consecutive weeks
    let frequency: String
    let isOnTrack: Bool

    var streakText: String {
        if currentStreak == 1 {
            return "1 week"
        }
        return "\(currentStreak) weeks"
    }
}

// MARK: - Widget Quick Note

struct WidgetQuickNote: Codable, Identifiable {
    let id: UUID
    let personName: String
    let personInitials: String
    let personColor: String
    let meetingTitle: String
    let meetingDate: Date
    let notePreview: String

    var dateString: String {
        if Calendar.current.isDateInToday(meetingDate) { return "Today" }
        if Calendar.current.isDateInYesterday(meetingDate) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: meetingDate)
    }
}

// MARK: - Widget Mood Entry

struct WidgetMoodEntry: Codable, Identifiable {
    var id: Date { date }
    let date: Date
    let mood: String
    let moodIcon: String
    let moodColor: String

    var dayLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
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

    // New widget data
    let actionItems: [WidgetActionItem]
    let todayMeetings: [WidgetMeeting]
    let streakPeople: [WidgetStreakPerson]
    let recentNotes: [WidgetQuickNote]
    let moodHistory: [WidgetMoodEntry]

    static var empty: SharedWidgetData {
        SharedWidgetData(
            upcomingMeetings: [],
            overdueActionItemsCount: 0,
            peopleToMeetSoon: [],
            totalPeople: 0,
            totalMeetingsThisWeek: 0,
            lastUpdated: Date(),
            actionItems: [],
            todayMeetings: [],
            streakPeople: [],
            recentNotes: [],
            moodHistory: []
        )
    }

    // Backwards-compatible decoding for existing widget_data.json without new fields
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        upcomingMeetings = try container.decode([WidgetMeeting].self, forKey: .upcomingMeetings)
        overdueActionItemsCount = try container.decode(Int.self, forKey: .overdueActionItemsCount)
        peopleToMeetSoon = try container.decode([WidgetPerson].self, forKey: .peopleToMeetSoon)
        totalPeople = try container.decode(Int.self, forKey: .totalPeople)
        totalMeetingsThisWeek = try container.decode(Int.self, forKey: .totalMeetingsThisWeek)
        lastUpdated = try container.decode(Date.self, forKey: .lastUpdated)
        actionItems = (try? container.decode([WidgetActionItem].self, forKey: .actionItems)) ?? []
        todayMeetings = (try? container.decode([WidgetMeeting].self, forKey: .todayMeetings)) ?? []
        streakPeople = (try? container.decode([WidgetStreakPerson].self, forKey: .streakPeople)) ?? []
        recentNotes = (try? container.decode([WidgetQuickNote].self, forKey: .recentNotes)) ?? []
        moodHistory = (try? container.decode([WidgetMoodEntry].self, forKey: .moodHistory)) ?? []
    }

    init(upcomingMeetings: [WidgetMeeting], overdueActionItemsCount: Int, peopleToMeetSoon: [WidgetPerson], totalPeople: Int, totalMeetingsThisWeek: Int, lastUpdated: Date, actionItems: [WidgetActionItem], todayMeetings: [WidgetMeeting], streakPeople: [WidgetStreakPerson], recentNotes: [WidgetQuickNote], moodHistory: [WidgetMoodEntry]) {
        self.upcomingMeetings = upcomingMeetings
        self.overdueActionItemsCount = overdueActionItemsCount
        self.peopleToMeetSoon = peopleToMeetSoon
        self.totalPeople = totalPeople
        self.totalMeetingsThisWeek = totalMeetingsThisWeek
        self.lastUpdated = lastUpdated
        self.actionItems = actionItems
        self.todayMeetings = todayMeetings
        self.streakPeople = streakPeople
        self.recentNotes = recentNotes
        self.moodHistory = moodHistory
    }
}
