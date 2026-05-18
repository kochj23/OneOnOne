//
//  TemplatesView.swift
//  OneOnOne
//
//  Meeting templates management view
//  Created by Jordan Koch on 2026-02-02.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

struct TemplatesView: View {
    @EnvironmentObject var dataStore: DataStore
    @State private var selectedTemplate: MeetingTemplate?
    @State private var showNewTemplate = false
    @State private var searchText = ""

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
                    // Built-in Templates
                    templateSection(
                        title: "Built-in Templates",
                        templates: filteredBuiltInTemplates,
                        icon: "star.fill",
                        color: ModernColors.cyan
                    )

                    // Custom Templates
                    templateSection(
                        title: "Custom Templates",
                        templates: filteredCustomTemplates,
                        icon: "person.fill",
                        color: ModernColors.purple
                    )
                }
                .padding(24)
            }
        }
        .sheet(item: $selectedTemplate) { template in
            TemplateDetailView(template: template)
        }
        .sheet(isPresented: $showNewTemplate) {
            NewTemplateView()
        }
    }

    private var filteredBuiltInTemplates: [MeetingTemplate] {
        let builtIn = dataStore.templates.filter { $0.isBuiltIn }
        if searchText.isEmpty { return builtIn }
        return builtIn.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var filteredCustomTemplates: [MeetingTemplate] {
        let custom = dataStore.templates.filter { !$0.isBuiltIn }
        if searchText.isEmpty { return custom }
        return custom.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Meeting Templates")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(ModernColors.textPrimary)

                Text("Pre-built structures for common meeting types")
                    .font(.system(size: 14))
                    .foregroundColor(ModernColors.textSecondary)
            }

            Spacer()

            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(ModernColors.textTertiary)
                TextField("Search templates...", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(10)
            .background(Color.white.opacity(0.05))
            .cornerRadius(10)
            .frame(width: 200)

            Button {
                showNewTemplate = true
            } label: {
                Label("New Template", systemImage: "plus")
                    .primaryButton()
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Template Section

    private func templateSection(title: String, templates: [MeetingTemplate], icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(ModernColors.textPrimary)
                Text("(\(templates.count))")
                    .font(.system(size: 14))
                    .foregroundColor(ModernColors.textTertiary)
            }

            if templates.isEmpty {
                emptyState(for: title)
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ], spacing: 16) {
                    ForEach(templates) { template in
                        TemplateCard(template: template) {
                            selectedTemplate = template
                        }
                    }
                }
            }
        }
    }

    private func emptyState(for section: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 32))
                .foregroundColor(ModernColors.textTertiary)

            Text(section.contains("Custom") ? "No custom templates yet" : "No templates available")
                .font(.system(size: 14))
                .foregroundColor(ModernColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .glassCard()
    }
}

// MARK: - Template Card

struct TemplateCard: View {
    let template: MeetingTemplate
    let action: () -> Void

    private func iconForMeetingType(_ type: MeetingType) -> String {
        type.icon
    }

    private func colorForMeetingType(_ type: MeetingType) -> Color {
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

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                // Icon and name
                HStack {
                    Image(systemName: iconForMeetingType(template.meetingType))
                        .font(.system(size: 24))
                        .foregroundColor(colorForMeetingType(template.meetingType))

                    Spacer()

                    if template.isBuiltIn {
                        Text("Built-in")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(ModernColors.cyan)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(ModernColors.cyan.opacity(0.2))
                            .cornerRadius(4)
                    }
                }

                Text(template.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ModernColors.textPrimary)
                    .lineLimit(1)

                Text(template.description ?? "No description")
                    .font(.system(size: 13))
                    .foregroundColor(ModernColors.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                // Stats
                HStack(spacing: 16) {
                    Label("\(template.agendaItems.count) items", systemImage: "list.bullet")
                    Label("\(Int(template.defaultDuration / 60))m", systemImage: "clock")
                }
                .font(.system(size: 11))
                .foregroundColor(ModernColors.textTertiary)
            }
            .padding(16)
            .frame(height: 180)
            .glassCard()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Template Detail View

struct TemplateDetailView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var dataStore: DataStore
    let template: MeetingTemplate
    @State private var showDeleteAlert = false

    private func colorForMeetingType(_ type: MeetingType) -> Color {
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

    var body: some View {
        ZStack {
            ModernColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 12) {
                            Image(systemName: template.meetingType.icon)
                                .font(.system(size: 28))
                                .foregroundColor(colorForMeetingType(template.meetingType))

                            Text(template.name)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(ModernColors.textPrimary)
                        }

                        if let description = template.description {
                            Text(description)
                                .font(.system(size: 14))
                                .foregroundColor(ModernColors.textSecondary)
                        }
                    }

                    Spacer()

                    HStack(spacing: 12) {
                        if !template.isBuiltIn {
                            Button {
                                showDeleteAlert = true
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(ModernColors.red)
                            }
                            .buttonStyle(.plain)
                        }

                        Button("Done") {
                            dismiss()
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(ModernColors.cyan)
                    }
                }
                .padding(24)

                Divider()
                    .background(ModernColors.glassBorder)

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Default Duration
                        HStack {
                            Label("Default Duration", systemImage: "clock")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(ModernColors.textSecondary)
                            Spacer()
                            Text("\(Int(template.defaultDuration / 60)) minutes")
                                .font(.system(size: 14))
                                .foregroundColor(ModernColors.textPrimary)
                        }
                        .padding(16)
                        .glassCard()

                        // Agenda Items
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Agenda Items")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(ModernColors.textPrimary)

                            ForEach(Array(template.agendaItems.enumerated()), id: \.element.id) { index, item in
                                HStack(spacing: 12) {
                                    Text("\(index + 1)")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(colorForMeetingType(template.meetingType))
                                        .frame(width: 24, height: 24)
                                        .background(colorForMeetingType(template.meetingType).opacity(0.2))
                                        .cornerRadius(12)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.title)
                                            .font(.system(size: 14))
                                            .foregroundColor(ModernColors.textPrimary)
                                        if item.duration > 0 {
                                            Text("\(Int(item.duration / 60)) min")
                                                .font(.system(size: 11))
                                                .foregroundColor(ModernColors.textTertiary)
                                        }
                                    }

                                    Spacer()
                                }
                                .padding(12)
                                .background(Color.white.opacity(0.03))
                                .cornerRadius(8)
                            }
                        }
                        .padding(16)
                        .glassCard()

                        // Suggested Questions
                        if !template.suggestedQuestions.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Suggested Questions")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(ModernColors.textPrimary)

                                ForEach(template.suggestedQuestions, id: \.self) { question in
                                    HStack(spacing: 12) {
                                        Image(systemName: "questionmark.circle")
                                            .foregroundColor(ModernColors.accentGreen)

                                        Text(question)
                                            .font(.system(size: 14))
                                            .foregroundColor(ModernColors.textSecondary)

                                        Spacer()
                                    }
                                }
                            }
                            .padding(16)
                            .glassCard()
                        }

                        // Use Template Button
                        Button {
                            NotificationCenter.default.post(
                                name: .useTemplate,
                                object: template
                            )
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: "doc.badge.plus")
                                Text("Use This Template")
                            }
                            .frame(maxWidth: .infinity)
                            .primaryButton()
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(24)
                }
            }
        }
        .frame(width: 600, height: 700)
        .alert("Delete Template?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                dataStore.deleteTemplate(id: template.id)
                dismiss()
            }
        } message: {
            Text("This action cannot be undone.")
        }
    }
}

// MARK: - New Template View

struct NewTemplateView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var dataStore: DataStore

    @State private var name = ""
    @State private var description = ""
    @State private var meetingType: MeetingType = .oneOnOne
    @State private var defaultDuration = 30
    @State private var agendaItems: [String] = [""]
    @State private var suggestedQuestions: [String] = []
    @State private var newQuestion = ""

    var body: some View {
        ZStack {
            ModernColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("New Template")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(ModernColors.textPrimary)

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
                    VStack(alignment: .leading, spacing: 20) {
                        // Name
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Template Name")
                                .formLabel()
                            TextField("e.g., Weekly Check-in", text: $name)
                                .formTextField()
                        }

                        // Description
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .formLabel()
                            TextField("Brief description of when to use this template", text: $description)
                                .formTextField()
                        }

                        // Meeting Type
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Meeting Type")
                                .formLabel()
                            Picker("", selection: $meetingType) {
                                ForEach(MeetingType.allCases, id: \.self) { type in
                                    Text(type.rawValue).tag(type)
                                }
                            }
                            .pickerStyle(.menu)
                        }

                        // Duration
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Default Duration (minutes)")
                                .formLabel()
                            Picker("", selection: $defaultDuration) {
                                Text("15").tag(15)
                                Text("30").tag(30)
                                Text("45").tag(45)
                                Text("60").tag(60)
                                Text("90").tag(90)
                            }
                            .pickerStyle(.segmented)
                        }

                        // Agenda Items
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Agenda Items")
                                    .formLabel()
                                Spacer()
                                Button {
                                    agendaItems.append("")
                                } label: {
                                    Image(systemName: "plus.circle")
                                        .foregroundColor(ModernColors.cyan)
                                }
                                .buttonStyle(.plain)
                            }

                            ForEach(Array(agendaItems.enumerated()), id: \.offset) { index, _ in
                                HStack {
                                    Text("\(index + 1).")
                                        .foregroundColor(ModernColors.textTertiary)
                                        .frame(width: 24)
                                    TextField("Agenda item", text: $agendaItems[index])
                                        .formTextField()
                                    if agendaItems.count > 1 {
                                        Button {
                                            agendaItems.remove(at: index)
                                        } label: {
                                            Image(systemName: "minus.circle")
                                                .foregroundColor(ModernColors.red)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }

                        // Suggested Questions
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Suggested Questions (optional)")
                                .formLabel()

                            ForEach(suggestedQuestions, id: \.self) { question in
                                HStack {
                                    Image(systemName: "questionmark.circle")
                                        .foregroundColor(ModernColors.accentGreen)
                                    Text(question)
                                        .font(.system(size: 14))
                                        .foregroundColor(ModernColors.textSecondary)
                                    Spacer()
                                    Button {
                                        suggestedQuestions.removeAll { $0 == question }
                                    } label: {
                                        Image(systemName: "xmark")
                                            .foregroundColor(ModernColors.textTertiary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(8)
                                .background(Color.white.opacity(0.03))
                                .cornerRadius(8)
                            }

                            HStack {
                                TextField("Add a question", text: $newQuestion)
                                    .formTextField()
                                Button {
                                    if !newQuestion.isEmpty {
                                        suggestedQuestions.append(newQuestion)
                                        newQuestion = ""
                                    }
                                } label: {
                                    Text("Add")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(ModernColors.cyan)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        // Save Button
                        Button {
                            saveTemplate()
                        } label: {
                            Text("Create Template")
                                .frame(maxWidth: .infinity)
                                .primaryButton()
                        }
                        .buttonStyle(.plain)
                        .disabled(name.isEmpty || agendaItems.filter { !$0.isEmpty }.isEmpty)
                    }
                    .padding(24)
                }
            }
        }
        .frame(width: 600, height: 700)
    }

    private func saveTemplate() {
        let items = agendaItems.filter { !$0.isEmpty }.map { title in
            AgendaItem(title: title)
        }

        let template = MeetingTemplate(
            name: name,
            description: description.isEmpty ? nil : description,
            meetingType: meetingType,
            defaultDuration: TimeInterval(defaultDuration * 60),
            agendaItems: items,
            suggestedQuestions: suggestedQuestions,
            isBuiltIn: false
        )
        dataStore.addTemplate(template)
        dismiss()
    }
}

// MARK: - Notification

extension Notification.Name {
    static let useTemplate = Notification.Name("useTemplate")
}

#Preview {
    TemplatesView()
        .environmentObject(DataStore.shared)
}
