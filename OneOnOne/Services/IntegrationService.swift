//
//  IntegrationService.swift
//  OneOnOne
//
//  Integration with external services (Slack, Teams)
//  Created by Jordan Koch on 2026-02-02.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation
import Security

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

    // MARK: - Keychain Helpers

    private let keychainService = "com.jordankoch.OneOnOne.Integrations"

    private func saveToKeychain(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: keychainService
        ]
        SecItemDelete(query as CFDictionary)
        guard !value.isEmpty else { return }
        var addQuery = query
        addQuery[kSecValueData as String] = data
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    private func loadFromKeychain(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: keychainService,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func deleteFromKeychain(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: keychainService
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Configuration Persistence

    private func saveConfig() {
        // Webhook URLs are secrets — store in Keychain, not JSON
        if let slack = slackConfig {
            saveToKeychain(key: "slack_webhook_url", value: slack.webhookURL)
        } else {
            deleteFromKeychain(key: "slack_webhook_url")
        }
        if let teams = teamsConfig {
            saveToKeychain(key: "teams_webhook_url", value: teams.webhookURL)
        } else {
            deleteFromKeychain(key: "teams_webhook_url")
        }

        // Non-secret metadata stays in JSON (no webhook URLs)
        let config = IntegrationConfig(
            slack: slackConfig.map { SlackConfigFile(defaultChannel: $0.defaultChannel, isEnabled: $0.isEnabled) },
            teams: teamsConfig.map { TeamsConfigFile(isEnabled: $0.isEnabled) }
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

        // Load webhook URLs from Keychain
        let slackWebhook = loadFromKeychain(key: "slack_webhook_url")
        let teamsWebhook = loadFromKeychain(key: "teams_webhook_url")

        if let slack = config.slack {
            // Migrate: if Keychain is empty but JSON had a webhook, migrate it
            let webhook = slackWebhook ?? slack.legacyWebhookURL ?? ""
            slackConfig = SlackConfig(webhookURL: webhook, defaultChannel: slack.defaultChannel, isEnabled: slack.isEnabled)
            if slackWebhook == nil, let legacyURL = slack.legacyWebhookURL, !legacyURL.isEmpty {
                saveToKeychain(key: "slack_webhook_url", value: legacyURL)
            }
        }
        if let teams = config.teams {
            let webhook = teamsWebhook ?? teams.legacyWebhookURL ?? ""
            teamsConfig = TeamsConfig(webhookURL: webhook, isEnabled: teams.isEnabled)
            if teamsWebhook == nil, let legacyURL = teams.legacyWebhookURL, !legacyURL.isEmpty {
                saveToKeychain(key: "teams_webhook_url", value: legacyURL)
            }
        }

        isSlackConnected = slackConfig?.isEnabled ?? false
        isTeamsConnected = teamsConfig?.isEnabled ?? false

        // Re-save to strip legacy webhook URLs from JSON if they were present
        if config.slack?.legacyWebhookURL != nil || config.teams?.legacyWebhookURL != nil {
            saveConfig()
        }
    }
}

// MARK: - Models

/// Runtime model with full data including Keychain-sourced webhook URLs
struct SlackConfig {
    var webhookURL: String
    var defaultChannel: String
    var isEnabled: Bool
}

struct TeamsConfig {
    var webhookURL: String
    var isEnabled: Bool
}

/// File-safe config for JSON persistence (no webhook URLs — those go in Keychain)
struct SlackConfigFile: Codable {
    var defaultChannel: String
    var isEnabled: Bool
    // Legacy field for migration: read old files that had webhookURL in JSON
    var legacyWebhookURL: String?

    enum CodingKeys: String, CodingKey {
        case defaultChannel
        case isEnabled
        case legacyWebhookURL = "webhookURL"
    }
}

struct TeamsConfigFile: Codable {
    var isEnabled: Bool
    // Legacy field for migration
    var legacyWebhookURL: String?

    enum CodingKeys: String, CodingKey {
        case isEnabled
        case legacyWebhookURL = "webhookURL"
    }
}

struct IntegrationConfig: Codable {
    var slack: SlackConfigFile?
    var teams: TeamsConfigFile?
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
