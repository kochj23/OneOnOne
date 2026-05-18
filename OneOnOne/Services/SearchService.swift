//
//  SearchService.swift
//  OneOnOne
//
//  Full-text search across meetings, notes, and all content
//  Created by Jordan Koch on 2026-02-02.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation

@MainActor
class SearchService: ObservableObject {
    static let shared = SearchService()

    @Published var searchResults: [SearchResult] = []
    @Published var isSearching = false
    @Published var recentSearches: [String] = []

    private let maxRecentSearches = 10

    private init() {
        loadRecentSearches()
    }

    // MARK: - Search

    func search(query: String, filters: SearchFilters = SearchFilters()) async -> [SearchResult] {
        guard !query.isEmpty else {
            searchResults = []
            return []
        }

        isSearching = true
        defer { isSearching = false }

        var results: [SearchResult] = []
        let lowercaseQuery = query.lowercased()
        let dataStore = DataStore.shared

        // Search meetings
        if filters.includeMeetings {
            for meeting in dataStore.meetings {
                var matches: [SearchMatch] = []

                // Title
                if meeting.title.lowercased().contains(lowercaseQuery) {
                    matches.append(SearchMatch(field: "title", text: meeting.title, highlight: highlightText(meeting.title, query: lowercaseQuery)))
                }

                // Notes
                if meeting.notes.lowercased().contains(lowercaseQuery) {
                    matches.append(SearchMatch(field: "notes", text: meeting.notes, highlight: highlightText(meeting.notes, query: lowercaseQuery)))
                }

                // Agenda
                if let agenda = meeting.agenda, agenda.lowercased().contains(lowercaseQuery) {
                    matches.append(SearchMatch(field: "agenda", text: agenda, highlight: highlightText(agenda, query: lowercaseQuery)))
                }

                // Summary
                if let summary = meeting.summary, summary.lowercased().contains(lowercaseQuery) {
                    matches.append(SearchMatch(field: "summary", text: summary, highlight: highlightText(summary, query: lowercaseQuery)))
                }

                // Action items
                for item in meeting.actionItems {
                    if item.title.lowercased().contains(lowercaseQuery) {
                        matches.append(SearchMatch(field: "action_item", text: item.title, highlight: highlightText(item.title, query: lowercaseQuery)))
                    }
                }

                // Decisions
                for decision in meeting.decisions {
                    if decision.title.lowercased().contains(lowercaseQuery) {
                        matches.append(SearchMatch(field: "decision", text: decision.title, highlight: highlightText(decision.title, query: lowercaseQuery)))
                    }
                }

                if !matches.isEmpty {
                    results.append(SearchResult(
                        type: .meeting,
                        id: meeting.id,
                        title: meeting.title,
                        subtitle: meeting.date.formatted(date: .abbreviated, time: .shortened),
                        matches: matches,
                        date: meeting.date,
                        relevanceScore: calculateRelevance(matches: matches, query: lowercaseQuery)
                    ))
                }
            }
        }

        // Search people
        if filters.includePeople {
            for person in dataStore.people {
                var matches: [SearchMatch] = []

                if person.name.lowercased().contains(lowercaseQuery) {
                    matches.append(SearchMatch(field: "name", text: person.name, highlight: highlightText(person.name, query: lowercaseQuery)))
                }

                if let title = person.title, title.lowercased().contains(lowercaseQuery) {
                    matches.append(SearchMatch(field: "title", text: title, highlight: highlightText(title, query: lowercaseQuery)))
                }

                if let notes = person.notes, notes.lowercased().contains(lowercaseQuery) {
                    matches.append(SearchMatch(field: "notes", text: notes, highlight: highlightText(notes, query: lowercaseQuery)))
                }

                if !matches.isEmpty {
                    results.append(SearchResult(
                        type: .person,
                        id: person.id,
                        title: person.name,
                        subtitle: person.displayTitle,
                        matches: matches,
                        date: person.createdAt,
                        relevanceScore: calculateRelevance(matches: matches, query: lowercaseQuery)
                    ))
                }
            }
        }

        // Search goals
        if filters.includeGoals {
            for goal in dataStore.goals {
                var matches: [SearchMatch] = []

                if goal.title.lowercased().contains(lowercaseQuery) {
                    matches.append(SearchMatch(field: "title", text: goal.title, highlight: highlightText(goal.title, query: lowercaseQuery)))
                }

                if let desc = goal.description, desc.lowercased().contains(lowercaseQuery) {
                    matches.append(SearchMatch(field: "description", text: desc, highlight: highlightText(desc, query: lowercaseQuery)))
                }

                for milestone in goal.milestones {
                    if milestone.title.lowercased().contains(lowercaseQuery) {
                        matches.append(SearchMatch(field: "milestone", text: milestone.title, highlight: highlightText(milestone.title, query: lowercaseQuery)))
                    }
                }

                if !matches.isEmpty {
                    results.append(SearchResult(
                        type: .goal,
                        id: goal.id,
                        title: goal.title,
                        subtitle: goal.category.rawValue,
                        matches: matches,
                        date: goal.createdAt,
                        relevanceScore: calculateRelevance(matches: matches, query: lowercaseQuery)
                    ))
                }
            }
        }

        // Sort by relevance
        results.sort { $0.relevanceScore > $1.relevanceScore }

        // Apply date filter
        if let startDate = filters.startDate {
            results = results.filter { $0.date >= startDate }
        }
        if let endDate = filters.endDate {
            results = results.filter { $0.date <= endDate }
        }

        searchResults = results
        addRecentSearch(query)

        return results
    }

    // MARK: - Quick Queries

    func findLastDiscussion(about topic: String) async -> SearchResult? {
        let results = await search(query: topic, filters: SearchFilters(includeMeetings: true, includePeople: false, includeGoals: false))
        return results.first
    }

    func findDecisionsAbout(topic: String) async -> [SearchResult] {
        let results = await search(query: topic)
        return results.filter { result in
            result.matches.contains { $0.field == "decision" }
        }
    }

    func findActionItemsAbout(topic: String) async -> [SearchResult] {
        let results = await search(query: topic)
        return results.filter { result in
            result.matches.contains { $0.field == "action_item" }
        }
    }

    // MARK: - Helpers

    private func highlightText(_ text: String, query: String, contextLength: Int = 50) -> String {
        guard let range = text.lowercased().range(of: query) else {
            return String(text.prefix(contextLength * 2))
        }

        let startIndex = text.index(range.lowerBound, offsetBy: -min(contextLength, text.distance(from: text.startIndex, to: range.lowerBound)), limitedBy: text.startIndex) ?? text.startIndex
        let endIndex = text.index(range.upperBound, offsetBy: min(contextLength, text.distance(from: range.upperBound, to: text.endIndex)), limitedBy: text.endIndex) ?? text.endIndex

        var result = String(text[startIndex..<endIndex])
        if startIndex != text.startIndex { result = "..." + result }
        if endIndex != text.endIndex { result = result + "..." }

        return result
    }

    private func calculateRelevance(matches: [SearchMatch], query: String) -> Double {
        var score = 0.0

        for match in matches {
            // Weight by field importance
            switch match.field {
            case "title", "name":
                score += 10.0
            case "decision":
                score += 8.0
            case "action_item":
                score += 7.0
            case "notes", "description":
                score += 5.0
            default:
                score += 3.0
            }

            // Exact match bonus
            if match.text.lowercased() == query {
                score += 5.0
            }
        }

        return score
    }

    // MARK: - Recent Searches

    private func addRecentSearch(_ query: String) {
        recentSearches.removeAll { $0 == query }
        recentSearches.insert(query, at: 0)
        if recentSearches.count > maxRecentSearches {
            recentSearches = Array(recentSearches.prefix(maxRecentSearches))
        }
        saveRecentSearches()
    }

    func clearRecentSearches() {
        recentSearches = []
        saveRecentSearches()
    }

    private func saveRecentSearches() {
        UserDefaults.standard.set(recentSearches, forKey: "RecentSearches")
    }

    private func loadRecentSearches() {
        recentSearches = UserDefaults.standard.stringArray(forKey: "RecentSearches") ?? []
    }
}

// MARK: - Search Models

struct SearchResult: Identifiable {
    let id: UUID
    let type: SearchResultType
    let title: String
    let subtitle: String
    let matches: [SearchMatch]
    let date: Date
    let relevanceScore: Double

    init(type: SearchResultType, id: UUID, title: String, subtitle: String, matches: [SearchMatch], date: Date, relevanceScore: Double) {
        self.id = UUID()
        self.type = type
        self.title = title
        self.subtitle = subtitle
        self.matches = matches
        self.date = date
        self.relevanceScore = relevanceScore
    }
}

enum SearchResultType: String {
    case meeting = "Meeting"
    case person = "Person"
    case goal = "Goal"
    case feedback = "Feedback"
    case okr = "OKR"

    var icon: String {
        switch self {
        case .meeting: return "calendar"
        case .person: return "person"
        case .goal: return "target"
        case .feedback: return "star"
        case .okr: return "chart.bar"
        }
    }

    var color: String {
        switch self {
        case .meeting: return "#3BDAFC"
        case .person: return "#9966FF"
        case .goal: return "#4DE094"
        case .feedback: return "#FFD700"
        case .okr: return "#FF9933"
        }
    }
}

struct SearchMatch {
    let field: String
    let text: String
    let highlight: String
}

struct SearchFilters {
    var includeMeetings: Bool = true
    var includePeople: Bool = true
    var includeGoals: Bool = true
    var includeFeedback: Bool = true
    var includeOKRs: Bool = true
    var startDate: Date?
    var endDate: Date?
}
