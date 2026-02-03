//
//  ContentView.swift
//  OneOnOne
//
//  Main content view with sidebar navigation
//  Created by Jordan Koch on 2026-02-02.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

enum SidebarItem: String, CaseIterable {
    case dashboard = "Dashboard"
    case meetings = "Meetings"
    case people = "People"
    case actionItems = "Action Items"
    case goals = "Goals"
    case insights = "AI Insights"

    var icon: String {
        switch self {
        case .dashboard: return "square.grid.2x2"
        case .meetings: return "calendar"
        case .people: return "person.2"
        case .actionItems: return "checklist"
        case .goals: return "target"
        case .insights: return "sparkles"
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
        }
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
                VStack(spacing: 8) {
                    ForEach(SidebarItem.allCases, id: \.self) { item in
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
                    .font(.system(size: 18))
                    .frame(width: 24)

                Text(item.rawValue)
                    .font(.system(size: 15, weight: selectedItem == item ? .semibold : .medium))

                Spacer()

                // Badge for action items
                if item == .actionItems {
                    let count = dataStore.openActionItems().count
                    if count > 0 {
                        Text("\(count)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(ModernColors.orange)
                            .cornerRadius(10)
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

            HStack(spacing: 16) {
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
                    value: dataStore.activeGoals().count,
                    label: "Goals",
                    color: ModernColors.accentGreen
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
                .font(.system(size: 20, weight: .bold, design: .rounded))
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
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(DataStore.shared)
        .environmentObject(CalendarService.shared)
        .environmentObject(SyncService.shared)
}
