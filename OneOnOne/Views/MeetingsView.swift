//
//  MeetingsView.swift
//  OneOnOne
//
//  View for managing and browsing meetings
//  Created by Jordan Koch on 2026-02-02.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

struct MeetingsView: View {
    @EnvironmentObject var dataStore: DataStore
    @State private var searchText = ""
    @State private var selectedMeeting: Meeting?
    @State private var showNewMeeting = false
    @State private var filterType: MeetingType?
    @State private var dateFilter: DateFilter = .all

    enum DateFilter: String, CaseIterable {
        case all = "All Time"
        case today = "Today"
        case thisWeek = "This Week"
        case thisMonth = "This Month"
    }

    var filteredMeetings: [Meeting] {
        var meetings = dataStore.meetings

        // Date filter
        let calendar = Calendar.current
        let now = Date()
        switch dateFilter {
        case .all:
            break
        case .today:
            meetings = meetings.filter { calendar.isDateInToday($0.date) }
        case .thisWeek:
            let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            meetings = meetings.filter { $0.date >= weekAgo }
        case .thisMonth:
            let monthAgo = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            meetings = meetings.filter { $0.date >= monthAgo }
        }

        // Type filter
        if let type = filterType {
            meetings = meetings.filter { $0.meetingType == type }
        }

        // Search filter
        if !searchText.isEmpty {
            meetings = meetings.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.notes.localizedCaseInsensitiveContains(searchText)
            }
        }

        return meetings.sorted { $0.date > $1.date }
    }

    var body: some View {
        #if os(macOS)
        HSplitView {
            // Meeting list
            meetingsList
                .frame(minWidth: 400, maxWidth: 500)

            // Meeting detail
            if let meeting = selectedMeeting {
                MeetingDetailView(meeting: binding(for: meeting))
            } else {
                emptyDetailView
            }
        }
        .sheet(isPresented: $showNewMeeting) {
            NewMeetingView()
        }
        #else
        NavigationStack {
            List(filteredMeetings) { meeting in
                NavigationLink(value: meeting) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(meeting.title)
                            .font(.headline)
                        Text(meeting.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Meetings")
            .navigationDestination(for: Meeting.self) { meeting in
                MeetingDetailView(meeting: binding(for: meeting))
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showNewMeeting = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showNewMeeting) {
            NewMeetingView()
        }
        #endif
    }

    // MARK: - Meetings List

    private var meetingsList: some View {
        VStack(spacing: 0) {
            // Header
            listHeader
                .padding(20)

            // Filters
            filtersBar
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

            Divider()
                .background(ModernColors.glassBorder)

            // List
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(filteredMeetings) { meeting in
                        meetingCard(meeting)
                            .onTapGesture {
                                selectedMeeting = meeting
                            }
                    }
                }
                .padding(20)
            }
        }
        .background(Color.black.opacity(0.2))
    }

    private var listHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Meetings")
                    .modernHeader(size: .large)

                Spacer()

                Button {
                    showNewMeeting = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                        Text("New")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(ModernColors.accentBlue)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }

            // Search
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(ModernColors.textTertiary)

                TextField("Search meetings...", text: $searchText)
                    .textFieldStyle(.plain)
                    .foregroundColor(ModernColors.textPrimary)
            }
            .padding(12)
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
        }
    }

    private var filtersBar: some View {
        HStack(spacing: 12) {
            // Date filter
            Menu {
                ForEach(DateFilter.allCases, id: \.self) { filter in
                    Button(filter.rawValue) {
                        dateFilter = filter
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                    Text(dateFilter.rawValue)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))
                }
                .font(.system(size: 13))
                .foregroundColor(ModernColors.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.05))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)

            // Type filter
            Menu {
                Button("All Types") {
                    filterType = nil
                }
                Divider()
                ForEach(MeetingType.allCases, id: \.self) { type in
                    Button {
                        filterType = type
                    } label: {
                        Label(type.rawValue, systemImage: type.icon)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: filterType?.icon ?? "rectangle.3.group")
                    Text(filterType?.rawValue ?? "All Types")
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))
                }
                .font(.system(size: 13))
                .foregroundColor(ModernColors.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.05))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)

            Spacer()

            Text("\(filteredMeetings.count) meetings")
                .font(.system(size: 13))
                .foregroundColor(ModernColors.textTertiary)
        }
    }

    private func meetingCard(_ meeting: Meeting) -> some View {
        HStack(spacing: 16) {
            // Type icon
            Image(systemName: meeting.meetingType.icon)
                .font(.system(size: 20))
                .foregroundColor(ModernColors.accentBlue)
                .frame(width: 44, height: 44)
                .background(ModernColors.accentBlue.opacity(0.2))
                .cornerRadius(12)

            VStack(alignment: .leading, spacing: 4) {
                Text(meeting.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ModernColors.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 12) {
                    Label(meeting.date.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                    Label(meeting.formattedDuration, systemImage: "clock")
                }
                .font(.system(size: 12))
                .foregroundColor(ModernColors.textTertiary)
            }

            Spacer()

            // Attendees
            if !meeting.attendees.isEmpty {
                HStack(spacing: -8) {
                    ForEach(meeting.attendees.prefix(3), id: \.self) { attendeeId in
                        if let person = dataStore.person(for: attendeeId) {
                            Text(person.initials)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 28, height: 28)
                                .background(Color(hex: person.avatarColor))
                                .cornerRadius(14)
                                .overlay(
                                    Circle().stroke(Color.black.opacity(0.3), lineWidth: 2)
                                )
                        }
                    }
                }
            }

            // Action items indicator
            if meeting.openActionItemsCount > 0 {
                Text("\(meeting.openActionItemsCount)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .background(ModernColors.orange)
                    .cornerRadius(12)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(selectedMeeting?.id == meeting.id ? ModernColors.accentBlue.opacity(0.15) : Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(selectedMeeting?.id == meeting.id ? ModernColors.accentBlue.opacity(0.5) : Color.clear, lineWidth: 1)
                )
        )
    }

    // MARK: - Empty Detail View

    private var emptyDetailView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar")
                .font(.system(size: 48))
                .foregroundColor(ModernColors.textTertiary)

            Text("Select a meeting")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(ModernColors.textSecondary)

            Text("Choose a meeting from the list to view details")
                .font(.system(size: 14))
                .foregroundColor(ModernColors.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helper

    private func binding(for meeting: Meeting) -> Binding<Meeting> {
        Binding(
            get: {
                dataStore.meetings.first { $0.id == meeting.id } ?? meeting
            },
            set: { newValue in
                dataStore.updateMeeting(newValue)
            }
        )
    }
}

// MARK: - Meeting Detail View

struct MeetingDetailView: View {
    @Binding var meeting: Meeting
    @EnvironmentObject var dataStore: DataStore
    @State private var isEditingNotes = false
    @State private var showAISummary = false
    @State private var aiSummary: String?
    @State private var isGeneratingSummary = false
    @State private var showAddActionItem = false
    @State private var newActionItemTitle = ""
    @State private var newActionItemPriority: Priority = .medium
    @State private var newActionItemDueDate: Date? = nil
    @State private var newActionItemAssignee: UUID? = nil
    @State private var showDueDatePicker = false
    @State private var aiSummaryError: String? = nil
    @State private var showEditMeeting = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                header

                // Meeting info
                meetingInfoCard

                // Notes
                notesCard

                // Action items
                actionItemsCard

                // Decisions
                if !meeting.decisions.isEmpty {
                    decisionsCard
                }

                // Follow-ups
                if !meeting.followUps.isEmpty {
                    followUpsCard
                }
            }
            .padding(32)
        }
        .sheet(isPresented: $showEditMeeting) {
            EditMeetingView(meeting: $meeting)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: meeting.meetingType.icon)
                    .font(.system(size: 24))
                    .foregroundColor(ModernColors.accentBlue)

                Text(meeting.title)
                    .modernHeader(size: .large)

                Spacer()

                // Edit button
                Button {
                    showEditMeeting = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "pencil")
                        Text("Edit")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(ModernColors.accentBlue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(ModernColors.accentBlue.opacity(0.2))
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)

                // AI Summary button
                Button {
                    generateSummary()
                } label: {
                    HStack(spacing: 6) {
                        if isGeneratingSummary {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "sparkles")
                        }
                        Text("AI Summary")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(ModernColors.pink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(ModernColors.pink.opacity(0.2))
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .disabled(isGeneratingSummary)
            }

            HStack(spacing: 16) {
                Label(meeting.date.formatted(date: .complete, time: .shortened), systemImage: "calendar")
                Label(meeting.formattedDuration, systemImage: "clock")
                if let location = meeting.location {
                    Label(location, systemImage: "mappin")
                }
            }
            .font(.system(size: 14))
            .foregroundColor(ModernColors.textSecondary)
        }
    }

    private var meetingInfoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Attendees")
                .modernHeader(size: .small)

            if meeting.attendees.isEmpty {
                Text("No attendees")
                    .font(.system(size: 14))
                    .foregroundColor(ModernColors.textTertiary)
            } else {
                HStack(spacing: 12) {
                    ForEach(meeting.attendees, id: \.self) { attendeeId in
                        if let person = dataStore.person(for: attendeeId) {
                            VStack(spacing: 4) {
                                Text(person.initials)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 40, height: 40)
                                    .background(Color(hex: person.avatarColor))
                                    .cornerRadius(20)

                                Text(person.name.components(separatedBy: " ").first ?? "")
                                    .font(.system(size: 12))
                                    .foregroundColor(ModernColors.textSecondary)
                            }
                        }
                    }
                }
            }

            if let mood = meeting.mood {
                HStack(spacing: 8) {
                    Image(systemName: mood.icon)
                        .foregroundColor(Color(hex: mood.color))
                    Text("Mood: \(mood.rawValue)")
                        .font(.system(size: 14))
                        .foregroundColor(ModernColors.textSecondary)
                }
            }
        }
        .glassCard()
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Notes")
                    .modernHeader(size: .small)

                Spacer()

                Button {
                    isEditingNotes.toggle()
                } label: {
                    Text(isEditingNotes ? "Done" : "Edit")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(ModernColors.accent)
                }
                .buttonStyle(.plain)
            }

            if isEditingNotes {
                TextEditor(text: $meeting.notes)
                    .font(.system(size: 14))
                    .foregroundColor(ModernColors.textPrimary)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 200)
                    .padding(12)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
            } else {
                if meeting.notes.isEmpty {
                    Text("No notes yet. Click Edit to add notes.")
                        .font(.system(size: 14))
                        .foregroundColor(ModernColors.textTertiary)
                        .italic()
                } else {
                    Text(meeting.notes)
                        .font(.system(size: 14))
                        .foregroundColor(ModernColors.textPrimary)
                }
            }

            // AI Summary error
            if let error = aiSummaryError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(ModernColors.orange)
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundColor(ModernColors.orange)
                }
                .padding(12)
                .background(ModernColors.orange.opacity(0.1))
                .cornerRadius(10)
            }

            // AI Summary
            if let summary = meeting.summary ?? aiSummary {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .foregroundColor(ModernColors.pink)
                        Text("AI Summary")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(ModernColors.pink)
                    }

                    Text(summary)
                        .font(.system(size: 14))
                        .foregroundColor(ModernColors.textSecondary)
                        .padding(12)
                        .background(ModernColors.pink.opacity(0.1))
                        .cornerRadius(12)
                }
            }
        }
        .glassCard()
    }

    private var actionItemsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Action Items")
                    .modernHeader(size: .small)

                Spacer()

                Text("\(meeting.completedActionItemsCount)/\(meeting.actionItems.count)")
                    .font(.system(size: 13))
                    .foregroundColor(ModernColors.textTertiary)

                Button {
                    showAddActionItem.toggle()
                } label: {
                    Image(systemName: showAddActionItem ? "minus.circle.fill" : "plus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(ModernColors.accentGreen)
                }
                .buttonStyle(.plain)
            }

            // Add action item form
            if showAddActionItem {
                addActionItemForm
            }

            if meeting.actionItems.isEmpty && !showAddActionItem {
                Text("No action items. Click + to add one.")
                    .font(.system(size: 14))
                    .foregroundColor(ModernColors.textTertiary)
            } else {
                ForEach(meeting.actionItems.indices, id: \.self) { index in
                    actionItemRow(index: index)
                }
            }
        }
        .glassCard()
    }

    private var addActionItemForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title field
            TextField("Action item title...", text: $newActionItemTitle)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .foregroundColor(ModernColors.textPrimary)
                .padding(12)
                .background(Color.white.opacity(0.05))
                .cornerRadius(10)

            HStack(spacing: 12) {
                // Priority picker
                Menu {
                    ForEach(Priority.allCases, id: \.self) { priority in
                        Button {
                            newActionItemPriority = priority
                        } label: {
                            Label(priority.rawValue, systemImage: priority.icon)
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: newActionItemPriority.icon)
                        Text(newActionItemPriority.rawValue)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10))
                    }
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: newActionItemPriority.color))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(hex: newActionItemPriority.color).opacity(0.2))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)

                // Due date picker
                Button {
                    showDueDatePicker.toggle()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                        Text(newActionItemDueDate?.formatted(date: .abbreviated, time: .omitted) ?? "Set Due Date")
                    }
                    .font(.system(size: 13))
                    .foregroundColor(newActionItemDueDate != nil ? ModernColors.accentBlue : ModernColors.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showDueDatePicker) {
                    VStack {
                        DatePicker("Due Date", selection: Binding(
                            get: { newActionItemDueDate ?? Date() },
                            set: { newActionItemDueDate = $0 }
                        ), displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .padding()

                        HStack {
                            Button("Clear") {
                                newActionItemDueDate = nil
                                showDueDatePicker = false
                            }
                            .foregroundColor(.red)

                            Spacer()

                            Button("Done") {
                                showDueDatePicker = false
                            }
                        }
                        .padding()
                    }
                    .frame(width: 300, height: 350)
                }

                // Assignee picker
                Menu {
                    Button("Unassigned") {
                        newActionItemAssignee = nil
                    }
                    Divider()
                    ForEach(dataStore.people) { person in
                        Button {
                            newActionItemAssignee = person.id
                        } label: {
                            Text(person.name)
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "person")
                        if let assigneeId = newActionItemAssignee,
                           let person = dataStore.person(for: assigneeId) {
                            Text(person.name)
                        } else {
                            Text("Assign")
                        }
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10))
                    }
                    .font(.system(size: 13))
                    .foregroundColor(ModernColors.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)

                Spacer()

                // Add button
                Button {
                    addActionItem()
                } label: {
                    Text("Add")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(newActionItemTitle.isEmpty ? Color.gray : ModernColors.accentGreen)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(newActionItemTitle.isEmpty)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.03))
        .cornerRadius(12)
    }

    private func addActionItem() {
        guard !newActionItemTitle.isEmpty else { return }

        let actionItem = ActionItem(
            title: newActionItemTitle,
            assigneeId: newActionItemAssignee,
            dueDate: newActionItemDueDate,
            priority: newActionItemPriority,
            meetingId: meeting.id
        )

        dataStore.addActionItem(actionItem, to: meeting.id)

        // Reset form
        newActionItemTitle = ""
        newActionItemPriority = .medium
        newActionItemDueDate = nil
        newActionItemAssignee = nil
        showAddActionItem = false
    }

    private func actionItemRow(index: Int) -> some View {
        let item = meeting.actionItems[index]
        return HStack(spacing: 12) {
            Button {
                meeting.actionItems[index].isCompleted.toggle()
                if meeting.actionItems[index].isCompleted {
                    meeting.actionItems[index].completedDate = Date()
                } else {
                    meeting.actionItems[index].completedDate = nil
                }
            } label: {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(item.isCompleted ? ModernColors.accentGreen : ModernColors.textTertiary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(item.isCompleted ? ModernColors.textTertiary : ModernColors.textPrimary)
                    .strikethrough(item.isCompleted)

                if let dueDate = item.dueDate {
                    Text("Due: \(dueDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.system(size: 12))
                        .foregroundColor(item.isOverdue ? ModernColors.statusCritical : ModernColors.textTertiary)
                }
            }

            Spacer()

            // Priority
            Text(item.priority.rawValue)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color(hex: item.priority.color))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(hex: item.priority.color).opacity(0.2))
                .cornerRadius(6)
        }
        .padding(.vertical, 4)
    }

    private var decisionsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Decisions")
                .modernHeader(size: .small)

            ForEach(meeting.decisions) { decision in
                VStack(alignment: .leading, spacing: 4) {
                    Text(decision.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(ModernColors.textPrimary)

                    if let rationale = decision.rationale {
                        Text(rationale)
                            .font(.system(size: 13))
                            .foregroundColor(ModernColors.textSecondary)
                    }
                }
                .padding(12)
                .background(Color.white.opacity(0.03))
                .cornerRadius(10)
            }
        }
        .glassCard()
    }

    private var followUpsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Follow-ups")
                .modernHeader(size: .small)

            ForEach(meeting.followUps) { followUp in
                HStack {
                    Image(systemName: followUp.isAddressed ? "checkmark.circle.fill" : "arrow.right.circle")
                        .foregroundColor(followUp.isAddressed ? ModernColors.accentGreen : ModernColors.orange)

                    Text(followUp.topic)
                        .font(.system(size: 14))
                        .foregroundColor(ModernColors.textPrimary)

                    Spacer()
                }
            }
        }
        .glassCard()
    }

    #if os(macOS)
    private func generateSummary() {
        guard !meeting.notes.isEmpty else {
            aiSummaryError = "Please add meeting notes first before generating a summary."
            return
        }

        aiSummaryError = nil
        isGeneratingSummary = true
        Task {
            do {
                let attendeeNames = meeting.attendees.compactMap {
                    dataStore.person(for: $0)?.name
                }
                let summary = try await AIService.shared.generateMeetingSummary(
                    notes: meeting.notes,
                    attendees: attendeeNames
                )
                await MainActor.run {
                    aiSummary = summary
                    meeting.summary = summary
                    isGeneratingSummary = false
                }
            } catch {
                await MainActor.run {
                    isGeneratingSummary = false
                    aiSummaryError = "AI Summary failed: \(error.localizedDescription)"
                }
                print("AI Summary error: \(error)")
            }
        }
    }
    #else
    private func generateSummary() {
        aiSummaryError = "AI features are only available on macOS"
    }
    #endif
}

#Preview {
    MeetingsView()
        .environmentObject(DataStore.shared)
}
