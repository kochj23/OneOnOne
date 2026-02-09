//
//  IntegrationsView.swift
//  OneOnOne
//
//  Slack and Teams integration settings
//  Created by Jordan Koch on 2026-02-02.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

#if os(macOS)
struct IntegrationsView: View {
    @StateObject private var integrationService = IntegrationService.shared
    @StateObject private var outlookService = OutlookCalendarService.shared
    @State private var showSlackSetup = false
    @State private var showTeamsSetup = false
    @State private var showOutlookSetup = false

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
                    // Calendar Integrations Section
                    calendarIntegrationsSection

                    // Communication Integrations Section
                    communicationIntegrationsSection

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
        .sheet(isPresented: $showOutlookSetup) {
            OutlookSetupView()
        }
    }

    // MARK: - Calendar Integrations

    private var calendarIntegrationsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Calendar")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(ModernColors.textSecondary)
                .textCase(.uppercase)
                .tracking(1)

            // Outlook Calendar
            outlookCalendarCard
        }
    }

    private var outlookCalendarCard: some View {
        HStack(spacing: 20) {
            // Icon
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 32))
                .foregroundColor(Color(hex: "#0078D4"))
                .frame(width: 64, height: 64)
                .background(Color(hex: "#0078D4").opacity(0.15))
                .cornerRadius(16)

            // Info
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Microsoft Outlook Calendar")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(ModernColors.textPrimary)

                    if outlookService.isAuthenticated {
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

                if outlookService.isAuthenticated, let email = outlookService.userEmail {
                    Text(email)
                        .font(.system(size: 12))
                        .foregroundColor(ModernColors.cyan)
                }

                Text("Sync meetings with your Outlook calendar, create events with Teams links")
                    .font(.system(size: 14))
                    .foregroundColor(ModernColors.textSecondary)
                    .lineLimit(2)

                if let lastSync = outlookService.lastSyncDate {
                    Text("Last synced: \(lastSync.formatted(date: .abbreviated, time: .shortened))")
                        .font(.system(size: 11))
                        .foregroundColor(ModernColors.textTertiary)
                }
            }

            Spacer()

            // Action buttons
            if outlookService.isAuthenticated {
                HStack(spacing: 12) {
                    // Sync button
                    Button {
                        Task {
                            try? await outlookService.syncWithMeetings()
                        }
                    } label: {
                        if outlookService.isSyncing {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(ModernColors.cyan)
                    .frame(width: 32, height: 32)
                    .background(ModernColors.cyan.opacity(0.15))
                    .cornerRadius(8)
                    .disabled(outlookService.isSyncing)

                    // Menu
                    Menu {
                        Button("Sync Now") {
                            Task {
                                try? await outlookService.syncWithMeetings()
                            }
                        }
                        Button("Settings") {
                            showOutlookSetup = true
                        }
                        Divider()
                        Button("Disconnect", role: .destructive) {
                            outlookService.signOut()
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
                }
            } else {
                Button(action: { showOutlookSetup = true }) {
                    Text("Connect")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color(hex: "#0078D4"))
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
        .glassCard()
    }

    // MARK: - Communication Integrations

    private var communicationIntegrationsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Communication")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(ModernColors.textSecondary)
                .textCase(.uppercase)
                .tracking(1)

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
                comingSoonItem("Zoom", icon: "video")
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

// MARK: - Outlook Setup View

struct OutlookSetupView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var outlookService = OutlookCalendarService.shared

    @State private var clientId = ""
    @State private var tenantId = "common"
    @State private var isConnecting = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        ZStack {
            ModernColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 12) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.system(size: 28))
                                .foregroundColor(Color(hex: "#0078D4"))

                            Text("Microsoft Outlook Calendar")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(ModernColors.textPrimary)
                        }

                        Text("Connect your Outlook calendar to sync meetings")
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
                        if outlookService.isAuthenticated {
                            // Connected state
                            connectedView
                        } else {
                            // Setup instructions
                            setupInstructionsView

                            // Configuration form
                            configurationForm

                            // Connect button
                            connectButton
                        }
                    }
                    .padding(24)
                }
            }
        }
        .frame(width: 600, height: 700)
        .onAppear {
            clientId = outlookService.clientId
            tenantId = outlookService.tenantId
        }
        .alert("Connection Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Connected View

    private var connectedView: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Account info
            HStack(spacing: 16) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(Color(hex: "#0078D4"))

                VStack(alignment: .leading, spacing: 4) {
                    if let name = outlookService.userName {
                        Text(name)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(ModernColors.textPrimary)
                    }

                    if let email = outlookService.userEmail {
                        Text(email)
                            .font(.system(size: 14))
                            .foregroundColor(ModernColors.cyan)
                    }

                    HStack(spacing: 4) {
                        Circle()
                            .fill(ModernColors.accentGreen)
                            .frame(width: 8, height: 8)
                        Text("Connected")
                            .font(.system(size: 12))
                            .foregroundColor(ModernColors.accentGreen)
                    }
                }

                Spacer()
            }
            .padding(20)
            .glassCard()

            // Calendar selection
            if !outlookService.calendars.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Default Calendar")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(ModernColors.textPrimary)

                    Picker("Calendar", selection: $outlookService.selectedCalendarId) {
                        ForEach(outlookService.calendars) { calendar in
                            HStack {
                                Text(calendar.name)
                                if calendar.isDefaultCalendar {
                                    Text("(Default)")
                                        .foregroundColor(ModernColors.textTertiary)
                                }
                            }
                            .tag(calendar.id as String?)
                        }
                    }
                    .pickerStyle(.menu)

                    Text("New meetings will be created in this calendar")
                        .font(.system(size: 12))
                        .foregroundColor(ModernColors.textTertiary)
                }
                .padding(16)
                .glassCard()
            }

            // Sync options
            VStack(alignment: .leading, spacing: 16) {
                Text("Sync Options")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ModernColors.textPrimary)

                Button {
                    Task {
                        do {
                            try await outlookService.syncWithMeetings()
                        } catch {
                            errorMessage = error.localizedDescription
                            showError = true
                        }
                    }
                } label: {
                    HStack {
                        if outlookService.isSyncing {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                        Text(outlookService.isSyncing ? "Syncing..." : "Sync Now")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(hex: "#0078D4"))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .disabled(outlookService.isSyncing)

                if let lastSync = outlookService.lastSyncDate {
                    Text("Last synced: \(lastSync.formatted(date: .abbreviated, time: .shortened))")
                        .font(.system(size: 12))
                        .foregroundColor(ModernColors.textTertiary)
                }
            }
            .padding(16)
            .glassCard()

            // Sign out button
            Button {
                outlookService.signOut()
                dismiss()
            } label: {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("Disconnect Account")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(ModernColors.red.opacity(0.15))
                .foregroundColor(ModernColors.red)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Setup Instructions

    private var setupInstructionsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Setup Instructions")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(ModernColors.textPrimary)

            Text("To connect Outlook Calendar, you need to register an app in Azure AD:")
                .font(.system(size: 14))
                .foregroundColor(ModernColors.textSecondary)

            VStack(alignment: .leading, spacing: 8) {
                instructionStep(1, "Go to Azure Portal (portal.azure.com)")
                instructionStep(2, "Navigate to Azure Active Directory → App registrations")
                instructionStep(3, "Click 'New registration' and create an app")
                instructionStep(4, "Set redirect URI to: msauth.com.jordankoch.OneOnOne://auth")
                instructionStep(5, "Add API permissions: Calendars.ReadWrite, User.Read")
                instructionStep(6, "Copy the Application (client) ID below")
            }

            Link(destination: URL(string: "https://portal.azure.com/#blade/Microsoft_AAD_RegisteredApps/ApplicationsListBlade")!) {
                HStack {
                    Image(systemName: "arrow.up.right.square")
                    Text("Open Azure Portal")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(hex: "#0078D4"))
            }
        }
        .padding(16)
        .glassCard()
    }

    // MARK: - Configuration Form

    private var configurationForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Configuration")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(ModernColors.textPrimary)

            // Client ID
            VStack(alignment: .leading, spacing: 8) {
                Text("Application (Client) ID")
                    .formLabel()
                TextField("xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx", text: $clientId)
                    .formTextField()

                Text("Found in Azure AD → App registrations → Your app → Overview")
                    .font(.system(size: 11))
                    .foregroundColor(ModernColors.textTertiary)
            }

            // Tenant ID
            VStack(alignment: .leading, spacing: 8) {
                Text("Tenant ID (Optional)")
                    .formLabel()
                TextField("common", text: $tenantId)
                    .formTextField()

                Text("Use 'common' for personal accounts, or your organization's tenant ID")
                    .font(.system(size: 11))
                    .foregroundColor(ModernColors.textTertiary)
            }
        }
        .padding(16)
        .glassCard()
    }

    // MARK: - Connect Button

    private var connectButton: some View {
        Button {
            connect()
        } label: {
            HStack {
                if isConnecting {
                    ProgressView()
                        .scaleEffect(0.8)
                }
                Text(isConnecting ? "Connecting..." : "Connect Outlook Calendar")
            }
            .frame(maxWidth: .infinity)
            .primaryButton()
        }
        .buttonStyle(.plain)
        .disabled(clientId.isEmpty || isConnecting)
    }

    // MARK: - Helper Views

    private func instructionStep(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color(hex: "#0078D4"))
                .frame(width: 24, height: 24)
                .background(Color(hex: "#0078D4").opacity(0.2))
                .cornerRadius(12)

            Text(text)
                .font(.system(size: 14))
                .foregroundColor(ModernColors.textSecondary)
        }
    }

    // MARK: - Actions

    private func connect() {
        isConnecting = true

        // Save configuration
        outlookService.clientId = clientId
        outlookService.tenantId = tenantId.isEmpty ? "common" : tenantId
        outlookService.saveConfiguration()

        Task {
            do {
                try await outlookService.authenticate()
                await MainActor.run {
                    isConnecting = false
                }
            } catch {
                await MainActor.run {
                    isConnecting = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

#Preview {
    IntegrationsView()
}
#endif  // os(macOS)
