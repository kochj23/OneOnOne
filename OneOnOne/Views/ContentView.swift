//
//  ContentView.swift
//  OneOnOne
//
//  Main content view with sidebar navigation
//  Created by Jordan Koch on 2026-02-02.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

enum SidebarSection: String, CaseIterable {
    case main = "Main"
    case people = "People"
    case tools = "Tools"
}

enum SidebarItem: String, CaseIterable {
    // Main
    case dashboard = "Dashboard"
    case meetings = "Meetings"
    case actionItems = "Action Items"

    // People
    case people = "People"
    case feedback = "Feedback"
    case careers = "Careers"
    case okrs = "OKRs"

    // Tools
    case goals = "Goals"
    case templates = "Templates"
    case recordings = "Recordings"
    case search = "Search"
    case insights = "AI Insights"
    case teamInsights = "Team Insights"
    case integrations = "Integrations"

    var section: SidebarSection {
        switch self {
        case .dashboard, .meetings, .actionItems:
            return .main
        case .people, .feedback, .careers, .okrs:
            return .people
        case .goals, .templates, .recordings, .search, .insights, .teamInsights, .integrations:
            return .tools
        }
    }

    var icon: String {
        switch self {
        case .dashboard: return "square.grid.2x2"
        case .meetings: return "calendar"
        case .people: return "person.2"
        case .actionItems: return "checklist"
        case .goals: return "target"
        case .insights: return "sparkles"
        case .templates: return "doc.text"
        case .feedback: return "star"
        case .careers: return "chart.line.uptrend.xyaxis"
        case .okrs: return "chart.bar.doc.horizontal"
        case .recordings: return "waveform"
        case .search: return "magnifyingglass"
        case .teamInsights: return "chart.pie"
        case .integrations: return "link"
        }
    }

    var color: Color {
        switch self {
        case .dashboard: return ModernColors.cyan
        case .meetings: return ModernColors.accentBlue
        case .people: return ModernColors.purple
        case .actionItems: return ModernColors.orange
        case .goals: return ModernColors.accentGreen
        case .insights: return ModernColors.pink
        case .templates: return ModernColors.cyan
        case .feedback: return Color(hex: "#FFD700")
        case .careers: return ModernColors.purple
        case .okrs: return ModernColors.orange
        case .recordings: return ModernColors.red
        case .search: return ModernColors.textSecondary
        case .teamInsights: return ModernColors.accentGreen
        case .integrations: return ModernColors.accentBlue
        }
    }

    static var mainItems: [SidebarItem] {
        [.dashboard, .meetings, .actionItems]
    }

    static var peopleItems: [SidebarItem] {
        [.people, .feedback, .careers, .okrs]
    }

    static var toolsItems: [SidebarItem] {
        [.goals, .templates, .recordings, .search, .insights, .teamInsights, .integrations]
    }
}

struct ContentView: View {
    @EnvironmentObject var dataStore: DataStore
    @State private var selectedItem: SidebarItem = .dashboard
    @State private var showNewMeeting = false
    @State private var showNewPerson = false
    @State private var showNewGoal = false

    var body: some View {
        ZStack {
            GlassmorphicBackground()

            HStack(spacing: 0) {
                // Sidebar
                sidebar
                    .frame(width: 260)

                // Divider
                Rectangle()
                    .fill(ModernColors.glassBorder)
                    .frame(width: 1)

                // Main content
                mainContent
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .newMeeting)) { _ in
            showNewMeeting = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .newPerson)) { _ in
            showNewPerson = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .newGoal)) { _ in
            showNewGoal = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .useTemplate)) { notification in
            if let _ = notification.object as? MeetingTemplate {
                showNewMeeting = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .selectMeeting)) { _ in
            selectedItem = .meetings
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToActionItems)) { _ in
            selectedItem = .actionItems
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToGoals)) { _ in
            selectedItem = .goals
        }
        .sheet(isPresented: $showNewMeeting) {
            NewMeetingView()
        }
        .sheet(isPresented: $showNewPerson) {
            NewPersonView()
        }
        .sheet(isPresented: $showNewGoal) {
            NewGoalView()
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            // App header
            appHeader
                .padding(20)

            Divider()
                .background(ModernColors.glassBorder)

            // Navigation items
            ScrollView {
                VStack(spacing: 4) {
                    // Main section
                    sectionHeader("Main")
                    ForEach(SidebarItem.mainItems, id: \.self) { item in
                        sidebarButton(item)
                    }

                    // People section
                    sectionHeader("People")
                        .padding(.top, 12)
                    ForEach(SidebarItem.peopleItems, id: \.self) { item in
                        sidebarButton(item)
                    }

                    // Tools section
                    sectionHeader("Tools")
                        .padding(.top, 12)
                    ForEach(SidebarItem.toolsItems, id: \.self) { item in
                        sidebarButton(item)
                    }
                }
                .padding(16)
            }

            Spacer()

            // Quick stats
            quickStats
                .padding(16)

            // Sync status
            syncStatus
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
        }
        .background(Color.black.opacity(0.3))
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(ModernColors.textTertiary)
                .textCase(.uppercase)
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
    }

    private var appHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 28))
                .foregroundStyle(
                    LinearGradient(
                        colors: [ModernColors.cyan, ModernColors.purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("OneOnOne")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(ModernColors.textPrimary)

                Text("Meeting Manager")
                    .font(.system(size: 12))
                    .foregroundColor(ModernColors.textTertiary)
            }

            Spacer()
        }
    }

    private func sidebarButton(_ item: SidebarItem) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedItem = item
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: item.icon)
                    .font(.system(size: 16))
                    .frame(width: 20)

                Text(item.rawValue)
                    .font(.system(size: 14, weight: selectedItem == item ? .semibold : .medium))

                Spacer()

                // Badge for action items
                if item == .actionItems {
                    let count = dataStore.openActionItems().count
                    if count > 0 {
                        Text("\(count)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(ModernColors.orange)
                            .cornerRadius(8)
                    }
                }

                // Badge for overdue
                if item == .actionItems {
                    let overdue = dataStore.overdueActionItems.count
                    if overdue > 0 {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(ModernColors.red)
                    }
                }
            }
            .sidebarItem(isSelected: selectedItem == item, color: item.color)
        }
        .buttonStyle(.plain)
    }

    private var quickStats: some View {
        VStack(spacing: 12) {
            HStack {
                Text("This Week")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(ModernColors.textTertiary)
                Spacer()
            }

            HStack(spacing: 12) {
                statBadge(
                    value: dataStore.totalMeetingsThisWeek,
                    label: "Meetings",
                    color: ModernColors.accentBlue
                )

                statBadge(
                    value: dataStore.openActionItems().count,
                    label: "Tasks",
                    color: ModernColors.orange
                )

                statBadge(
                    value: dataStore.totalFeedbackThisMonth,
                    label: "Feedback",
                    color: Color(hex: "#FFD700")
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
    }

    private func statBadge(value: Int, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(color)

            Text(label)
                .font(.system(size: 10))
                .foregroundColor(ModernColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private var syncStatus: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.green)
                .frame(width: 8, height: 8)

            Text("Synced")
                .font(.system(size: 12))
                .foregroundColor(ModernColors.textTertiary)

            Spacer()

            if let lastSync = dataStore.lastSyncDate {
                Text(lastSync.formatted(.relative(presentation: .named)))
                    .font(.system(size: 11))
                    .foregroundColor(ModernColors.textTertiary)
            }
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        switch selectedItem {
        case .dashboard:
            DashboardView()
        case .meetings:
            MeetingsView()
        case .people:
            PeopleView()
        case .actionItems:
            ActionItemsView()
        case .goals:
            GoalsView()
        case .insights:
            AIInsightsView()
        case .templates:
            TemplatesView()
        case .feedback:
            FeedbackView()
        case .careers:
            CareerView()
        case .okrs:
            OKRView()
        case .recordings:
            RecordingsView()
        case .search:
            SearchView()
        case .teamInsights:
            TeamInsightsView()
        case .integrations:
            IntegrationsView()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(DataStore.shared)
        .environmentObject(CalendarService.shared)
        .environmentObject(SyncService.shared)
}
