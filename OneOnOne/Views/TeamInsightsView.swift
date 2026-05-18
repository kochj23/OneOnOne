//
//  TeamInsightsView.swift
//  OneOnOne
//
//  Team-level analytics and insights dashboard
//  Created by Jordan Koch on 2026-02-02.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

struct TeamInsightsView: View {
    @EnvironmentObject var dataStore: DataStore
    @StateObject private var insightsService = TeamInsightsService.shared

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
                    // Top row - Key metrics
                    keyMetricsRow

                    // Middle row - Charts and trends
                    HStack(spacing: 20) {
                        meetingTrendsCard
                        meetingsByTypeCard
                    }

                    // Bottom row - People insights
                    HStack(spacing: 20) {
                        peopleNeedingAttentionCard
                        topPerformersCard
                        actionItemsCard
                    }
                }
                .padding(24)
            }
        }
        .onAppear {
            Task {
                await insightsService.generateInsights()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Team Insights")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(ModernColors.textPrimary)

                Text("Analytics and trends across your team")
                    .font(.system(size: 14))
                    .foregroundColor(ModernColors.textSecondary)
            }

            Spacer()

            if insightsService.isLoading {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Button {
                    Task {
                        await insightsService.generateInsights()
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .font(.system(size: 14))
                        .foregroundColor(ModernColors.textSecondary)
                }
                .buttonStyle(.plain)
            }

            if let insights = insightsService.insights {
                Text("Updated \(insights.generatedAt.formatted(.relative(presentation: .named)))")
                    .font(.system(size: 12))
                    .foregroundColor(ModernColors.textTertiary)
            }
        }
    }

    // MARK: - Key Metrics Row

    private var keyMetricsRow: some View {
        HStack(spacing: 20) {
            metricCard(
                title: "Total People",
                value: "\(insightsService.insights?.totalPeople ?? dataStore.people.count)",
                icon: "person.2.fill",
                color: ModernColors.purple
            )

            metricCard(
                title: "Meetings This Week",
                value: "\(insightsService.insights?.totalMeetingsThisWeek ?? 0)",
                icon: "calendar",
                color: ModernColors.cyan
            )

            metricCard(
                title: "Meetings This Month",
                value: "\(insightsService.insights?.totalMeetingsThisMonth ?? 0)",
                icon: "calendar.badge.clock",
                color: ModernColors.accentBlue
            )

            metricCard(
                title: "Open Action Items",
                value: "\(insightsService.insights?.openActionItems ?? 0)",
                icon: "checklist",
                color: ModernColors.orange
            )

            metricCard(
                title: "Overdue Items",
                value: "\(insightsService.insights?.overdueActionItems ?? 0)",
                icon: "exclamationmark.triangle.fill",
                color: ModernColors.red
            )
        }
    }

    private func metricCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
                Spacer()
            }

            HStack {
                Text(value)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(ModernColors.textPrimary)
                Spacer()
            }

            HStack {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundColor(ModernColors.textSecondary)
                Spacer()
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .glassCard()
    }

    // MARK: - Meeting Trends Card

    private var meetingTrendsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Meeting Trends")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ModernColors.textPrimary)

                Spacer()

                if let insights = insightsService.insights {
                    HStack(spacing: 4) {
                        Image(systemName: trendIcon(insights.meetingTrend))
                            .foregroundColor(trendColor(insights.meetingTrend))
                        Text(insights.meetingTrend.capitalized)
                            .font(.system(size: 12))
                            .foregroundColor(trendColor(insights.meetingTrend))
                    }
                }
            }

            if let insights = insightsService.insights {
                // Bar chart representation
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(Array(insights.weeklyMeetingCounts.enumerated()), id: \.offset) { index, count in
                        VStack(spacing: 4) {
                            Text("\(count)")
                                .font(.system(size: 11))
                                .foregroundColor(ModernColors.textTertiary)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(ModernColors.cyan)
                                .frame(height: CGFloat(count) * 8 + 10)
                                .frame(maxWidth: .infinity)

                            Text("W\(index + 1)")
                                .font(.system(size: 10))
                                .foregroundColor(ModernColors.textTertiary)
                        }
                    }
                }
                .frame(height: 100)

                HStack {
                    Text("Avg: \(String(format: "%.1f", insights.averageMeetingsPerWeek)) meetings/week")
                        .font(.system(size: 12))
                        .foregroundColor(ModernColors.textTertiary)
                    Spacer()
                }
            } else {
                Text("No data available")
                    .font(.system(size: 14))
                    .foregroundColor(ModernColors.textTertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .frame(height: 200)
        .glassCard()
    }

    private func trendIcon(_ trend: String) -> String {
        switch trend {
        case "increasing": return "arrow.up.right"
        case "decreasing": return "arrow.down.right"
        default: return "arrow.right"
        }
    }

    private func trendColor(_ trend: String) -> Color {
        switch trend {
        case "increasing": return ModernColors.accentGreen
        case "decreasing": return ModernColors.red
        default: return ModernColors.textTertiary
        }
    }

    // MARK: - Meetings by Type Card

    private var meetingsByTypeCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Meetings by Type")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(ModernColors.textPrimary)

            if let insights = insightsService.insights {
                let sortedTypes = insights.meetingsByType.sorted { $0.value > $1.value }
                let total = Double(sortedTypes.map { $0.value }.reduce(0, +))

                VStack(spacing: 12) {
                    ForEach(sortedTypes, id: \.key) { type, count in
                        HStack {
                            Circle()
                                .fill(typeColor(type))
                                .frame(width: 10, height: 10)

                            Text(type.rawValue)
                                .font(.system(size: 13))
                                .foregroundColor(ModernColors.textSecondary)

                            Spacer()

                            Text("\(count)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(ModernColors.textPrimary)

                            Text("(\(Int(Double(count) / max(total, 1) * 100))%)")
                                .font(.system(size: 11))
                                .foregroundColor(ModernColors.textTertiary)
                        }

                        // Progress bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.white.opacity(0.1))
                                    .frame(height: 4)

                                RoundedRectangle(cornerRadius: 2)
                                    .fill(typeColor(type))
                                    .frame(width: geo.size.width * CGFloat(Double(count) / max(total, 1)), height: 4)
                            }
                        }
                        .frame(height: 4)
                    }
                }
            } else {
                Text("No data available")
                    .font(.system(size: 14))
                    .foregroundColor(ModernColors.textTertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .frame(height: 200)
        .glassCard()
    }

    private func typeColor(_ type: MeetingType) -> Color {
        switch type {
        case .oneOnOne: return ModernColors.cyan
        case .teamMeeting: return ModernColors.purple
        case .standUp: return ModernColors.accentGreen
        case .retrospective: return ModernColors.orange
        case .planning: return ModernColors.accentBlue
        case .review: return ModernColors.pink
        case .brainstorm: return ModernColors.yellow
        case .interview: return ModernColors.teal
        case .training: return ModernColors.accentOrange
        case .other: return ModernColors.textTertiary
        }
    }

    // MARK: - People Needing Attention Card

    private var peopleNeedingAttentionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Needs Attention")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ModernColors.textPrimary)

                Spacer()

                let count = (insightsService.insights?.peopleDueForMeeting.count ?? 0) +
                           (insightsService.insights?.peopleNeverMet.count ?? 0)
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

            let leastActive = insightsService.getLeastActivePeople(limit: 5)

            if leastActive.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 24))
                        .foregroundColor(ModernColors.accentGreen)
                    Text("All caught up!")
                        .font(.system(size: 13))
                        .foregroundColor(ModernColors.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 10) {
                    ForEach(leastActive, id: \.person.id) { item in
                        HStack {
                            Text(item.person.initials)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 28, height: 28)
                                .background(Circle().fill(ModernColors.purple))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.person.name)
                                    .font(.system(size: 13))
                                    .foregroundColor(ModernColors.textPrimary)
                                    .lineLimit(1)

                                Text(item.daysSinceLastMeeting == -1 ? "Never met" : "\(item.daysSinceLastMeeting)d ago")
                                    .font(.system(size: 11))
                                    .foregroundColor(item.daysSinceLastMeeting == -1 ? ModernColors.red : ModernColors.textTertiary)
                            }

                            Spacer()

                            Image(systemName: "exclamationmark.circle")
                                .foregroundColor(item.daysSinceLastMeeting > 30 || item.daysSinceLastMeeting == -1 ? ModernColors.orange : ModernColors.textTertiary)
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .frame(height: 240)
        .glassCard()
    }

    // MARK: - Top Performers Card

    private var topPerformersCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Top Task Completers")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(ModernColors.textPrimary)

            let topPerformers = insightsService.getTopPerformers(limit: 5)

            if topPerformers.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "chart.bar")
                        .font(.system(size: 24))
                        .foregroundColor(ModernColors.textTertiary)
                    Text("No data yet")
                        .font(.system(size: 13))
                        .foregroundColor(ModernColors.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(topPerformers.enumerated()), id: \.element.person.id) { index, item in
                        HStack {
                            Text("\(index + 1)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(index == 0 ? ModernColors.accentGreen : ModernColors.textTertiary)
                                .frame(width: 20)

                            Text(item.person.initials)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 28, height: 28)
                                .background(Circle().fill(ModernColors.accentGreen))

                            Text(item.person.name)
                                .font(.system(size: 13))
                                .foregroundColor(ModernColors.textPrimary)
                                .lineLimit(1)

                            Spacer()

                            Text("\(Int(item.completionRate * 100))%")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(ModernColors.accentGreen)
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .frame(height: 240)
        .glassCard()
    }

    // MARK: - Action Items Card

    private var actionItemsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Action Items")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ModernColors.textPrimary)

                Spacer()

                if let insights = insightsService.insights {
                    Text("\(insights.completedThisWeek) completed this week")
                        .font(.system(size: 11))
                        .foregroundColor(ModernColors.textTertiary)
                }
            }

            if let insights = insightsService.insights {
                VStack(spacing: 16) {
                    // Stats
                    HStack(spacing: 20) {
                        VStack(spacing: 4) {
                            Text("\(insights.openActionItems)")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(ModernColors.orange)
                            Text("Open")
                                .font(.system(size: 11))
                                .foregroundColor(ModernColors.textTertiary)
                        }

                        VStack(spacing: 4) {
                            Text("\(insights.overdueActionItems)")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(ModernColors.red)
                            Text("Overdue")
                                .font(.system(size: 11))
                                .foregroundColor(ModernColors.textTertiary)
                        }

                        VStack(spacing: 4) {
                            Text("\(Int(insights.teamCompletionRate * 100))%")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(ModernColors.accentGreen)
                            Text("Rate")
                                .font(.system(size: 11))
                                .foregroundColor(ModernColors.textTertiary)
                        }
                    }

                    // Busiest day
                    if let busiestDay = insightsService.getBusiestDay() {
                        HStack {
                            Image(systemName: "calendar.badge.clock")
                                .foregroundColor(ModernColors.cyan)
                            Text("Busiest: \(busiestDay.dayName)")
                                .font(.system(size: 12))
                                .foregroundColor(ModernColors.textSecondary)
                            Spacer()
                            Text("\(busiestDay.count) meetings")
                                .font(.system(size: 12))
                                .foregroundColor(ModernColors.textTertiary)
                        }
                        .padding(10)
                        .background(Color.white.opacity(0.03))
                        .cornerRadius(8)
                    }
                }
            } else {
                Text("No data available")
                    .font(.system(size: 14))
                    .foregroundColor(ModernColors.textTertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .frame(height: 240)
        .glassCard()
    }
}

#Preview {
    TeamInsightsView()
        .environmentObject(DataStore.shared)
}
