//
//  SearchView.swift
//  OneOnOne
//
//  Global search and knowledge base view
//  Created by Jordan Koch on 2026-02-02.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

struct SearchView: View {
    @EnvironmentObject var dataStore: DataStore
    @StateObject private var searchService = SearchService.shared
    @State private var searchText = ""
    @State private var filters = SearchFilters()
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header with search
            header
                .padding(24)

            Divider()
                .background(ModernColors.glassBorder)

            // Content
            HStack(spacing: 0) {
                // Results
                resultsView
                    .frame(maxWidth: .infinity)

                Divider()
                    .background(ModernColors.glassBorder)

                // Filters sidebar
                filtersSidebar
                    .frame(width: 260)
            }
        }
        .onAppear {
            isSearchFocused = true
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Search")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(ModernColors.textPrimary)

                    Text("Find meetings, notes, decisions, and action items")
                        .font(.system(size: 14))
                        .foregroundColor(ModernColors.textSecondary)
                }

                Spacer()
            }

            // Search bar
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18))
                    .foregroundColor(ModernColors.textTertiary)

                TextField("Search everything...", text: $searchText)
                    .font(.system(size: 16))
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
                    .onSubmit {
                        performSearch()
                    }

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        searchService.searchResults = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(ModernColors.textTertiary)
                    }
                    .buttonStyle(.plain)
                }

                if searchService.isSearching {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
        }
    }

    // MARK: - Results View

    private var resultsView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if searchText.isEmpty {
                    recentSearchesView
                } else if searchService.searchResults.isEmpty && !searchService.isSearching {
                    noResultsView
                } else {
                    // Results count
                    HStack {
                        Text("\(searchService.searchResults.count) results")
                            .font(.system(size: 14))
                            .foregroundColor(ModernColors.textTertiary)
                        Spacer()
                    }
                    .padding(.bottom, 8)

                    // Results list
                    ForEach(searchService.searchResults) { result in
                        SearchResultRow(result: result)
                    }
                }
            }
            .padding(24)
        }
    }

    private var recentSearchesView: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !searchService.recentSearches.isEmpty {
                HStack {
                    Text("Recent Searches")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(ModernColors.textSecondary)

                    Spacer()

                    Button("Clear") {
                        searchService.clearRecentSearches()
                    }
                    .font(.system(size: 12))
                    .foregroundColor(ModernColors.textTertiary)
                    .buttonStyle(.plain)
                }

                ForEach(searchService.recentSearches, id: \.self) { query in
                    Button {
                        searchText = query
                        performSearch()
                    } label: {
                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(ModernColors.textTertiary)
                            Text(query)
                                .foregroundColor(ModernColors.textSecondary)
                            Spacer()
                            Image(systemName: "arrow.up.left")
                                .foregroundColor(ModernColors.textTertiary)
                        }
                        .padding(12)
                        .background(Color.white.opacity(0.03))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Quick queries
            VStack(alignment: .leading, spacing: 12) {
                Text("Quick Queries")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ModernColors.textSecondary)

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    quickQueryButton("Recent decisions", icon: "checkmark.seal", color: ModernColors.accentGreen)
                    quickQueryButton("Open action items", icon: "checklist", color: ModernColors.orange)
                    quickQueryButton("Performance reviews", icon: "chart.bar", color: ModernColors.purple)
                    quickQueryButton("Career goals", icon: "target", color: ModernColors.cyan)
                }
            }
            .padding(.top, 24)
        }
    }

    private func quickQueryButton(_ title: String, icon: String, color: Color) -> some View {
        Button {
            searchText = title
            performSearch()
        } label: {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 13))
                    .foregroundColor(ModernColors.textSecondary)
                Spacer()
            }
            .padding(12)
            .background(Color.white.opacity(0.03))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    private var noResultsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(ModernColors.textTertiary)

            Text("No results found")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(ModernColors.textSecondary)

            Text("Try adjusting your search or filters")
                .font(.system(size: 14))
                .foregroundColor(ModernColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(60)
    }

    // MARK: - Filters Sidebar

    private var filtersSidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Content types
                VStack(alignment: .leading, spacing: 12) {
                    Text("Search In")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(ModernColors.textSecondary)

                    filterToggle("Meetings", icon: "calendar", isOn: $filters.includeMeetings, color: ModernColors.cyan)
                    filterToggle("People", icon: "person.2", isOn: $filters.includePeople, color: ModernColors.purple)
                    filterToggle("Goals", icon: "target", isOn: $filters.includeGoals, color: ModernColors.accentGreen)
                }
                .padding(16)
                .glassCard()

                // Date range
                VStack(alignment: .leading, spacing: 12) {
                    Text("Date Range")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(ModernColors.textSecondary)

                    dateRangeButton("All time", startDate: nil, endDate: nil)
                    dateRangeButton("Past week", startDate: Calendar.current.date(byAdding: .day, value: -7, to: Date()), endDate: nil)
                    dateRangeButton("Past month", startDate: Calendar.current.date(byAdding: .month, value: -1, to: Date()), endDate: nil)
                    dateRangeButton("Past 3 months", startDate: Calendar.current.date(byAdding: .month, value: -3, to: Date()), endDate: nil)
                    dateRangeButton("Past year", startDate: Calendar.current.date(byAdding: .year, value: -1, to: Date()), endDate: nil)
                }
                .padding(16)
                .glassCard()

                // Search tips
                VStack(alignment: .leading, spacing: 12) {
                    Text("Search Tips")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(ModernColors.textSecondary)

                    VStack(alignment: .leading, spacing: 8) {
                        tipRow("Use specific keywords")
                        tipRow("Search for names or topics")
                        tipRow("Filter by date range")
                        tipRow("Check all content types")
                    }
                }
                .padding(16)
                .glassCard()
            }
            .padding(20)
        }
        .background(Color.black.opacity(0.2))
    }

    private func filterToggle(_ title: String, icon: String, isOn: Binding<Bool>, color: Color) -> some View {
        Toggle(isOn: isOn) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 20)
                Text(title)
                    .font(.system(size: 13))
                    .foregroundColor(ModernColors.textSecondary)
            }
        }
        .toggleStyle(.switch)
        .onChange(of: isOn.wrappedValue) { _, _ in
            if !searchText.isEmpty {
                performSearch()
            }
        }
    }

    private func dateRangeButton(_ title: String, startDate: Date?, endDate: Date?) -> some View {
        let isSelected = filters.startDate == startDate && filters.endDate == endDate

        return Button {
            filters.startDate = startDate
            filters.endDate = endDate
            if !searchText.isEmpty {
                performSearch()
            }
        } label: {
            HStack {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundColor(isSelected ? ModernColors.cyan : ModernColors.textSecondary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(ModernColors.cyan)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    private func tipRow(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "lightbulb")
                .font(.system(size: 11))
                .foregroundColor(ModernColors.orange)
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(ModernColors.textTertiary)
        }
    }

    // MARK: - Actions

    private func performSearch() {
        Task {
            await searchService.search(query: searchText, filters: filters)
        }
    }
}

// MARK: - Search Result Row

struct SearchResultRow: View {
    let result: SearchResult
    @EnvironmentObject var dataStore: DataStore

    var body: some View {
        Button {
            // Navigate to result (would need navigation system)
        } label: {
            HStack(spacing: 16) {
                // Type icon
                Image(systemName: result.type.icon)
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: result.type.color))
                    .frame(width: 44, height: 44)
                    .background(Color(hex: result.type.color).opacity(0.15))
                    .cornerRadius(12)

                // Content
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(result.type.rawValue)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color(hex: result.type.color))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color(hex: result.type.color).opacity(0.15))
                            .cornerRadius(4)

                        Spacer()

                        Text(result.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.system(size: 12))
                            .foregroundColor(ModernColors.textTertiary)
                    }

                    Text(result.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(ModernColors.textPrimary)
                        .lineLimit(1)

                    Text(result.subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(ModernColors.textSecondary)

                    // Matches
                    if let firstMatch = result.matches.first {
                        Text(firstMatch.highlight)
                            .font(.system(size: 12))
                            .foregroundColor(ModernColors.textTertiary)
                            .lineLimit(2)
                            .padding(8)
                            .background(Color.white.opacity(0.03))
                            .cornerRadius(6)
                    }
                }

                Image(systemName: "chevron.right")
                    .foregroundColor(ModernColors.textTertiary)
            }
            .padding(16)
            .glassCard()
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SearchView()
        .environmentObject(DataStore.shared)
}
