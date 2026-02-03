//
//  IntegrationService.swift
//  OneOnOne
//
//  Integration with external services (Slack, Teams)
//  Created by Jordan Koch on 2026-02-02.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation

@MainActor
class IntegrationService: ObservableObject {
    static let shared = IntegrationService()

    @Published var slackConfig: SlackConfig?
    @Published var teamsConfig: TeamsConfig?
    @Published var isSlackConnected = false
    @Published var isTeamsConnected = false

    private let configFile: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("OneOnOne/integrations.json")
    }()

    private init() {
        loadConfig()
    }

    // MARK: - Slack Integration

    func configureSlack(webhookURL: String, defaultChannel: String) {
        slackConfig = SlackConfig(
            webhookURL: webhookURL,
            defaultChannel: defaultChannel,
            isEnabled: true
        )
        isSlackConnected = true
        saveConfig()
    }

    func disconnectSlack() {
        slackConfig = nil
        isSlackConnected = false
        saveConfig()
    }

    func sendToSlack(message: String, channel: String? = nil) async throws {
        guard let config = slackConfig, config.isEnabled else {
            throw IntegrationError.notConfigured
        }

        guard let url = URL(string: config.webhookURL) else {
            throw IntegrationError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "channel": channel ?? config.defaultChannel,
            "text": message,
            "username": "OneOnOne",
            "icon_emoji": ":calendar:"
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw IntegrationError.requestFailed
        }
    }

    func shareMeetingSummary(meeting: Meeting, channel: String? = nil) async throws {
        guard let config = slackConfig, config.isEnabled else {
            throw IntegrationError.notConfigured
        }

        let attendeeNames = meeting.attendees.compactMap {
            DataStore.shared.person(for: $0)?.name
        }

        var message = """
        *Meeting Summary: \(meeting.title)*
        :calendar: \(meeting.date.formatted(date: .abbreviated, time: .shortened))
        :busts_in_silhouette: \(attendeeNames.joined(separator: ", "))
        """

        if let summary = meeting.summary {
            message += "\n\n*Summary:*\n\(summary)"
        }

        if !meeting.actionItems.isEmpty {
            message += "\n\n*Action Items:*"
            for item in meeting.actionItems.filter({ !$0.isCompleted }) {
                let assignee = item.assigneeId.flatMap { DataStore.shared.person(for: $0)?.name } ?? "Unassigned"
                message += "\n• \(item.title) (@\(assignee))"
            }
        }

        if !meeting.decisions.isEmpty {
            message += "\n\n*Decisions:*"
            for decision in meeting.decisions {
                message += "\n• \(decision.title)"
            }
        }

        try await sendToSlack(message: message, channel: channel)
    }

    func shareActionItemReminder(item: ActionItem, channel: String? = nil) async throws {
        let assignee = item.assigneeId.flatMap { DataStore.shared.person(for: $0)?.name } ?? "Unassigned"
        let dueText = item.dueDate.map { "Due: \($0.formatted(date: .abbreviated, time: .omitted))" } ?? ""

        let emoji = item.isOverdue ? ":warning:" : ":clipboard:"

        let message = """
        \(emoji) *Action Item Reminder*
        \(item.title)
        :bust_in_silhouette: \(assignee)
        \(dueText)
        """

        try await sendToSlack(message: message, channel: channel)
    }

    // MARK: - Microsoft Teams Integration

    func configureTeams(webhookURL: String) {
        teamsConfig = TeamsConfig(
            webhookURL: webhookURL,
            isEnabled: true
        )
        isTeamsConnected = true
        saveConfig()
    }

    func disconnectTeams() {
        teamsConfig = nil
        isTeamsConnected = false
        saveConfig()
    }

    func sendToTeams(message: String, title: String? = nil) async throws {
        guard let config = teamsConfig, config.isEnabled else {
            throw IntegrationError.notConfigured
        }

        guard let url = URL(string: config.webhookURL) else {
            throw IntegrationError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Teams Adaptive Card format
        var card: [String: Any] = [
            "@type": "MessageCard",
            "@context": "http://schema.org/extensions",
            "themeColor": "3BDAFC",
            "text": message
        ]

        if let title = title {
            card["title"] = title
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: card)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw IntegrationError.requestFailed
        }
    }

    func shareMeetingSummaryToTeams(meeting: Meeting) async throws {
        guard let config = teamsConfig, config.isEnabled else {
            throw IntegrationError.notConfigured
        }

        let attendeeNames = meeting.attendees.compactMap {
            DataStore.shared.person(for: $0)?.name
        }

        var sections: [[String: Any]] = []

        // Meeting info section
        sections.append([
            "activityTitle": meeting.title,
            "activitySubtitle": meeting.date.formatted(date: .complete, time: .shortened),
            "facts": [
                ["name": "Attendees", "value": attendeeNames.joined(separator: ", ")],
                ["name": "Type", "value": meeting.meetingType.rawValue]
            ]
        ])

        // Summary section
        if let summary = meeting.summary {
            sections.append([
                "title": "Summary",
                "text": summary
            ])
        }

        // Action items section
        if !meeting.actionItems.isEmpty {
            let items = meeting.actionItems.filter { !$0.isCompleted }.map { item -> String in
                let assignee = item.assigneeId.flatMap { DataStore.shared.person(for: $0)?.name } ?? "Unassigned"
                return "• \(item.title) (\(assignee))"
            }
            sections.append([
                "title": "Action Items",
                "text": items.joined(separator: "\n")
            ])
        }

        guard let url = URL(string: config.webhookURL) else {
            throw IntegrationError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let card: [String: Any] = [
            "@type": "MessageCard",
            "@context": "http://schema.org/extensions",
            "themeColor": "3BDAFC",
            "summary": "Meeting Summary: \(meeting.title)",
            "sections": sections
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: card)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw IntegrationError.requestFailed
        }
    }

    // MARK: - Configuration Persistence

    private func saveConfig() {
        let config = IntegrationConfig(
            slack: slackConfig,
            teams: teamsConfig
        )

        if let data = try? JSONEncoder().encode(config) {
            try? data.write(to: configFile)
        }
    }

    private func loadConfig() {
        guard let data = try? Data(contentsOf: configFile),
              let config = try? JSONDecoder().decode(IntegrationConfig.self, from: data) else {
            return
        }

        slackConfig = config.slack
        teamsConfig = config.teams
        isSlackConnected = slackConfig?.isEnabled ?? false
        isTeamsConnected = teamsConfig?.isEnabled ?? false
    }
}

// MARK: - Models

struct IntegrationConfig: Codable {
    var slack: SlackConfig?
    var teams: TeamsConfig?
}

struct SlackConfig: Codable {
    var webhookURL: String
    var defaultChannel: String
    var isEnabled: Bool
}

struct TeamsConfig: Codable {
    var webhookURL: String
    var isEnabled: Bool
}

enum IntegrationError: LocalizedError {
    case notConfigured
    case invalidURL
    case requestFailed

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Integration not configured"
        case .invalidURL:
            return "Invalid webhook URL"
        case .requestFailed:
            return "Request to external service failed"
        }
    }
}
