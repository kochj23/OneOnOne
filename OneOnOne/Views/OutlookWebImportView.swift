//
//  OutlookWebImportView.swift
//  OneOnOne
//
//  WebView-based Outlook calendar import - sign in via browser and import meetings
//  No Azure AD app registration required
//
//  Created by Jordan Koch on 2026-02-19.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI
import WebKit

#if os(macOS)

// MARK: - Outlook Web Import View

struct OutlookWebImportView: View {
    @Environment(\.dismiss) var dismiss

    @State private var isAuthenticated = false
    @State private var isImporting = false
    @State private var importResult: OutlookWebImportResult?
    @State private var errorMessage: String?
    @State private var currentURL: String = ""
    @State private var webViewCoordinator: OutlookWebViewCoordinator?

    var body: some View {
        ZStack {
            ModernColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(24)

                Divider()
                    .background(ModernColors.glassBorder)

                if let result = importResult {
                    importResultView(result)
                } else {
                    // WebView
                    OutlookWebViewRepresentable(
                        isAuthenticated: $isAuthenticated,
                        isImporting: $isImporting,
                        importResult: $importResult,
                        errorMessage: $errorMessage,
                        currentURL: $currentURL,
                        coordinator: $webViewCoordinator
                    )

                    if let error = errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(ModernColors.red)
                            Text(error)
                                .font(.system(size: 13))
                                .foregroundColor(ModernColors.red)
                                .lineLimit(2)
                            Spacer()
                            Button("Dismiss") {
                                errorMessage = nil
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(ModernColors.textSecondary)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(ModernColors.red.opacity(0.1))
                    }

                    bottomBar
                }
            }
        }
        .frame(width: 900, height: 700)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    Image(systemName: "globe")
                        .font(.system(size: 28))
                        .foregroundColor(Color(hex: "#0078D4"))

                    Text("Import from Outlook Web")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(ModernColors.textPrimary)
                }

                Text("Sign in to your Outlook account and import your calendar meetings")
                    .font(.system(size: 14))
                    .foregroundColor(ModernColors.textSecondary)
            }

            Spacer()

            Button("Cancel") {
                dismiss()
            }
            .buttonStyle(.plain)
            .foregroundColor(ModernColors.textSecondary)
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack {
            HStack(spacing: 8) {
                Circle()
                    .fill(isAuthenticated ? ModernColors.accentGreen : ModernColors.textTertiary)
                    .frame(width: 8, height: 8)

                Text(isAuthenticated ? "Signed in - Ready to import" : "Sign in to your Outlook account above")
                    .font(.system(size: 13))
                    .foregroundColor(isAuthenticated ? ModernColors.accentGreen : ModernColors.textTertiary)
            }

            Spacer()

            Button {
                startImport()
            } label: {
                HStack(spacing: 8) {
                    if isImporting {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: "square.and.arrow.down")
                    }
                    Text(isImporting ? "Importing..." : "Import Meetings")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(isAuthenticated && !isImporting ? Color(hex: "#0078D4") : Color.gray.opacity(0.3))
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .disabled(!isAuthenticated || isImporting)
        }
        .padding(24)
        .background(Color.black.opacity(0.2))
    }

    // MARK: - Import Result View

    private func importResultView(_ result: OutlookWebImportResult) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Summary
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(ModernColors.accentGreen)

                    Text("Import Complete")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(ModernColors.textPrimary)

                    HStack(spacing: 32) {
                        statItem(value: "\(result.importedCount)", label: "Imported", color: ModernColors.accentGreen)
                        statItem(value: "\(result.skippedCount)", label: "Already Existed", color: ModernColors.cyan)
                        if result.failedCount > 0 {
                            statItem(value: "\(result.failedCount)", label: "Failed", color: ModernColors.red)
                        }
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .glassCard()

                // Imported meetings list
                if !result.importedMeetings.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Imported Meetings")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(ModernColors.textPrimary)

                        ForEach(result.importedMeetings.prefix(20)) { meeting in
                            HStack(spacing: 12) {
                                Image(systemName: meeting.meetingType.icon)
                                    .foregroundColor(ModernColors.cyan)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(meeting.title)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(ModernColors.textPrimary)

                                    Text(meeting.date.formatted(date: .abbreviated, time: .shortened))
                                        .font(.system(size: 12))
                                        .foregroundColor(ModernColors.textTertiary)
                                }

                                Spacer()

                                Text(meeting.meetingType.rawValue)
                                    .font(.system(size: 11))
                                    .foregroundColor(ModernColors.textTertiary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(ModernColors.glassBorder)
                                    .cornerRadius(6)
                            }
                            .padding(.vertical, 4)
                        }

                        if result.importedMeetings.count > 20 {
                            Text("...and \(result.importedMeetings.count - 20) more")
                                .font(.system(size: 13))
                                .foregroundColor(ModernColors.textTertiary)
                        }
                    }
                    .padding(16)
                    .glassCard()
                }

                // Done button
                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .frame(maxWidth: .infinity)
                        .primaryButton()
                }
                .buttonStyle(.plain)
            }
            .padding(24)
        }
    }

    private func statItem(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(ModernColors.textSecondary)
        }
    }

    // MARK: - Actions

    private func startImport() {
        isImporting = true
        errorMessage = nil
        webViewCoordinator?.fetchCalendarEvents()
    }
}

// MARK: - WebView NSViewRepresentable

struct OutlookWebViewRepresentable: NSViewRepresentable {
    @Binding var isAuthenticated: Bool
    @Binding var isImporting: Bool
    @Binding var importResult: OutlookWebImportResult?
    @Binding var errorMessage: String?
    @Binding var currentURL: String
    @Binding var coordinator: OutlookWebViewCoordinator?

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()

        // Add message handler for receiving calendar data from JavaScript
        config.userContentController.add(context.coordinator, name: "calendarData")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView

        // Load Outlook Calendar
        let url = URL(string: "https://outlook.office.com/calendar")!
        webView.load(URLRequest(url: url))

        DispatchQueue.main.async {
            self.coordinator = context.coordinator
        }

        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    func makeCoordinator() -> OutlookWebViewCoordinator {
        OutlookWebViewCoordinator(
            isAuthenticated: $isAuthenticated,
            isImporting: $isImporting,
            importResult: $importResult,
            errorMessage: $errorMessage,
            currentURL: $currentURL
        )
    }
}

// MARK: - WebView Coordinator

class OutlookWebViewCoordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    @Binding var isAuthenticated: Bool
    @Binding var isImporting: Bool
    @Binding var importResult: OutlookWebImportResult?
    @Binding var errorMessage: String?
    @Binding var currentURL: String

    weak var webView: WKWebView?

    private let outlookDomains = [
        "outlook.office.com",
        "outlook.office365.com",
        "outlook.live.com"
    ]

    init(
        isAuthenticated: Binding<Bool>,
        isImporting: Binding<Bool>,
        importResult: Binding<OutlookWebImportResult?>,
        errorMessage: Binding<String?>,
        currentURL: Binding<String>
    ) {
        _isAuthenticated = isAuthenticated
        _isImporting = isImporting
        _importResult = importResult
        _errorMessage = errorMessage
        _currentURL = currentURL
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let url = webView.url else { return }
        let urlString = url.absoluteString

        DispatchQueue.main.async {
            self.currentURL = urlString
        }

        // Detect authentication state from URL
        let host = url.host?.lowercased() ?? ""
        let isOnOutlook = self.outlookDomains.contains(where: { host.contains($0) })
        let isOnCalendar = urlString.contains("/calendar") || urlString.contains("/owa")
        let isOnLoginPage = host.contains("login.microsoftonline.com") || host.contains("login.live.com")

        DispatchQueue.main.async {
            self.isAuthenticated = isOnOutlook && isOnCalendar && !isOnLoginPage
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        let nsError = error as NSError
        if nsError.code == NSURLErrorCancelled { return }

        DispatchQueue.main.async {
            self.errorMessage = "Navigation failed: \(error.localizedDescription)"
        }
    }

    // MARK: - WKScriptMessageHandler

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "calendarData" else { return }

        guard let jsonString = message.body as? String,
              let jsonData = jsonString.data(using: .utf8) else {
            DispatchQueue.main.async {
                self.isImporting = false
                self.errorMessage = "Failed to receive calendar data from Outlook"
            }
            return
        }

        processCalendarData(jsonData)
    }

    // MARK: - Fetch Calendar Events (JavaScript Injection)

    func fetchCalendarEvents() {
        guard let webView = webView else {
            DispatchQueue.main.async {
                self.isImporting = false
                self.errorMessage = "WebView not available"
            }
            return
        }

        // JavaScript that fetches calendar events using the OWA REST API
        // Uses the current page's origin to avoid CORS issues
        // Normalizes PascalCase/camelCase response keys for consistent parsing
        let js = """
        (function() {
            var start = new Date().toISOString();
            var end = new Date(Date.now() + 30*24*60*60*1000).toISOString();
            var baseUrl = window.location.origin;
            var url = baseUrl + '/api/v2.0/me/calendarview?startdatetime=' + encodeURIComponent(start) + '&enddatetime=' + encodeURIComponent(end) + '&$orderby=Start/DateTime&$top=200&$select=Subject,Start,End,Location,Attendees,BodyPreview,Id';

            fetch(url, {
                credentials: 'include',
                headers: {
                    'Content-Type': 'application/json',
                    'Accept': 'application/json'
                }
            })
            .then(function(response) {
                if (!response.ok) {
                    return response.text().then(function(text) {
                        throw new Error('HTTP ' + response.status + ': ' + text.substring(0, 300));
                    });
                }
                return response.json();
            })
            .then(function(data) {
                var events = (data.value || []).map(function(e) {
                    var startObj = e.Start || e.start || {};
                    var endObj = e.End || e.end || {};
                    var locObj = e.Location || e.location || {};
                    var rawAttendees = e.Attendees || e.attendees || [];

                    return {
                        id: e.Id || e.id || '',
                        subject: e.Subject || e.subject || 'Untitled',
                        bodyPreview: e.BodyPreview || e.bodyPreview || '',
                        start: {
                            dateTime: startObj.DateTime || startObj.dateTime || '',
                            timeZone: startObj.TimeZone || startObj.timeZone || 'UTC'
                        },
                        end: {
                            dateTime: endObj.DateTime || endObj.dateTime || '',
                            timeZone: endObj.TimeZone || endObj.timeZone || 'UTC'
                        },
                        location: {
                            displayName: locObj.DisplayName || locObj.displayName || ''
                        },
                        attendees: rawAttendees.map(function(a) {
                            var email = a.EmailAddress || a.emailAddress || {};
                            return {
                                emailAddress: {
                                    name: email.Name || email.name || '',
                                    address: email.Address || email.address || ''
                                },
                                type: a.Type || a.type || 'required'
                            };
                        })
                    };
                });
                window.webkit.messageHandlers.calendarData.postMessage(JSON.stringify({value: events}));
            })
            .catch(function(error) {
                window.webkit.messageHandlers.calendarData.postMessage(JSON.stringify({error: error.message || 'Unknown error'}));
            });
        })();
        """

        webView.evaluateJavaScript(js) { _, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.isImporting = false
                    self.errorMessage = "Failed to fetch calendar data: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - Process Calendar Data

    private func processCalendarData(_ data: Data) {
        DispatchQueue.main.async {
            do {
                // Check for error response
                if let errorCheck = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorMsg = errorCheck["error"] as? String {
                    self.isImporting = false
                    self.errorMessage = "Outlook API error: \(errorMsg)"
                    return
                }

                let decoder = JSONDecoder()
                let response = try decoder.decode(OWACalendarResponse.self, from: data)
                let events = response.value

                let dataStore = DataStore.shared
                let existingMeetings = dataStore.meetings
                var importedMeetings: [Meeting] = []
                var skippedCount = 0
                var failedCount = 0

                for event in events {
                    // Skip if already imported (match by Outlook event ID)
                    if existingMeetings.contains(where: { $0.outlookEventId == event.id }) {
                        skippedCount += 1
                        continue
                    }

                    // Parse start/end dates
                    guard let startDate = self.parseOWADate(event.start.dateTime, timeZone: event.start.timeZone),
                          let endDate = self.parseOWADate(event.end.dateTime, timeZone: event.end.timeZone) else {
                        failedCount += 1
                        continue
                    }

                    // Only import future meetings
                    guard startDate > Date() else {
                        skippedCount += 1
                        continue
                    }

                    // Determine meeting type from title keywords and attendee count
                    let attendeeCount = event.attendees.count
                    let meetingType = self.inferMeetingType(subject: event.subject, attendeeCount: attendeeCount)

                    // Match attendees to existing People by email
                    let matchedAttendees: [UUID] = event.attendees.compactMap { attendee in
                        guard let email = attendee.emailAddress.address, !email.isEmpty else { return nil }
                        return dataStore.people.first { $0.email?.lowercased() == email.lowercased() }?.id
                    }

                    // Determine location
                    let location: String? = {
                        guard let name = event.location?.displayName, !name.isEmpty else { return nil }
                        return name
                    }()

                    // Create the meeting
                    let meeting = Meeting(
                        id: UUID(),
                        title: event.subject,
                        date: startDate,
                        duration: endDate.timeIntervalSince(startDate),
                        attendees: matchedAttendees,
                        meetingType: meetingType,
                        location: location,
                        outlookEventId: event.id,
                        agenda: event.bodyPreview?.isEmpty == false ? event.bodyPreview : nil,
                        notes: ""
                    )

                    dataStore.addMeeting(meeting)
                    importedMeetings.append(meeting)
                }

                self.importResult = OutlookWebImportResult(
                    importedCount: importedMeetings.count,
                    skippedCount: skippedCount,
                    failedCount: failedCount,
                    importedMeetings: importedMeetings
                )
                self.isImporting = false

                // Sync widget data
                WidgetSyncService.shared.syncToWidget()

                print("OutlookWebImport: Imported \(importedMeetings.count) meetings, skipped \(skippedCount), failed \(failedCount)")

            } catch {
                self.isImporting = false
                self.errorMessage = "Failed to parse calendar data: \(error.localizedDescription)"
                print("OutlookWebImport: Parse error: \(error)")
            }
        }
    }

    // MARK: - Date Parsing

    private func parseOWADate(_ dateString: String, timeZone: String) -> Date? {
        // Try ISO 8601 with fractional seconds
        let f1 = ISO8601DateFormatter()
        f1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = f1.date(from: dateString) { return date }

        // Try ISO 8601 without fractional seconds
        let f2 = ISO8601DateFormatter()
        f2.formatOptions = [.withInternetDateTime]
        if let date = f2.date(from: dateString) { return date }

        // Try plain datetime format (no timezone suffix - common from OWA)
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(identifier: timeZone) ?? .current

        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSS"
        if let date = df.date(from: dateString) { return date }

        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let date = df.date(from: dateString) { return date }

        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        if let date = df.date(from: dateString) { return date }

        return nil
    }

    // MARK: - Meeting Type Inference

    private func inferMeetingType(subject: String, attendeeCount: Int) -> MeetingType {
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

        // Infer from attendee count
        if attendeeCount <= 2 {
            return .oneOnOne
        }

        return .teamMeeting
    }
}

// MARK: - OWA Response Models (normalized camelCase from JavaScript)

struct OWACalendarResponse: Codable {
    let value: [OWANormalizedEvent]
}

struct OWANormalizedEvent: Codable {
    let id: String
    let subject: String
    let bodyPreview: String?
    let start: OWANormalizedDateTime
    let end: OWANormalizedDateTime
    let location: OWANormalizedLocation?
    let attendees: [OWANormalizedAttendee]
}

struct OWANormalizedDateTime: Codable {
    let dateTime: String
    let timeZone: String
}

struct OWANormalizedLocation: Codable {
    let displayName: String?
}

struct OWANormalizedAttendee: Codable {
    let emailAddress: OWANormalizedEmailAddress
    let type: String?
}

struct OWANormalizedEmailAddress: Codable {
    let name: String?
    let address: String?
}

// MARK: - Import Result

struct OutlookWebImportResult {
    let importedCount: Int
    let skippedCount: Int
    let failedCount: Int
    let importedMeetings: [Meeting]
}

#endif  // os(macOS)
