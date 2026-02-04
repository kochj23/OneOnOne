//
//  CalendarService.swift
//  OneOnOne
//
//  Calendar integration for meeting scheduling and reminders
//  Created by Jordan Koch on 2026-02-02.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation

#if !os(tvOS)
import EventKit

@MainActor
class CalendarService: ObservableObject {
    static let shared = CalendarService()

    @Published var isAuthorized = false
    @Published var calendars: [EKCalendar] = []
    @Published var selectedCalendarId: String?

    private let eventStore = EKEventStore()

    private init() {
        checkAuthorization()
    }

    // MARK: - Authorization

    func checkAuthorization() {
        let status = EKEventStore.authorizationStatus(for: .event)
        isAuthorized = (status == .fullAccess || status == .authorized)

        if isAuthorized {
            loadCalendars()
        }
    }

    func requestAccess() async -> Bool {
        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            await MainActor.run {
                isAuthorized = granted
                if granted {
                    loadCalendars()
                }
            }
            return granted
        } catch {
            print("Calendar access error: \(error)")
            return false
        }
    }

    private func loadCalendars() {
        calendars = eventStore.calendars(for: .event)
            .filter { $0.allowsContentModifications }

        // Default to first writable calendar
        if selectedCalendarId == nil, let first = calendars.first {
            selectedCalendarId = first.calendarIdentifier
        }
    }

    // MARK: - Event Management

    /// Creates a calendar event for a meeting
    func createEvent(for meeting: Meeting, with attendees: [Person]) async throws -> String {
        guard isAuthorized else {
            throw CalendarError.notAuthorized
        }

        guard let calendarId = selectedCalendarId,
              let calendar = calendars.first(where: { $0.calendarIdentifier == calendarId }) else {
            throw CalendarError.noCalendarSelected
        }

        let event = EKEvent(eventStore: eventStore)
        event.title = meeting.title
        event.startDate = meeting.date
        event.endDate = meeting.date.addingTimeInterval(meeting.duration)
        event.calendar = calendar

        if let location = meeting.location {
            event.location = location
        }

        if let agenda = meeting.agenda {
            event.notes = agenda
        }

        // Add attendees
        for person in attendees {
            if let email = person.email {
                // Note: Creating EKParticipant programmatically is limited
                // This is a workaround - actual attendee invites require Exchange/CalDAV
                event.notes = (event.notes ?? "") + "\nAttendee: \(person.name) <\(email)>"
            }
        }

        // Add reminder
        let alarm = EKAlarm(relativeOffset: -900) // 15 minutes before
        event.addAlarm(alarm)

        try eventStore.save(event, span: .thisEvent)

        return event.eventIdentifier
    }

    /// Updates an existing calendar event
    func updateEvent(eventId: String, meeting: Meeting) async throws {
        guard isAuthorized else {
            throw CalendarError.notAuthorized
        }

        guard let event = eventStore.event(withIdentifier: eventId) else {
            throw CalendarError.eventNotFound
        }

        event.title = meeting.title
        event.startDate = meeting.date
        event.endDate = meeting.date.addingTimeInterval(meeting.duration)
        event.location = meeting.location
        event.notes = meeting.agenda

        try eventStore.save(event, span: .thisEvent)
    }

    /// Deletes a calendar event
    func deleteEvent(eventId: String) async throws {
        guard isAuthorized else {
            throw CalendarError.notAuthorized
        }

        guard let event = eventStore.event(withIdentifier: eventId) else {
            return // Already deleted
        }

        try eventStore.remove(event, span: .thisEvent)
    }

    /// Fetches upcoming events from the calendar
    func fetchUpcomingEvents(days: Int = 7) -> [EKEvent] {
        guard isAuthorized else { return [] }

        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: days, to: startDate) ?? startDate

        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: calendars
        )

        return eventStore.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
    }

    /// Finds potential meeting slots
    func findAvailableSlots(duration: TimeInterval, inNextDays days: Int = 7) -> [DateInterval] {
        guard isAuthorized else { return [] }

        var availableSlots: [DateInterval] = []
        let calendar = Calendar.current

        let startDate = Date()
        let endDate = calendar.date(byAdding: .day, value: days, to: startDate) ?? startDate

        let events = fetchUpcomingEvents(days: days)

        // Find gaps between events (simplified algorithm)
        var currentDate = startDate

        for event in events {
            // Check if there's a gap before this event
            let gap = event.startDate.timeIntervalSince(currentDate)
            if gap >= duration {
                // Add work hours only (9 AM - 5 PM)
                let proposedStart = currentDate
                let proposedEnd = currentDate.addingTimeInterval(duration)

                let startHour = calendar.component(.hour, from: proposedStart)
                let endHour = calendar.component(.hour, from: proposedEnd)

                if startHour >= 9 && endHour <= 17 {
                    availableSlots.append(DateInterval(start: proposedStart, end: proposedEnd))
                }
            }

            currentDate = max(currentDate, event.endDate)
        }

        return Array(availableSlots.prefix(5))
    }

    /// Schedules a recurring meeting
    func createRecurringEvent(
        meeting: Meeting,
        attendees: [Person],
        frequency: MeetingFrequency
    ) async throws -> String {
        guard isAuthorized else {
            throw CalendarError.notAuthorized
        }

        guard let calendarId = selectedCalendarId,
              let calendar = calendars.first(where: { $0.calendarIdentifier == calendarId }) else {
            throw CalendarError.noCalendarSelected
        }

        let event = EKEvent(eventStore: eventStore)
        event.title = meeting.title
        event.startDate = meeting.date
        event.endDate = meeting.date.addingTimeInterval(meeting.duration)
        event.calendar = calendar
        event.location = meeting.location
        event.notes = meeting.agenda

        // Set recurrence rule
        var recurrenceRule: EKRecurrenceRule?
        switch frequency {
        case .daily:
            recurrenceRule = EKRecurrenceRule(
                recurrenceWith: .daily,
                interval: 1,
                end: nil
            )
        case .weekly:
            recurrenceRule = EKRecurrenceRule(
                recurrenceWith: .weekly,
                interval: 1,
                end: nil
            )
        case .biweekly:
            recurrenceRule = EKRecurrenceRule(
                recurrenceWith: .weekly,
                interval: 2,
                end: nil
            )
        case .monthly:
            recurrenceRule = EKRecurrenceRule(
                recurrenceWith: .monthly,
                interval: 1,
                end: nil
            )
        case .quarterly:
            recurrenceRule = EKRecurrenceRule(
                recurrenceWith: .monthly,
                interval: 3,
                end: nil
            )
        case .asNeeded:
            break
        }

        if let rule = recurrenceRule {
            event.addRecurrenceRule(rule)
        }

        // Add reminder
        let alarm = EKAlarm(relativeOffset: -900)
        event.addAlarm(alarm)

        try eventStore.save(event, span: .futureEvents)

        return event.eventIdentifier
    }
}

// MARK: - Errors

enum CalendarError: LocalizedError {
    case notAuthorized
    case noCalendarSelected
    case eventNotFound
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Calendar access not authorized"
        case .noCalendarSelected:
            return "No calendar selected"
        case .eventNotFound:
            return "Calendar event not found"
        case .saveFailed:
            return "Failed to save calendar event"
        }
    }
}
#endif  // !os(tvOS)
