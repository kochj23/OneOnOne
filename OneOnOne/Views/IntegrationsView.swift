//
//  IntegrationsView.swift
//  OneOnOne
//
//  Slack and Teams integration settings
//  Created by Jordan Koch on 2026-02-02.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

struct IntegrationsView: View {
    @StateObject private var integrationService = IntegrationService.shared
    @State private var showSlackSetup = false
    @State private var showTeamsSetup = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
                .padding(24)

            Divider()
                .background(ModernColors.glassBorder)

            // Content
            ScrollView {
                VStack(spacing: 24) {
                    // Slack Integration
                    integrationCard(
                        name: "Slack",
                        icon: "number.square.fill",
                        color: Color(hex: "#4A154B"),
                        description: "Share meeting summaries and action items to Slack channels",
                        isConnected: integrationService.isSlackConnected,
                        onConnect: { showSlackSetup = true },
                        onDisconnect: { integrationService.disconnectSlack() }
                    )

                    // Teams Integration
                    integrationCard(
                        name: "Microsoft Teams",
                        icon: "rectangle.grid.2x2.fill",
                        color: Color(hex: "#5558AF"),
                        description: "Post meeting summaries to Teams channels via webhooks",
                        isConnected: integrationService.isTeamsConnected,
                        onConnect: { showTeamsSetup = true },
                        onDisconnect: { integrationService.disconnectTeams() }
                    )

                    // Future integrations placeholder
                    comingSoonCard
                }
                .padding(24)
            }
        }
        .sheet(isPresented: $showSlackSetup) {
            SlackSetupView()
        }
        .sheet(isPresented: $showTeamsSetup) {
            TeamsSetupView()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Integrations")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(ModernColors.textPrimary)

                Text("Connect with Slack, Teams, and other services")
                    .font(.system(size: 14))
                    .foregroundColor(ModernColors.textSecondary)
            }

            Spacer()
        }
    }

    // MARK: - Integration Card

    private func integrationCard(
        name: String,
        icon: String,
        color: Color,
        description: String,
        isConnected: Bool,
        onConnect: @escaping () -> Void,
        onDisconnect: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 20) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(color)
                .frame(width: 64, height: 64)
                .background(color.opacity(0.15))
                .cornerRadius(16)

            // Info
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(ModernColors.textPrimary)

                    if isConnected {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(ModernColors.accentGreen)
                                .frame(width: 8, height: 8)
                            Text("Connected")
                                .font(.system(size: 12))
                                .foregroundColor(ModernColors.accentGreen)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(ModernColors.accentGreen.opacity(0.15))
                        .cornerRadius(8)
                    }
                }

                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(ModernColors.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            // Action button
            if isConnected {
                Menu {
                    Button("Settings") {
                        // Would open settings
                    }
                    Button("Disconnect", role: .destructive) {
                        onDisconnect()
                    }
                } label: {
                    HStack {
                        Text("Connected")
                        Image(systemName: "chevron.down")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ModernColors.accentGreen)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(ModernColors.accentGreen.opacity(0.15))
                    .cornerRadius(10)
                }
            } else {
                Button(action: onConnect) {
                    Text("Connect")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(color)
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
        .glassCard()
    }

    // MARK: - Coming Soon Card

    private var comingSoonCard: some View {
        VStack(spacing: 16) {
            Text("More Integrations Coming Soon")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(ModernColors.textSecondary)

            HStack(spacing: 24) {
                comingSoonItem("Google Calendar", icon: "calendar")
                comingSoonItem("Notion", icon: "doc.text")
                comingSoonItem("Jira", icon: "checkmark.square")
                comingSoonItem("Asana", icon: "list.bullet")
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.02))
        .cornerRadius(20)
    }

    private func comingSoonItem(_ name: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(ModernColors.textTertiary)

            Text(name)
                .font(.system(size: 12))
                .foregroundColor(ModernColors.textTertiary)
        }
    }
}

// MARK: - Slack Setup View

struct SlackSetupView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var integrationService = IntegrationService.shared

    @State private var webhookURL = ""
    @State private var defaultChannel = "#general"
    @State private var isValidating = false
    @State private var validationError: String?

    var body: some View {
        ZStack {
            ModernColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 12) {
                            Image(systemName: "number.square.fill")
                                .font(.system(size: 28))
                                .foregroundColor(Color(hex: "#4A154B"))

                            Text("Connect Slack")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(ModernColors.textPrimary)
                        }

                        Text("Set up Slack webhook integration")
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
                .padding(24)

                Divider()
                    .background(ModernColors.glassBorder)

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Instructions
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Setup Instructions")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(ModernColors.textPrimary)

                            VStack(alignment: .leading, spacing: 8) {
                                instructionStep(1, "Go to your Slack workspace settings")
                                instructionStep(2, "Navigate to Apps → Incoming Webhooks")
                                instructionStep(3, "Create a new webhook and select a channel")
                                instructionStep(4, "Copy the webhook URL and paste it below")
                            }
                        }
                        .padding(16)
                        .glassCard()

                        // Webhook URL
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Webhook URL")
                                .formLabel()
                            TextField("https://hooks.slack.com/services/...", text: $webhookURL)
                                .formTextField()

                            if let error = validationError {
                                Text(error)
                                    .font(.system(size: 12))
                                    .foregroundColor(ModernColors.red)
                            }
                        }

                        // Default Channel
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Default Channel")
                                .formLabel()
                            TextField("#general", text: $defaultChannel)
                                .formTextField()

                            Text("This channel will be used when sharing without specifying a channel")
                                .font(.system(size: 12))
                                .foregroundColor(ModernColors.textTertiary)
                        }

                        // Connect Button
                        Button {
                            connect()
                        } label: {
                            HStack {
                                if isValidating {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                }
                                Text(isValidating ? "Validating..." : "Connect Slack")
                            }
                            .frame(maxWidth: .infinity)
                            .primaryButton()
                        }
                        .buttonStyle(.plain)
                        .disabled(webhookURL.isEmpty || isValidating)
                    }
                    .padding(24)
                }
            }
        }
        .frame(width: 500, height: 600)
    }

    private func instructionStep(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(ModernColors.cyan)
                .frame(width: 24, height: 24)
                .background(ModernColors.cyan.opacity(0.2))
                .cornerRadius(12)

            Text(text)
                .font(.system(size: 14))
                .foregroundColor(ModernColors.textSecondary)
        }
    }

    private func connect() {
        isValidating = true
        validationError = nil

        // Validate URL format
        guard webhookURL.hasPrefix("https://hooks.slack.com/") else {
            validationError = "Invalid Slack webhook URL format"
            isValidating = false
            return
        }

        // Connect
        integrationService.configureSlack(webhookURL: webhookURL, defaultChannel: defaultChannel)
        dismiss()
    }
}

// MARK: - Teams Setup View

struct TeamsSetupView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var integrationService = IntegrationService.shared

    @State private var webhookURL = ""
    @State private var isValidating = false
    @State private var validationError: String?

    var body: some View {
        ZStack {
            ModernColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 12) {
                            Image(systemName: "rectangle.grid.2x2.fill")
                                .font(.system(size: 28))
                                .foregroundColor(Color(hex: "#5558AF"))

                            Text("Connect Microsoft Teams")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(ModernColors.textPrimary)
                        }

                        Text("Set up Teams webhook integration")
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
                .padding(24)

                Divider()
                    .background(ModernColors.glassBorder)

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Instructions
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Setup Instructions")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(ModernColors.textPrimary)

                            VStack(alignment: .leading, spacing: 8) {
                                instructionStep(1, "Open Microsoft Teams and go to a channel")
                                instructionStep(2, "Click the ... menu → Connectors")
                                instructionStep(3, "Find and configure 'Incoming Webhook'")
                                instructionStep(4, "Copy the webhook URL and paste it below")
                            }
                        }
                        .padding(16)
                        .glassCard()

                        // Webhook URL
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Webhook URL")
                                .formLabel()
                            TextField("https://outlook.office.com/webhook/...", text: $webhookURL)
                                .formTextField()

                            if let error = validationError {
                                Text(error)
                                    .font(.system(size: 12))
                                    .foregroundColor(ModernColors.red)
                            }
                        }

                        // Connect Button
                        Button {
                            connect()
                        } label: {
                            HStack {
                                if isValidating {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                }
                                Text(isValidating ? "Validating..." : "Connect Teams")
                            }
                            .frame(maxWidth: .infinity)
                            .primaryButton()
                        }
                        .buttonStyle(.plain)
                        .disabled(webhookURL.isEmpty || isValidating)
                    }
                    .padding(24)
                }
            }
        }
        .frame(width: 500, height: 550)
    }

    private func instructionStep(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(ModernColors.cyan)
                .frame(width: 24, height: 24)
                .background(ModernColors.cyan.opacity(0.2))
                .cornerRadius(12)

            Text(text)
                .font(.system(size: 14))
                .foregroundColor(ModernColors.textSecondary)
        }
    }

    private func connect() {
        isValidating = true
        validationError = nil

        // Validate URL format
        guard webhookURL.contains("office.com") || webhookURL.contains("webhook.office") else {
            validationError = "Invalid Teams webhook URL format"
            isValidating = false
            return
        }

        // Connect
        integrationService.configureTeams(webhookURL: webhookURL)
        dismiss()
    }
}

#Preview {
    IntegrationsView()
}
