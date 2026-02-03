//
//  TeamInsightsService.swift
//  OneOnOne
//
//  Team-level analytics and insights
//  Created by Jordan Koch on 2026-02-02.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation

@MainActor
class TeamInsightsService: ObservableObject {
    static let shared = TeamInsightsService()

    @Published var insights: TeamInsights?
    @Published var isLoading = false

    private init() {}

    // MARK: - Generate Insights

    func generateInsights() async {
        isLoading = true
        defer { isLoading = false }

        let dataStore = DataStore.shared
        let now = Date()
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        let monthAgo = Calendar.current.date(byAdding: .month, value: -1, to: now) ?? now

        // Meeting frequency by person
        var meetingFrequencyByPerson: [UUID: Int] = [:]
        for person in dataStore.people {
            let count = dataStore.meetings(for: person.id).filter { $0.date >= monthAgo }.count
            meetingFrequencyByPerson[person.id] = count
        }

        // People due for meetings
        let peopleDueForMeeting = dataStore.people.filter { person in
            guard let lastMeeting = person.lastMeetingDate,
                  let days = person.meetingFrequency.calendarDays else {
                return person.lastMeetingDate == nil
            }
            let nextDue = Calendar.current.date(byAdding: .day, value: days, to: lastMeeting)!
            return nextDue < now
        }

        // People never met
        let peopleNeverMet = dataStore.people.filter { $0.lastMeetingDate == nil }

        // Meeting distribution by type
        var meetingsByType: [MeetingType: Int] = [:]
        for meeting in dataStore.meetings.filter({ $0.date >= monthAgo }) {
            meetingsByType[meeting.meetingType, default: 0] += 1
        }

        // Action item stats
        let allActionItems = dataStore.allActionItems()
        let openItems = allActionItems.filter { !$0.isCompleted }
        let overdueItems = openItems.filter { $0.isOverdue }
        let completedThisWeek = allActionItems.filter {
            $0.isCompleted && ($0.completedDate ?? Date.distantPast) >= weekAgo
        }

        // Completion rate by person
        var completionRateByPerson: [UUID: Double] = [:]
        for person in dataStore.people {
            let personItems = allActionItems.filter { $0.assigneeId == person.id }
            guard !personItems.isEmpty else { continue }
            let completed = personItems.filter { $0.isCompleted }.count
            completionRateByPerson[person.id] = Double(completed) / Double(personItems.count)
        }

        // Meeting trends (weekly counts for last 4 weeks)
        var weeklyMeetingCounts: [Int] = []
        for weekOffset in 0..<4 {
            let weekStart = Calendar.current.date(byAdding: .day, value: -7 * (weekOffset + 1), to: now)!
            let weekEnd = Calendar.current.date(byAdding: .day, value: -7 * weekOffset, to: now)!
            let count = dataStore.meetings.filter { $0.date >= weekStart && $0.date < weekEnd }.count
            weeklyMeetingCounts.append(count)
        }

        // Top contributors (most feedback given)
        // This would require feedback data

        // Busiest days
        var meetingsByDayOfWeek: [Int: Int] = [:]
        for meeting in dataStore.meetings.filter({ $0.date >= monthAgo }) {
            let day = Calendar.current.component(.weekday, from: meeting.date)
            meetingsByDayOfWeek[day, default: 0] += 1
        }

        insights = TeamInsights(
            totalPeople: dataStore.people.count,
            totalMeetingsThisMonth: dataStore.meetings.filter { $0.date >= monthAgo }.count,
            totalMeetingsThisWeek: dataStore.meetings.filter { $0.date >= weekAgo }.count,
            meetingFrequencyByPerson: meetingFrequencyByPerson,
            peopleDueForMeeting: peopleDueForMeeting.map { $0.id },
            peopleNeverMet: peopleNeverMet.map { $0.id },
            meetingsByType: meetingsByType,
            openActionItems: openItems.count,
            overdueActionItems: overdueItems.count,
            completedThisWeek: completedThisWeek.count,
            completionRateByPerson: completionRateByPerson,
            weeklyMeetingCounts: weeklyMeetingCounts.reversed(),
            meetingsByDayOfWeek: meetingsByDayOfWeek,
            generatedAt: now
        )
    }

    // MARK: - Specific Queries

    func getMostActivePeople(limit: Int = 5) -> [(person: Person, meetingCount: Int)] {
        guard let insights = insights else { return [] }
        let dataStore = DataStore.shared

        return insights.meetingFrequencyByPerson
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .compactMap { personId, count in
                guard let person = dataStore.person(for: personId) else { return nil }
                return (person: person, meetingCount: count)
            }
    }

    func getLeastActivePeople(limit: Int = 5) -> [(person: Person, daysSinceLastMeeting: Int)] {
        let dataStore = DataStore.shared
        let now = Date()

        return dataStore.people
            .compactMap { person -> (person: Person, days: Int)? in
                guard let lastMeeting = person.lastMeetingDate else {
                    return (person: person, days: Int.max)
                }
                let days = Calendar.current.dateComponents([.day], from: lastMeeting, to: now).day ?? 0
                return (person: person, days: days)
            }
            .sorted { $0.days > $1.days }
            .prefix(limit)
            .map { (person: $0.person, daysSinceLastMeeting: $0.days == Int.max ? -1 : $0.days) }
    }

    func getTopPerformers(limit: Int = 5) -> [(person: Person, completionRate: Double)] {
        guard let insights = insights else { return [] }
        let dataStore = DataStore.shared

        return insights.completionRateByPerson
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .compactMap { personId, rate in
                guard let person = dataStore.person(for: personId) else { return nil }
                return (person: person, completionRate: rate)
            }
    }

    func getBusiestDay() -> (dayName: String, count: Int)? {
        guard let insights = insights,
              let (day, count) = insights.meetingsByDayOfWeek.max(by: { $0.value < $1.value }) else {
            return nil
        }

        let dayNames = ["", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        return (dayName: dayNames[day], count: count)
    }
}

// MARK: - Team Insights Model

struct TeamInsights {
    let totalPeople: Int
    let totalMeetingsThisMonth: Int
    let totalMeetingsThisWeek: Int
    let meetingFrequencyByPerson: [UUID: Int]
    let peopleDueForMeeting: [UUID]
    let peopleNeverMet: [UUID]
    let meetingsByType: [MeetingType: Int]
    let openActionItems: Int
    let overdueActionItems: Int
    let completedThisWeek: Int
    let completionRateByPerson: [UUID: Double]
    let weeklyMeetingCounts: [Int] // Last 4 weeks
    let meetingsByDayOfWeek: [Int: Int]
    let generatedAt: Date

    var averageMeetingsPerWeek: Double {
        guard !weeklyMeetingCounts.isEmpty else { return 0 }
        return Double(weeklyMeetingCounts.reduce(0, +)) / Double(weeklyMeetingCounts.count)
    }

    var meetingTrend: String {
        guard weeklyMeetingCounts.count >= 2 else { return "stable" }
        let recent = weeklyMeetingCounts.last ?? 0
        let previous = weeklyMeetingCounts[weeklyMeetingCounts.count - 2]
        if recent > previous { return "increasing" }
        if recent < previous { return "decreasing" }
        return "stable"
    }

    var teamCompletionRate: Double {
        guard !completionRateByPerson.isEmpty else { return 0 }
        return completionRateByPerson.values.reduce(0, +) / Double(completionRateByPerson.count)
    }
}
