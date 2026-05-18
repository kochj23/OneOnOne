//
//  OKRView.swift
//  OneOnOne
//
//  OKR (Objectives and Key Results) management view
//  Created by Jordan Koch on 2026-02-02.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

struct OKRView: View {
    @EnvironmentObject var dataStore: DataStore
    @State private var selectedObjective: Objective?
    @State private var showNewObjective = false
    @State private var filterOwner: UUID?
    @State private var filterLevel: OKRLevel?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
                .padding(24)

            Divider()
                .background(ModernColors.glassBorder)

            // Content
            HStack(spacing: 0) {
                // Objectives list
                objectivesList
                    .frame(maxWidth: .infinity)

                Divider()
                    .background(ModernColors.glassBorder)

                // Progress sidebar
                progressSidebar
                    .frame(width: 300)
            }
        }
        .sheet(isPresented: $showNewObjective) {
            NewObjectiveView()
        }
        .sheet(item: $selectedObjective) { objective in
            ObjectiveDetailView(objective: objective)
        }
    }

    private var filteredObjectives: [Objective] {
        var result = dataStore.objectives

        if let level = filterLevel {
            result = result.filter { $0.level == level }
        }

        if let ownerId = filterOwner {
            result = result.filter { $0.ownerId == ownerId }
        }

        return result.sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("OKRs")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(ModernColors.textPrimary)

                Text("Objectives and Key Results tracking")
                    .font(.system(size: 14))
                    .foregroundColor(ModernColors.textSecondary)
            }

            Spacer()

            // Filter by level
            Menu {
                Button("All Levels") { filterLevel = nil }
                Divider()
                ForEach(OKRLevel.allCases, id: \.self) { level in
                    Button(level.rawValue) {
                        filterLevel = level
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "square.3.layers.3d")
                    Text(filterLevel?.rawValue ?? "All Levels")
                }
                .foregroundColor(ModernColors.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.05))
                .cornerRadius(8)
            }

            // Filter by owner
            Menu {
                Button("All Owners") { filterOwner = nil }
                Divider()
                ForEach(dataStore.people) { person in
                    Button(person.name) {
                        filterOwner = person.id
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "person")
                    Text(filterOwner.flatMap { dataStore.person(for: $0)?.name } ?? "All Owners")
                }
                .foregroundColor(ModernColors.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.05))
                .cornerRadius(8)
            }

            Button {
                showNewObjective = true
            } label: {
                Label("New Objective", systemImage: "plus")
                    .primaryButton()
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Objectives List

    private var objectivesList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if filteredObjectives.isEmpty {
                    emptyState
                } else {
                    ForEach(filteredObjectives) { objective in
                        ObjectiveCard(objective: objective) {
                            selectedObjective = objective
                        }
                    }
                }
            }
            .padding(24)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 48))
                .foregroundColor(ModernColors.textTertiary)

            Text("No objectives yet")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(ModernColors.textSecondary)

            Text("Create objectives with measurable key results to track progress")
                .font(.system(size: 14))
                .foregroundColor(ModernColors.textTertiary)
                .multilineTextAlignment(.center)

            Button {
                showNewObjective = true
            } label: {
                Label("Create First Objective", systemImage: "plus")
                    .primaryButton()
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(60)
    }

    // MARK: - Progress Sidebar

    private var progressSidebar: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Overall progress
                VStack(alignment: .leading, spacing: 12) {
                    Text("Overall Progress")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(ModernColors.textSecondary)

                    let progress = overallProgress
                    VStack(spacing: 8) {
                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(progressColor(progress))

                        ProgressView(value: progress)
                            .tint(progressColor(progress))
                    }
                }
                .padding(16)
                .glassCard()

                // By status
                VStack(alignment: .leading, spacing: 12) {
                    Text("By Status")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(ModernColors.textSecondary)

                    ForEach(OKRStatus.allCases, id: \.self) { status in
                        let count = dataStore.objectives.filter { $0.status == status }.count
                        HStack {
                            Circle()
                                .fill(Color(hex: status.color))
                                .frame(width: 10, height: 10)
                            Text(status.rawValue)
                                .font(.system(size: 13))
                                .foregroundColor(ModernColors.textSecondary)
                            Spacer()
                            Text("\(count)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(ModernColors.textPrimary)
                        }
                    }
                }
                .padding(16)
                .glassCard()

                // By level
                VStack(alignment: .leading, spacing: 12) {
                    Text("By Level")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(ModernColors.textSecondary)

                    ForEach(OKRLevel.allCases, id: \.self) { level in
                        let count = dataStore.objectives.filter { $0.level == level }.count
                        HStack {
                            Image(systemName: level.icon)
                                .foregroundColor(Color(hex: level.color))
                                .frame(width: 16)
                            Text(level.rawValue)
                                .font(.system(size: 13))
                                .foregroundColor(ModernColors.textSecondary)
                            Spacer()
                            Text("\(count)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(ModernColors.textPrimary)
                        }
                    }
                }
                .padding(16)
                .glassCard()

                // At risk objectives
                let atRiskObjectives = dataStore.objectives.filter { $0.status == .atRisk }
                if !atRiskObjectives.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(ModernColors.orange)
                            Text("At Risk")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(ModernColors.textSecondary)
                        }

                        ForEach(atRiskObjectives) { objective in
                            Button {
                                selectedObjective = objective
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(objective.title)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(ModernColors.textPrimary)
                                        .lineLimit(1)

                                    HStack {
                                        Text("\(Int(objective.progress * 100))% complete")
                                            .font(.system(size: 11))
                                            .foregroundColor(ModernColors.textTertiary)

                                        Spacer()

                                        Text(objective.quarter)
                                            .font(.system(size: 11))
                                            .foregroundColor(ModernColors.orange)
                                    }
                                }
                                .padding(10)
                                .background(Color.white.opacity(0.03))
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                    .glassCard()
                }
            }
            .padding(20)
        }
        .background(Color.black.opacity(0.2))
    }

    private var overallProgress: Double {
        let activeObjectives = dataStore.objectives.filter { $0.status != .cancelled }
        guard !activeObjectives.isEmpty else { return 0 }
        return activeObjectives.map { $0.progress }.reduce(0, +) / Double(activeObjectives.count)
    }

    private func progressColor(_ progress: Double) -> Color {
        if progress >= 0.7 { return ModernColors.accentGreen }
        if progress >= 0.4 { return ModernColors.orange }
        return ModernColors.red
    }
}

// MARK: - Objective Card

struct ObjectiveCard: View {
    let objective: Objective
    let action: () -> Void
    @EnvironmentObject var dataStore: DataStore

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(objective.title)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(ModernColors.textPrimary)
                            .lineLimit(2)

                        HStack(spacing: 12) {
                            Label(objective.level.rawValue, systemImage: objective.level.icon)
                                .foregroundColor(Color(hex: objective.level.color))

                            if let ownerId = objective.ownerId,
                               let owner = dataStore.person(for: ownerId) {
                                Label(owner.name, systemImage: "person.fill")
                                    .foregroundColor(ModernColors.textTertiary)
                            }

                            Label(objective.status.rawValue, systemImage: objective.status.icon)
                                .foregroundColor(Color(hex: objective.status.color))
                        }
                        .font(.system(size: 12))
                    }

                    Spacer()

                    // Progress ring
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.1), lineWidth: 6)
                        Circle()
                            .trim(from: 0, to: objective.progress)
                            .stroke(progressColor(objective.progress), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Text("\(Int(objective.progress * 100))%")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(ModernColors.textPrimary)
                    }
                    .frame(width: 60, height: 60)
                }

                // Key Results
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(objective.keyResults) { kr in
                        HStack(spacing: 10) {
                            // Progress indicator
                            ZStack {
                                Circle()
                                    .stroke(Color.white.opacity(0.1), lineWidth: 3)
                                    .frame(width: 24, height: 24)
                                Circle()
                                    .trim(from: 0, to: kr.progress)
                                    .stroke(progressColor(kr.progress), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                    .frame(width: 24, height: 24)
                                    .rotationEffect(.degrees(-90))
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(kr.title)
                                    .font(.system(size: 13))
                                    .foregroundColor(ModernColors.textSecondary)
                                    .lineLimit(1)

                                Text("\(kr.formattedCurrent) / \(kr.formattedTarget)")
                                    .font(.system(size: 11))
                                    .foregroundColor(ModernColors.textTertiary)
                            }

                            Spacer()
                        }
                    }
                }

                // Quarter and tags
                HStack {
                    Label(objective.quarter, systemImage: "calendar")
                        .font(.system(size: 11))
                        .foregroundColor(ModernColors.textTertiary)

                    Spacer()

                    ForEach(objective.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 10))
                            .foregroundColor(ModernColors.cyan)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(ModernColors.cyan.opacity(0.15))
                            .cornerRadius(4)
                    }
                }
            }
            .padding(20)
            .glassCard()
        }
        .buttonStyle(.plain)
    }

    private func progressColor(_ progress: Double) -> Color {
        if progress >= 0.7 { return ModernColors.accentGreen }
        if progress >= 0.4 { return ModernColors.orange }
        return ModernColors.red
    }
}

// MARK: - Objective Detail View

struct ObjectiveDetailView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var dataStore: DataStore
    let objective: Objective
    @State private var editedObjective: Objective
    @State private var showDeleteAlert = false

    init(objective: Objective) {
        self.objective = objective
        _editedObjective = State(initialValue: objective)
    }

    var body: some View {
        ZStack {
            ModernColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Objective Details")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(ModernColors.textPrimary)

                    Spacer()

                    Button {
                        showDeleteAlert = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(ModernColors.red)
                    }
                    .buttonStyle(.plain)

                    Button("Save") {
                        dataStore.updateObjective(editedObjective)
                        dismiss()
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(ModernColors.cyan)
                }
                .padding(24)

                Divider()
                    .background(ModernColors.glassBorder)

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Title
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Objective")
                                .formLabel()
                            TextField("Objective title", text: $editedObjective.title)
                                .formTextField()
                        }

                        // Description
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .formLabel()
                            TextField("Description", text: Binding(
                                get: { editedObjective.description ?? "" },
                                set: { editedObjective.description = $0.isEmpty ? nil : $0 }
                            ))
                            .formTextField()
                        }

                        // Level and Status
                        HStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Level")
                                    .formLabel()
                                Picker("", selection: $editedObjective.level) {
                                    ForEach(OKRLevel.allCases, id: \.self) { level in
                                        Text(level.rawValue).tag(level)
                                    }
                                }
                                .pickerStyle(.menu)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Status")
                                    .formLabel()
                                Picker("", selection: $editedObjective.status) {
                                    ForEach(OKRStatus.allCases, id: \.self) { status in
                                        Text(status.rawValue).tag(status)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                        }

                        // Quarter
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Quarter")
                                .formLabel()
                            TextField("e.g., Q1 2026", text: $editedObjective.quarter)
                                .formTextField()
                        }

                        // Key Results
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Key Results")
                                    .formLabel()
                                Spacer()
                                Button {
                                    editedObjective.keyResults.append(KeyResult(
                                        title: "",
                                        targetValue: 100
                                    ))
                                } label: {
                                    Image(systemName: "plus.circle")
                                        .foregroundColor(ModernColors.cyan)
                                }
                                .buttonStyle(.plain)
                            }

                            ForEach(Array(editedObjective.keyResults.enumerated()), id: \.element.id) { index, kr in
                                VStack(spacing: 12) {
                                    HStack {
                                        TextField("Key result", text: $editedObjective.keyResults[index].title)
                                            .formTextField()

                                        if editedObjective.keyResults.count > 1 {
                                            Button {
                                                editedObjective.keyResults.remove(at: index)
                                            } label: {
                                                Image(systemName: "minus.circle")
                                                    .foregroundColor(ModernColors.red)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }

                                    HStack(spacing: 16) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Current")
                                                .font(.system(size: 11))
                                                .foregroundColor(ModernColors.textTertiary)
                                            TextField("0", value: $editedObjective.keyResults[index].currentValue, format: .number)
                                                .textFieldStyle(.roundedBorder)
                                                .frame(width: 80)
                                        }

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Target")
                                                .font(.system(size: 11))
                                                .foregroundColor(ModernColors.textTertiary)
                                            TextField("100", value: $editedObjective.keyResults[index].targetValue, format: .number)
                                                .textFieldStyle(.roundedBorder)
                                                .frame(width: 80)
                                        }

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Unit")
                                                .font(.system(size: 11))
                                                .foregroundColor(ModernColors.textTertiary)
                                            TextField("%", text: Binding(
                                                get: { editedObjective.keyResults[index].unit ?? "" },
                                                set: { editedObjective.keyResults[index].unit = $0.isEmpty ? nil : $0 }
                                            ))
                                            .textFieldStyle(.roundedBorder)
                                            .frame(width: 60)
                                        }

                                        Spacer()

                                        // Progress display
                                        Text("\(Int(editedObjective.keyResults[index].progress * 100))%")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(progressColor(editedObjective.keyResults[index].progress))
                                    }
                                }
                                .padding(12)
                                .background(Color.white.opacity(0.03))
                                .cornerRadius(10)
                            }
                        }

                        // Overall Progress
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Overall Progress")
                                    .formLabel()
                                Spacer()
                                Text("\(Int(editedObjective.progress * 100))%")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(progressColor(editedObjective.progress))
                            }
                            ProgressView(value: editedObjective.progress)
                                .tint(progressColor(editedObjective.progress))
                        }
                        .padding(16)
                        .glassCard()
                    }
                    .padding(24)
                }
            }
        }
        .frame(width: 600, height: 700)
        .alert("Delete Objective?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                dataStore.deleteObjective(id: objective.id)
                dismiss()
            }
        } message: {
            Text("This will also delete all associated key results.")
        }
    }

    private func progressColor(_ progress: Double) -> Color {
        if progress >= 0.7 { return ModernColors.accentGreen }
        if progress >= 0.4 { return ModernColors.orange }
        return ModernColors.red
    }
}

// MARK: - New Objective View

struct NewObjectiveView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var dataStore: DataStore

    @State private var title = ""
    @State private var description = ""
    @State private var level: OKRLevel = .individual
    @State private var ownerId: UUID?
    @State private var quarter = "Q1 2026"
    @State private var keyResults: [KeyResult] = [
        KeyResult(title: "", targetValue: 100)
    ]

    var body: some View {
        ZStack {
            ModernColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("New Objective")
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
                        // Title
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Objective")
                                .formLabel()
                            TextField("e.g., Improve customer satisfaction", text: $title)
                                .formTextField()
                        }

                        // Description
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description (optional)")
                                .formLabel()
                            TextField("Why is this objective important?", text: $description)
                                .formTextField()
                        }

                        // Level and Owner
                        HStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Level")
                                    .formLabel()
                                Picker("", selection: $level) {
                                    ForEach(OKRLevel.allCases, id: \.self) { lvl in
                                        Text(lvl.rawValue).tag(lvl)
                                    }
                                }
                                .pickerStyle(.menu)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Owner")
                                    .formLabel()
                                Picker("", selection: $ownerId) {
                                    Text("Unassigned").tag(nil as UUID?)
                                    ForEach(dataStore.people) { person in
                                        Text(person.name).tag(person.id as UUID?)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                        }

                        // Quarter
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Quarter")
                                .formLabel()
                            TextField("e.g., Q1 2026", text: $quarter)
                                .formTextField()
                        }

                        // Key Results
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Key Results")
                                    .formLabel()
                                Spacer()
                                Button {
                                    keyResults.append(KeyResult(title: "", targetValue: 100))
                                } label: {
                                    Label("Add", systemImage: "plus.circle")
                                        .font(.system(size: 13))
                                        .foregroundColor(ModernColors.cyan)
                                }
                                .buttonStyle(.plain)
                            }

                            ForEach(Array(keyResults.enumerated()), id: \.element.id) { index, _ in
                                VStack(spacing: 12) {
                                    HStack {
                                        Text("KR \(index + 1)")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(ModernColors.cyan)
                                            .frame(width: 40)

                                        TextField("Key result title", text: $keyResults[index].title)
                                            .formTextField()

                                        if keyResults.count > 1 {
                                            Button {
                                                keyResults.remove(at: index)
                                            } label: {
                                                Image(systemName: "minus.circle")
                                                    .foregroundColor(ModernColors.red)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }

                                    HStack(spacing: 12) {
                                        Text("Target:")
                                            .font(.system(size: 12))
                                            .foregroundColor(ModernColors.textTertiary)

                                        TextField("100", value: $keyResults[index].targetValue, format: .number)
                                            .textFieldStyle(.roundedBorder)
                                            .frame(width: 80)

                                        TextField("Unit", text: Binding(
                                            get: { keyResults[index].unit ?? "" },
                                            set: { keyResults[index].unit = $0.isEmpty ? nil : $0 }
                                        ))
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 80)

                                        Spacer()
                                    }
                                }
                                .padding(12)
                                .background(Color.white.opacity(0.03))
                                .cornerRadius(10)
                            }
                        }

                        // Create Button
                        Button {
                            createObjective()
                        } label: {
                            Text("Create Objective")
                                .frame(maxWidth: .infinity)
                                .primaryButton()
                        }
                        .buttonStyle(.plain)
                        .disabled(title.isEmpty || keyResults.filter { !$0.title.isEmpty }.isEmpty)
                    }
                    .padding(24)
                }
            }
        }
        .frame(width: 600, height: 700)
    }

    private func createObjective() {
        let objective = Objective(
            title: title,
            description: description.isEmpty ? nil : description,
            level: level,
            ownerId: ownerId,
            quarter: quarter,
            keyResults: keyResults.filter { !$0.title.isEmpty }
        )

        dataStore.addObjective(objective)
        dismiss()
    }
}

#Preview {
    OKRView()
        .environmentObject(DataStore.shared)
}
