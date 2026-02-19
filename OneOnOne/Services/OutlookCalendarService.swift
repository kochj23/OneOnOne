//
//  OutlookCalendarService.swift
//  OneOnOne
//
//  Microsoft Outlook Calendar integration via Microsoft Graph API
//  Supports OAuth 2.0 authentication with PKCE flow
//
//  Created by Jordan Koch on 2026-02-09.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation
import SwiftUI
import AuthenticationServices
import CryptoKit

#if !os(tvOS)

// MARK: - Outlook Calendar Service

@MainActor
class OutlookCalendarService: NSObject, ObservableObject {
    static let shared = OutlookCalendarService()

    // MARK: - Published Properties

    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var userEmail: String?
    @Published var userName: String?
    @Published var calendars: [OutlookCalendar] = []
    @Published var selectedCalendarId: String?
    @Published var lastSyncDate: Date?
    @Published var lastError: String?
    @Published var isSyncing = false

    // MARK: - Configuration

    // Microsoft Azure AD App Registration settings
    // User needs to register an app at https://portal.azure.com
    @Published var clientId: String = ""
    @Published var tenantId: String = "common" // "common" for multi-tenant, or specific tenant ID

    private let redirectUri = "msauth.com.jordankoch.OneOnOne://auth"
    private let scopes = ["User.Read", "Calendars.ReadWrite", "Calendars.Read.Shared"]

    // MARK: - Private Properties

    private var accessToken: String?
    private var refreshToken: String?
    private var tokenExpiry: Date?
    private var codeVerifier: String?

    private let baseURL = "https://graph.microsoft.com/v1.0"
    private let authBaseURL = "https://login.microsoftonline.com"

    private let configFile: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("OneOnOne")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("outlook_config.json")
    }()

    // MARK: - Initialization

    private override init() {
        super.init()
        loadConfiguration()
    }

    // MARK: - Authentication

    /// Starts the OAuth 2.0 authentication flow with PKCE
    func authenticate() async throws {
        guard !clientId.isEmpty else {
            throw OutlookError.notConfigured
        }

        isLoading = true
        lastError = nil

        defer { isLoading = false }

        // Generate PKCE code verifier and challenge
        codeVerifier = generateCodeVerifier()
        let codeChallenge = generateCodeChallenge(from: codeVerifier!)

        // Build authorization URL
        var components = URLComponents(string: "\(authBaseURL)/\(tenantId)/oauth2/v2.0/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "scope", value: scopes.joined(separator: " ")),
            URLQueryItem(name: "response_mode", value: "query"),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "prompt", value: "select_account")
        ]

        guard let authURL = components.url else {
            throw OutlookError.invalidConfiguration
        }

        // Present authentication session
        let callbackURL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: "msauth.com.jordankoch.OneOnOne"
            ) { callbackURL, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let callbackURL = callbackURL {
                    continuation.resume(returning: callbackURL)
                } else {
                    continuation.resume(throwing: OutlookError.authenticationFailed)
                }
            }

            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false

            if !session.start() {
                continuation.resume(throwing: OutlookError.authenticationFailed)
            }
        }

        // Extract authorization code from callback
        guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            throw OutlookError.authenticationFailed
        }

        // Exchange code for tokens
        try await exchangeCodeForTokens(code: code)

        // Fetch user info
        try await fetchUserInfo()

        // Fetch calendars
        try await fetchCalendars()

        isAuthenticated = true
        saveConfiguration()
    }

    /// Exchanges authorization code for access and refresh tokens
    private func exchangeCodeForTokens(code: String) async throws {
        guard let codeVerifier = codeVerifier else {
            throw OutlookError.authenticationFailed
        }

        let url = URL(string: "\(authBaseURL)/\(tenantId)/oauth2/v2.0/token")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyParams = [
            "client_id": clientId,
            "scope": scopes.joined(separator: " "),
            "code": code,
            "redirect_uri": redirectUri,
            "grant_type": "authorization_code",
            "code_verifier": codeVerifier
        ]

        request.httpBody = bodyParams
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OutlookError.tokenExchangeFailed
        }

        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)

        accessToken = tokenResponse.accessToken
        refreshToken = tokenResponse.refreshToken
        tokenExpiry = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))
    }

    /// Refreshes the access token using the refresh token
    private func refreshAccessToken() async throws {
        guard let refreshToken = refreshToken else {
            throw OutlookError.notAuthenticated
        }

        let url = URL(string: "\(authBaseURL)/\(tenantId)/oauth2/v2.0/token")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyParams = [
            "client_id": clientId,
            "scope": scopes.joined(separator: " "),
            "refresh_token": refreshToken,
            "grant_type": "refresh_token"
        ]

        request.httpBody = bodyParams
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            // Refresh failed, need to re-authenticate
            isAuthenticated = false
            throw OutlookError.tokenRefreshFailed
        }

        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)

        accessToken = tokenResponse.accessToken
        self.refreshToken = tokenResponse.refreshToken ?? refreshToken
        tokenExpiry = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))

        saveConfiguration()
    }

    /// Ensures we have a valid access token
    private func ensureValidToken() async throws {
        guard isAuthenticated else {
            throw OutlookError.notAuthenticated
        }

        if let expiry = tokenExpiry, Date() >= expiry.addingTimeInterval(-60) {
            try await refreshAccessToken()
        }
    }

    /// Signs out and clears all tokens
    func signOut() {
        accessToken = nil
        refreshToken = nil
        tokenExpiry = nil
        isAuthenticated = false
        userEmail = nil
        userName = nil
        calendars = []
        selectedCalendarId = nil
        lastSyncDate = nil

        // Remove config file
        try? FileManager.default.removeItem(at: configFile)
    }

    // MARK: - User Info

    /// Fetches the authenticated user's information
    private func fetchUserInfo() async throws {
        try await ensureValidToken()

        guard let accessToken = accessToken else {
            throw OutlookError.notAuthenticated
        }

        let url = URL(string: "\(baseURL)/me")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)

        let user = try JSONDecoder().decode(GraphUser.self, from: data)

        userEmail = user.mail ?? user.userPrincipalName
        userName = user.displayName
    }

    // MARK: - Calendars

    /// Fetches all calendars for the user
    func fetchCalendars() async throws {
        try await ensureValidToken()

        guard let accessToken = accessToken else {
            throw OutlookError.notAuthenticated
        }

        let url = URL(string: "\(baseURL)/me/calendars")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)

        let response = try JSONDecoder().decode(CalendarsResponse.self, from: data)
        calendars = response.value

        // Select default calendar if none selected
        if selectedCalendarId == nil {
            selectedCalendarId = calendars.first(where: { $0.isDefaultCalendar })?.id ?? calendars.first?.id
        }

        saveConfiguration()
    }

    // MARK: - Events

    /// Fetches events from Outlook calendar
    func fetchEvents(from startDate: Date, to endDate: Date, calendarId: String? = nil) async throws -> [OutlookEvent] {
        try await ensureValidToken()

        guard let accessToken = accessToken else {
            throw OutlookError.notAuthenticated
        }

        let calId = calendarId ?? selectedCalendarId ?? "primary"

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        var components = URLComponents(string: "\(baseURL)/me/calendars/\(calId)/events")!
        components.queryItems = [
            URLQueryItem(name: "$filter", value: "start/dateTime ge '\(formatter.string(from: startDate))' and end/dateTime le '\(formatter.string(from: endDate))'"),
            URLQueryItem(name: "$orderby", value: "start/dateTime"),
            URLQueryItem(name: "$top", value: "100")
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OutlookError.fetchFailed
        }

        let eventsResponse = try JSONDecoder().decode(EventsResponse.self, from: data)
        return eventsResponse.value
    }

    /// Creates an event in Outlook calendar
    func createEvent(
        title: String,
        start: Date,
        end: Date,
        location: String? = nil,
        body: String? = nil,
        attendees: [String] = [],
        isOnlineMeeting: Bool = false,
        calendarId: String? = nil
    ) async throws -> OutlookEvent {
        try await ensureValidToken()

        guard let accessToken = accessToken else {
            throw OutlookError.notAuthenticated
        }

        let calId = calendarId ?? selectedCalendarId ?? "primary"
        let url = URL(string: "\(baseURL)/me/calendars/\(calId)/events")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        var eventBody: [String: Any] = [
            "subject": title,
            "start": [
                "dateTime": formatter.string(from: start),
                "timeZone": TimeZone.current.identifier
            ],
            "end": [
                "dateTime": formatter.string(from: end),
                "timeZone": TimeZone.current.identifier
            ],
            "isOnlineMeeting": isOnlineMeeting
        ]

        if let location = location {
            eventBody["location"] = ["displayName": location]
        }

        if let body = body {
            eventBody["body"] = [
                "contentType": "text",
                "content": body
            ]
        }

        if !attendees.isEmpty {
            eventBody["attendees"] = attendees.map { email in
                [
                    "emailAddress": ["address": email],
                    "type": "required"
                ]
            }
        }

        if isOnlineMeeting {
            eventBody["onlineMeetingProvider"] = "teamsForBusiness"
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: eventBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 201 else {
            throw OutlookError.createFailed
        }

        return try JSONDecoder().decode(OutlookEvent.self, from: data)
    }

    /// Updates an existing event in Outlook calendar
    func updateEvent(
        eventId: String,
        title: String? = nil,
        start: Date? = nil,
        end: Date? = nil,
        location: String? = nil,
        body: String? = nil,
        calendarId: String? = nil
    ) async throws {
        try await ensureValidToken()

        guard let accessToken = accessToken else {
            throw OutlookError.notAuthenticated
        }

        let calId = calendarId ?? selectedCalendarId ?? "primary"
        let url = URL(string: "\(baseURL)/me/calendars/\(calId)/events/\(eventId)")!

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        var eventBody: [String: Any] = [:]

        if let title = title {
            eventBody["subject"] = title
        }

        if let start = start {
            eventBody["start"] = [
                "dateTime": formatter.string(from: start),
                "timeZone": TimeZone.current.identifier
            ]
        }

        if let end = end {
            eventBody["end"] = [
                "dateTime": formatter.string(from: end),
                "timeZone": TimeZone.current.identifier
            ]
        }

        if let location = location {
            eventBody["location"] = ["displayName": location]
        }

        if let body = body {
            eventBody["body"] = [
                "contentType": "text",
                "content": body
            ]
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: eventBody)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OutlookError.updateFailed
        }
    }

    /// Deletes an event from Outlook calendar
    func deleteEvent(eventId: String, calendarId: String? = nil) async throws {
        try await ensureValidToken()

        guard let accessToken = accessToken else {
            throw OutlookError.notAuthenticated
        }

        let calId = calendarId ?? selectedCalendarId ?? "primary"
        let url = URL(string: "\(baseURL)/me/calendars/\(calId)/events/\(eventId)")!

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 204 else {
            throw OutlookError.deleteFailed
        }
    }

    // MARK: - Sync with OneOnOne Meetings

    /// Syncs Outlook calendar events with OneOnOne meetings
    func syncWithMeetings() async throws {
        isSyncing = true
        lastError = nil

        defer {
            isSyncing = false
            lastSyncDate = Date()
            saveConfiguration()
        }

        // Fetch upcoming events from Outlook
        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: 30, to: startDate)!

        let outlookEvents = try await fetchEvents(from: startDate, to: endDate)

        // Get existing meetings from DataStore
        let existingMeetings = DataStore.shared.meetings

        // Find meetings that need to be created in Outlook
        for meeting in existingMeetings {
            // Check if meeting has an Outlook event ID
            if meeting.outlookEventId == nil && meeting.date > Date() {
                // Create event in Outlook
                let attendeeEmails = meeting.attendees.compactMap { personId -> String? in
                    DataStore.shared.person(for: personId)?.email
                }

                let event = try await createEvent(
                    title: meeting.title,
                    start: meeting.date,
                    end: meeting.date.addingTimeInterval(meeting.duration),
                    location: meeting.location,
                    body: meeting.agenda,
                    attendees: attendeeEmails
                )

                // Update meeting with Outlook event ID
                var updatedMeeting = meeting
                updatedMeeting.outlookEventId = event.id
                DataStore.shared.updateMeeting(updatedMeeting)
            }
        }

        // Import new events from Outlook that aren't in OneOnOne
        for event in outlookEvents {
            let existingMeeting = existingMeetings.first { $0.outlookEventId == event.id }

            if existingMeeting == nil {
                // Determine meeting type from attendee count and title
                let attendeeCount = event.attendees?.count ?? 0
                let meetingType = Self.inferMeetingType(subject: event.subject, attendeeCount: attendeeCount)

                // Match attendees to existing People by email
                let matchedAttendees: [UUID] = (event.attendees ?? []).compactMap { attendee in
                    let email = attendee.emailAddress.address
                    guard !email.isEmpty else { return nil }
                    return DataStore.shared.people.first { $0.email?.lowercased() == email.lowercased() }?.id
                }

                let newMeeting = Meeting(
                    id: UUID(),
                    title: event.subject,
                    date: event.startDate,
                    duration: event.endDate.timeIntervalSince(event.startDate),
                    attendees: matchedAttendees,
                    meetingType: meetingType,
                    location: event.location?.displayName,
                    calendarEventId: nil,
                    outlookEventId: event.id,
                    agenda: event.bodyPreview,
                    notes: ""
                )

                DataStore.shared.addMeeting(newMeeting)
            }
        }
    }

    /// Creates an Outlook event for a OneOnOne meeting
    func createEventForMeeting(_ meeting: Meeting) async throws -> String {
        let attendeeEmails = meeting.attendees.compactMap { personId -> String? in
            DataStore.shared.person(for: personId)?.email
        }

        let event = try await createEvent(
            title: meeting.title,
            start: meeting.date,
            end: meeting.date.addingTimeInterval(meeting.duration),
            location: meeting.location,
            body: meeting.agenda,
            attendees: attendeeEmails,
            isOnlineMeeting: true
        )

        return event.id
    }

    // MARK: - Meeting Type Inference

    /// Infers meeting type from subject keywords and attendee count
    static func inferMeetingType(subject: String, attendeeCount: Int) -> MeetingType {
        let lower = subject.lowercased()

        if lower.contains("stand-up") || lower.contains("standup") || lower.contains("daily scrum") {
            return .standUp
        }
        if lower.contains("retro") {
            return .retrospective
        }
        if lower.contains("planning") || lower.contains("sprint plan") {
            return .planning
        }
        if lower.contains("review") || lower.contains("demo") {
            return .review
        }
        if lower.contains("brainstorm") || lower.contains("ideation") {
            return .brainstorm
        }
        if lower.contains("interview") {
            return .interview
        }
        if lower.contains("training") || lower.contains("workshop") || lower.contains("learning") {
            return .training
        }
        if lower.contains("1:1") || lower.contains("one on one") || lower.contains("1-on-1") || lower.contains("one-on-one") {
            return .oneOnOne
        }

        if attendeeCount <= 2 {
            return .oneOnOne
        }

        return .teamMeeting
    }

    // MARK: - PKCE Helpers

    private func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func generateCodeChallenge(from verifier: String) -> String {
        let data = Data(verifier.utf8)
        let hash = SHA256.hash(data: data)
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    // MARK: - Configuration Persistence

    func saveConfiguration() {
        let config = OutlookConfig(
            clientId: clientId,
            tenantId: tenantId,
            accessToken: accessToken,
            refreshToken: refreshToken,
            tokenExpiry: tokenExpiry,
            userEmail: userEmail,
            userName: userName,
            selectedCalendarId: selectedCalendarId,
            lastSyncDate: lastSyncDate,
            isAuthenticated: isAuthenticated
        )

        if let data = try? JSONEncoder().encode(config) {
            try? data.write(to: configFile)
        }
    }

    private func loadConfiguration() {
        guard let data = try? Data(contentsOf: configFile),
              let config = try? JSONDecoder().decode(OutlookConfig.self, from: data) else {
            return
        }

        clientId = config.clientId
        tenantId = config.tenantId
        accessToken = config.accessToken
        refreshToken = config.refreshToken
        tokenExpiry = config.tokenExpiry
        userEmail = config.userEmail
        userName = config.userName
        selectedCalendarId = config.selectedCalendarId
        lastSyncDate = config.lastSyncDate
        isAuthenticated = config.isAuthenticated

        // Refresh token if needed
        if isAuthenticated {
            Task {
                do {
                    try await ensureValidToken()
                    try await fetchCalendars()
                } catch {
                    print("Failed to refresh Outlook token: \(error)")
                    isAuthenticated = false
                }
            }
        }
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension OutlookCalendarService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        #if os(macOS)
        return NSApp.keyWindow ?? NSApp.windows.first!
        #else
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }!
        #endif
    }
}

// MARK: - Models

struct OutlookConfig: Codable {
    var clientId: String
    var tenantId: String
    var accessToken: String?
    var refreshToken: String?
    var tokenExpiry: Date?
    var userEmail: String?
    var userName: String?
    var selectedCalendarId: String?
    var lastSyncDate: Date?
    var isAuthenticated: Bool
}

struct TokenResponse: Codable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int
    let tokenType: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
    }
}

struct GraphUser: Codable {
    let id: String
    let displayName: String
    let mail: String?
    let userPrincipalName: String
}

struct OutlookCalendar: Codable, Identifiable {
    let id: String
    let name: String
    let color: String?
    let isDefaultCalendar: Bool
    let canEdit: Bool
    let owner: CalendarOwner?

    struct CalendarOwner: Codable {
        let name: String?
        let address: String?
    }
}

struct CalendarsResponse: Codable {
    let value: [OutlookCalendar]
}

struct OutlookEvent: Codable, Identifiable {
    let id: String
    let subject: String
    let bodyPreview: String?
    let start: EventDateTime
    let end: EventDateTime
    let location: EventLocation?
    let attendees: [EventAttendee]?
    let isOnlineMeeting: Bool?
    let onlineMeetingUrl: String?
    let webLink: String?

    var startDate: Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: start.dateTime) ?? Date()
    }

    var endDate: Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: end.dateTime) ?? Date()
    }

    struct EventDateTime: Codable {
        let dateTime: String
        let timeZone: String
    }

    struct EventLocation: Codable {
        let displayName: String?
    }

    struct EventAttendee: Codable {
        let emailAddress: EmailAddress
        let type: String?
        let status: AttendeeStatus?

        struct EmailAddress: Codable {
            let name: String?
            let address: String
        }

        struct AttendeeStatus: Codable {
            let response: String?
        }
    }
}

struct EventsResponse: Codable {
    let value: [OutlookEvent]
}

// MARK: - Errors

enum OutlookError: LocalizedError {
    case notConfigured
    case invalidConfiguration
    case notAuthenticated
    case authenticationFailed
    case tokenExchangeFailed
    case tokenRefreshFailed
    case fetchFailed
    case createFailed
    case updateFailed
    case deleteFailed
    case syncFailed

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Outlook integration not configured. Please enter your Azure AD Client ID."
        case .invalidConfiguration:
            return "Invalid Outlook configuration"
        case .notAuthenticated:
            return "Not authenticated with Outlook. Please sign in."
        case .authenticationFailed:
            return "Outlook authentication failed. Please try again."
        case .tokenExchangeFailed:
            return "Failed to exchange authorization code for tokens"
        case .tokenRefreshFailed:
            return "Failed to refresh access token. Please sign in again."
        case .fetchFailed:
            return "Failed to fetch calendar data from Outlook"
        case .createFailed:
            return "Failed to create calendar event in Outlook"
        case .updateFailed:
            return "Failed to update calendar event in Outlook"
        case .deleteFailed:
            return "Failed to delete calendar event from Outlook"
        case .syncFailed:
            return "Calendar sync with Outlook failed"
        }
    }
}

#endif  // !os(tvOS)
