//
//  ActionItemsView.swift
//  OneOnOne
//
//  View for managing action items/tasks
//  Created by Jordan Koch on 2026-02-02.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

struct ActionItemsView: View {
    @EnvironmentObject var dataStore: DataStore
    @State private var filterPriority: Priority?
    @State private var filterAssignee: UUID?
    @State private var showCompleted = false

    var filteredItems: [ActionItem] {
        var items = showCompleted ? dataStore.allActionItems() : dataStore.openActionItems()

        if let priority = filterPriority {
            items = items.filter { $0.priority == priority }
        }

        if let assignee = filterAssignee {
            items = items.filter { $0.assigneeId == assignee }
        }

        return items.sorted { item1, item2 in
            // Overdue first, then by priority, then by due date
            if item1.isOverdue != item2.isOverdue {
                return item1.isOverdue
            }
            if item1.priority.sortOrder != item2.priority.sortOrder {
                return item1.priority.sortOrder < item2.priority.sortOrder
            }
            if let date1 = item1.dueDate, let date2 = item2.dueDate {
                return date1 < date2
            }
            return false
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
                .padding(24)

            // Filters
            filtersBar
                .padding(.horizontal, 24)
                .padding(.bottom, 16)

            Divider()
                .background(ModernColors.glassBorder)

            // Content
            ScrollView {
                LazyVStack(spacing: 12) {
                    // Overdue section
                    let overdue = filteredItems.filter { $0.isOverdue }
                    if !overdue.isEmpty {
                        sectionHeader("Overdue", count: overdue.count, color: ModernColors.statusCritical)
                        ForEach(overdue) { item in
                            actionItemCard(item)
                        }
                    }

                    // Due soon section
                    let dueSoon = filteredItems.filter { $0.isDueSoon && !$0.isOverdue }
                    if !dueSoon.isEmpty {
                        sectionHeader("Due Soon", count: dueSoon.count, color: ModernColors.orange)
                        ForEach(dueSoon) { item in
                            actionItemCard(item)
                        }
                    }

                    // Other items
                    let others = filteredItems.filter { !$0.isOverdue && !$0.isDueSoon }
                    if !others.isEmpty {
                        sectionHeader("All Tasks", count: others.count, color: ModernColors.textSecondary)
                        ForEach(others) { item in
                            actionItemCard(item)
                        }
                    }

                    if filteredItems.isEmpty {
                        emptyState
                    }
                }
                .padding(24)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Action Items")
                    .modernHeader(size: .large)

                Text("\(dataStore.openActionItems().count) open tasks")
                    .font(.system(size: 16))
                    .foregroundColor(ModernColors.textSecondary)
            }

            Spacer()

            // Stats
            HStack(spacing: 24) {
                statBadge(
                    value: dataStore.overdueActionItems.count,
                    label: "Overdue",
                    color: ModernColors.statusCritical
                )

                statBadge(
                    value: dataStore.openActionItems().filter { $0.priority == .urgent || $0.priority == .high }.count,
                    label: "High Priority",
                    color: ModernColors.orange
                )
            }
        }
    }

    private func statBadge(value: Int, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(ModernColors.textTertiary)
        }
    }

    // MARK: - Filters

    private var filtersBar: some View {
        HStack(spacing: 12) {
            // Priority filter
            Menu {
                Button("All Priorities") {
                    filterPriority = nil
                }
                Divider()
                ForEach(Priority.allCases, id: \.self) { priority in
                    Button {
                        filterPriority = priority
                    } label: {
                        Label(priority.rawValue, systemImage: priority.icon)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: filterPriority?.icon ?? "flag")
                    Text(filterPriority?.rawValue ?? "All Priorities")
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

            // Assignee filter
            Menu {
                Button("All Assignees") {
                    filterAssignee = nil
                }
                Divider()
                ForEach(dataStore.people) { person in
                    Button(person.name) {
                        filterAssignee = person.id
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "person")
                    if let assigneeId = filterAssignee,
                       let person = dataStore.person(for: assigneeId) {
                        Text(person.name)
                    } else {
                        Text("All Assignees")
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

            // Show completed toggle
            Toggle(isOn: $showCompleted) {
                Text("Show Completed")
                    .font(.system(size: 13))
                    .foregroundColor(ModernColors.textSecondary)
            }
            .toggleStyle(.checkbox)
        }
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String, count: Int, color: Color) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(color)

            Text("\(count)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(color)
                .cornerRadius(8)

            Spacer()
        }
        .padding(.top, 12)
    }

    // MARK: - Action Item Card

    private func actionItemCard(_ item: ActionItem) -> some View {
        HStack(spacing: 16) {
            // Checkbox
            Button {
                toggleCompletion(item)
            } label: {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(item.isCompleted ? ModernColors.accentGreen : ModernColors.textTertiary)
            }
            .buttonStyle(.plain)

            // Priority indicator
            Rectangle()
                .fill(Color(hex: item.priority.color))
                .frame(width: 4)
                .cornerRadius(2)

            // Content
            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(item.isCompleted ? ModernColors.textTertiary : ModernColors.textPrimary)
                    .strikethrough(item.isCompleted)

                if let description = item.description {
                    Text(description)
                        .font(.system(size: 13))
                        .foregroundColor(ModernColors.textTertiary)
                        .lineLimit(2)
                }

                HStack(spacing: 16) {
                    // Source meeting
                    if let meeting = dataStore.meetings.first(where: { $0.id == item.meetingId }) {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                            Text(meeting.title)
                        }
                        .font(.system(size: 12))
                        .foregroundColor(ModernColors.textTertiary)
                        .lineLimit(1)
                    }

                    // Due date
                    if let dueDate = item.dueDate {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                            Text(dueDate.formatted(date: .abbreviated, time: .omitted))
                        }
                        .font(.system(size: 12))
                        .foregroundColor(item.isOverdue ? ModernColors.statusCritical : ModernColors.textTertiary)
                    }
                }
            }

            Spacer()

            // Assignee
            if let assigneeId = item.assigneeId,
               let person = dataStore.person(for: assigneeId) {
                VStack(spacing: 4) {
                    Text(person.initials)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Color(hex: person.avatarColor))
                        .cornerRadius(16)

                    Text(person.name.components(separatedBy: " ").first ?? "")
                        .font(.system(size: 11))
                        .foregroundColor(ModernColors.textTertiary)
                }
            }

            // Priority badge
            Text(item.priority.rawValue)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color(hex: item.priority.color))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color(hex: item.priority.color).opacity(0.2))
                .cornerRadius(8)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(item.isOverdue ? ModernColors.statusCritical.opacity(0.1) : Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(item.isOverdue ? ModernColors.statusCritical.opacity(0.3) : Color.clear, lineWidth: 1)
                )
        )
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48))
                .foregroundColor(ModernColors.accentGreen)

            Text(showCompleted ? "No tasks found" : "All tasks completed!")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(ModernColors.textSecondary)

            Text("Great job staying on top of your action items")
                .font(.system(size: 14))
                .foregroundColor(ModernColors.textTertiary)
        }
        .padding(.vertical, 60)
    }

    // MARK: - Helper

    private func toggleCompletion(_ item: ActionItem) {
        var updatedItem = item
        if item.isCompleted {
            updatedItem.markIncomplete()
        } else {
            updatedItem.markComplete()
        }
        dataStore.updateActionItem(updatedItem, in: item.meetingId)
    }
}

#Preview {
    ActionItemsView()
        .environmentObject(DataStore.shared)
}
