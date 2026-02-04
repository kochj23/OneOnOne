//
//  PeopleView.swift
//  OneOnOne
//
//  View for managing people/contacts
//  Created by Jordan Koch on 2026-02-02.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

struct PeopleView: View {
    @EnvironmentObject var dataStore: DataStore
    @State private var searchText = ""
    @State private var selectedPerson: Person?
    @State private var showNewPerson = false

    var filteredPeople: [Person] {
        if searchText.isEmpty {
            return dataStore.people.sorted { $0.name < $1.name }
        }
        return dataStore.people.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            ($0.title?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            ($0.department?.localizedCaseInsensitiveContains(searchText) ?? false)
        }.sorted { $0.name < $1.name }
    }

    var body: some View {
        #if os(macOS)
        HSplitView {
            // People list
            peopleList
                .frame(minWidth: 350, maxWidth: 450)

            // Person detail
            if let person = selectedPerson {
                PersonDetailView(person: binding(for: person))
            } else {
                emptyDetailView
            }
        }
        .sheet(isPresented: $showNewPerson) {
            NewPersonView()
        }
        #else
        NavigationStack {
            List(filteredPeople) { person in
                NavigationLink(value: person) {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 40, height: 40)
                            .overlay(
                                Text(String(person.name.prefix(1)))
                                    .font(.headline)
                                    .foregroundColor(.white)
                            )
                        VStack(alignment: .leading) {
                            Text(person.name)
                                .font(.headline)
                            if let title = person.title {
                                Text(title)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("People")
            .navigationDestination(for: Person.self) { person in
                PersonDetailView(person: binding(for: person))
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showNewPerson = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showNewPerson) {
            NewPersonView()
        }
        #endif
    }

    // MARK: - People List

    private var peopleList: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("People")
                        .modernHeader(size: .large)

                    Spacer()

                    Button {
                        showNewPerson = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                            Text("Add")
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(ModernColors.purple)
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }

                // Search
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(ModernColors.textTertiary)

                    TextField("Search people...", text: $searchText)
                        .textFieldStyle(.plain)
                        .foregroundColor(ModernColors.textPrimary)
                }
                .padding(12)
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)

                Text("\(filteredPeople.count) people")
                    .font(.system(size: 13))
                    .foregroundColor(ModernColors.textTertiary)
            }
            .padding(20)

            Divider()
                .background(ModernColors.glassBorder)

            // List
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(filteredPeople) { person in
                        personRow(person)
                            .onTapGesture {
                                selectedPerson = person
                            }
                    }
                }
                .padding(16)
            }
        }
        .background(Color.black.opacity(0.2))
    }

    private func personRow(_ person: Person) -> some View {
        HStack(spacing: 14) {
            // Avatar
            Text(person.initials)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(Color(hex: person.avatarColor))
                .cornerRadius(22)

            VStack(alignment: .leading, spacing: 2) {
                Text(person.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ModernColors.textPrimary)

                if !person.displayTitle.isEmpty {
                    Text(person.displayTitle)
                        .font(.system(size: 13))
                        .foregroundColor(ModernColors.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Last meeting indicator
            if let lastMeeting = person.lastMeetingDate {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Last met")
                        .font(.system(size: 11))
                        .foregroundColor(ModernColors.textTertiary)

                    Text(lastMeeting.formatted(.relative(presentation: .named)))
                        .font(.system(size: 12))
                        .foregroundColor(ModernColors.textSecondary)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(selectedPerson?.id == person.id ? ModernColors.purple.opacity(0.15) : Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(selectedPerson?.id == person.id ? ModernColors.purple.opacity(0.5) : Color.clear, lineWidth: 1)
                )
        )
    }

    private var emptyDetailView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2")
                .font(.system(size: 48))
                .foregroundColor(ModernColors.textTertiary)

            Text("Select a person")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(ModernColors.textSecondary)

            Text("Choose someone from the list to view their profile")
                .font(.system(size: 14))
                .foregroundColor(ModernColors.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func binding(for person: Person) -> Binding<Person> {
        Binding(
            get: {
                dataStore.people.first { $0.id == person.id } ?? person
            },
            set: { newValue in
                dataStore.updatePerson(newValue)
            }
        )
    }
}

// MARK: - Person Detail View

struct PersonDetailView: View {
    @Binding var person: Person
    @EnvironmentObject var dataStore: DataStore
    @State private var showDeleteConfirmation = false

    var meetings: [Meeting] {
        dataStore.meetings(for: person.id)
    }

    var actionItems: [ActionItem] {
        dataStore.actionItems(for: person.id)
    }

    var goals: [Goal] {
        dataStore.goals(for: person.id)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                profileHeader

                // Info cards
                HStack(alignment: .top, spacing: 20) {
                    contactInfoCard
                    meetingStatsCard
                }

                // Meeting history
                meetingHistoryCard

                // Action items
                actionItemsCard

                // Goals
                goalsCard

                // Notes
                notesCard

                // Delete button
                deleteButton
            }
            .padding(32)
        }
        .alert("Delete Person", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                dataStore.deletePerson(id: person.id)
            }
        } message: {
            Text("Are you sure you want to delete \(person.name)? This cannot be undone.")
        }
    }

    private var profileHeader: some View {
        HStack(spacing: 20) {
            // Large avatar
            Text(person.initials)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 80, height: 80)
                .background(Color(hex: person.avatarColor))
                .cornerRadius(40)

            VStack(alignment: .leading, spacing: 4) {
                Text(person.name)
                    .modernHeader(size: .large)

                if !person.displayTitle.isEmpty {
                    Text(person.displayTitle)
                        .font(.system(size: 16))
                        .foregroundColor(ModernColors.textSecondary)
                }

                // Tags
                if !person.tags.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(person.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 12))
                                .foregroundColor(ModernColors.textSecondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(10)
                        }
                    }
                }
            }

            Spacer()

            // Meeting frequency badge
            VStack(alignment: .trailing, spacing: 4) {
                Text(person.meetingFrequency.rawValue)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ModernColors.purple)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(ModernColors.purple.opacity(0.2))
                    .cornerRadius(10)

                Text("meeting frequency")
                    .font(.system(size: 11))
                    .foregroundColor(ModernColors.textTertiary)
            }
        }
    }

    private var contactInfoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Contact Info")
                .modernHeader(size: .small)

            if let email = person.email {
                HStack(spacing: 10) {
                    Image(systemName: "envelope")
                        .foregroundColor(ModernColors.textTertiary)
                    Text(email)
                        .font(.system(size: 14))
                        .foregroundColor(ModernColors.textPrimary)
                }
            }

            if let title = person.title {
                HStack(spacing: 10) {
                    Image(systemName: "briefcase")
                        .foregroundColor(ModernColors.textTertiary)
                    Text(title)
                        .font(.system(size: 14))
                        .foregroundColor(ModernColors.textPrimary)
                }
            }

            if let department = person.department {
                HStack(spacing: 10) {
                    Image(systemName: "building.2")
                        .foregroundColor(ModernColors.textTertiary)
                    Text(department)
                        .font(.system(size: 14))
                        .foregroundColor(ModernColors.textPrimary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var meetingStatsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Meeting Stats")
                .modernHeader(size: .small)

            HStack(spacing: 24) {
                VStack(spacing: 4) {
                    Text("\(meetings.count)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(ModernColors.accentBlue)
                    Text("Total")
                        .font(.system(size: 12))
                        .foregroundColor(ModernColors.textTertiary)
                }

                VStack(spacing: 4) {
                    Text("\(actionItems.filter { !$0.isCompleted }.count)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(ModernColors.orange)
                    Text("Tasks")
                        .font(.system(size: 12))
                        .foregroundColor(ModernColors.textTertiary)
                }

                VStack(spacing: 4) {
                    Text("\(goals.count)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(ModernColors.accentGreen)
                    Text("Goals")
                        .font(.system(size: 12))
                        .foregroundColor(ModernColors.textTertiary)
                }
            }

            if let lastMeeting = person.lastMeetingDate {
                HStack(spacing: 8) {
                    Image(systemName: "clock")
                        .foregroundColor(ModernColors.textTertiary)
                    Text("Last met: \(lastMeeting.formatted(.relative(presentation: .named)))")
                        .font(.system(size: 13))
                        .foregroundColor(ModernColors.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var meetingHistoryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Meeting History")
                    .modernHeader(size: .small)

                Spacer()

                Text("\(meetings.count) meetings")
                    .font(.system(size: 13))
                    .foregroundColor(ModernColors.textTertiary)
            }

            if meetings.isEmpty {
                Text("No meetings yet")
                    .font(.system(size: 14))
                    .foregroundColor(ModernColors.textTertiary)
            } else {
                ForEach(meetings.prefix(5)) { meeting in
                    HStack(spacing: 12) {
                        Image(systemName: meeting.meetingType.icon)
                            .foregroundColor(ModernColors.accentBlue)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(meeting.title)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(ModernColors.textPrimary)

                            Text(meeting.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 12))
                                .foregroundColor(ModernColors.textTertiary)
                        }

                        Spacer()

                        if meeting.openActionItemsCount > 0 {
                            Text("\(meeting.openActionItemsCount) tasks")
                                .font(.system(size: 12))
                                .foregroundColor(ModernColors.orange)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .glassCard()
    }

    private var actionItemsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Open Tasks")
                .modernHeader(size: .small)

            let openItems = actionItems.filter { !$0.isCompleted }
            if openItems.isEmpty {
                Text("All tasks completed!")
                    .font(.system(size: 14))
                    .foregroundColor(ModernColors.textTertiary)
            } else {
                ForEach(openItems.prefix(5)) { item in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(Color(hex: item.priority.color))
                            .frame(width: 8, height: 8)

                        Text(item.title)
                            .font(.system(size: 14))
                            .foregroundColor(ModernColors.textPrimary)
                            .lineLimit(1)

                        Spacer()

                        if let dueDate = item.dueDate {
                            Text(dueDate.formatted(date: .abbreviated, time: .omitted))
                                .font(.system(size: 12))
                                .foregroundColor(item.isOverdue ? ModernColors.statusCritical : ModernColors.textTertiary)
                        }
                    }
                }
            }
        }
        .glassCard()
    }

    private var goalsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Goals")
                .modernHeader(size: .small)

            if goals.isEmpty {
                Text("No goals assigned")
                    .font(.system(size: 14))
                    .foregroundColor(ModernColors.textTertiary)
            } else {
                ForEach(goals) { goal in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: goal.category.icon)
                                .foregroundColor(Color(hex: goal.category.color))

                            Text(goal.title)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(ModernColors.textPrimary)

                            Spacer()

                            Text("\(Int(goal.progress * 100))%")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Color(hex: goal.status.color))
                        }

                        // Progress bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.white.opacity(0.1))

                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color(hex: goal.category.color))
                                    .frame(width: geometry.size.width * goal.progress)
                            }
                        }
                        .frame(height: 4)
                    }
                }
            }
        }
        .glassCard()
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Notes")
                .modernHeader(size: .small)

            TextEditor(text: Binding(
                get: { person.notes ?? "" },
                set: { person.notes = $0.isEmpty ? nil : $0 }
            ))
            .font(.system(size: 14))
            .foregroundColor(ModernColors.textPrimary)
            .scrollContentBackground(.hidden)
            .frame(minHeight: 100)
            .padding(12)
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
        }
        .glassCard()
    }

    private var deleteButton: some View {
        Button {
            showDeleteConfirmation = true
        } label: {
            HStack {
                Image(systemName: "trash")
                Text("Delete Person")
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(ModernColors.statusCritical)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PeopleView()
        .environmentObject(DataStore.shared)
}
