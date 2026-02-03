//
//  CareerView.swift
//  OneOnOne
//
//  Career development tracking view
//  Created by Jordan Koch on 2026-02-02.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

struct CareerView: View {
    @EnvironmentObject var dataStore: DataStore
    @State private var selectedPerson: Person?
    @State private var selectedProfile: CareerProfile?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
                .padding(24)

            Divider()
                .background(ModernColors.glassBorder)

            // Content
            HStack(spacing: 0) {
                // People list
                peopleList
                    .frame(width: 280)

                Divider()
                    .background(ModernColors.glassBorder)

                // Career details
                if let person = selectedPerson {
                    CareerDetailView(person: person)
                        .frame(maxWidth: .infinity)
                } else {
                    emptyState
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Career Development")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(ModernColors.textPrimary)

                Text("Track skills, training, and career progression")
                    .font(.system(size: 14))
                    .foregroundColor(ModernColors.textSecondary)
            }

            Spacer()
        }
    }

    // MARK: - People List

    private var peopleList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(dataStore.people) { person in
                    PersonCareerRow(
                        person: person,
                        profile: dataStore.careerProfile(for: person.id),
                        isSelected: selectedPerson?.id == person.id
                    ) {
                        selectedPerson = person
                    }
                }
            }
            .padding(16)
        }
        .background(Color.black.opacity(0.2))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 48))
                .foregroundColor(ModernColors.textTertiary)

            Text("Select a person")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(ModernColors.textSecondary)

            Text("Choose someone from the list to view and edit their career development profile")
                .font(.system(size: 14))
                .foregroundColor(ModernColors.textTertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
        }
    }
}

// MARK: - Person Career Row

struct PersonCareerRow: View {
    let person: Person
    let profile: CareerProfile?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(person.initials)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(ModernColors.purple))

                VStack(alignment: .leading, spacing: 2) {
                    Text(person.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(ModernColors.textPrimary)
                        .lineLimit(1)

                    if let profile = profile {
                        HStack(spacing: 8) {
                            Text("\(profile.skills.count) skills")
                                .font(.system(size: 11))
                                .foregroundColor(ModernColors.textTertiary)

                            if profile.promotionReadiness != .notReady {
                                Text(profile.promotionReadiness.rawValue)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(Color(hex: profile.promotionReadiness.color))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color(hex: profile.promotionReadiness.color).opacity(0.15))
                                    .cornerRadius(4)
                            }
                        }
                    } else {
                        Text("No profile")
                            .font(.system(size: 11))
                            .foregroundColor(ModernColors.textTertiary)
                    }
                }

                Spacer()
            }
            .padding(12)
            .background(isSelected ? Color.white.opacity(0.1) : Color.clear)
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Career Detail View

struct CareerDetailView: View {
    @EnvironmentObject var dataStore: DataStore
    let person: Person

    @State private var profile: CareerProfile?
    @State private var showAddSkill = false
    @State private var showAddTraining = false
    @State private var newSkillName = ""
    @State private var newSkillLevel: SkillLevel = .beginner

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Person header
                personHeader

                // Career aspirations
                aspirationsSection

                // Skills
                skillsSection

                // Training
                trainingSection

                // Promotion readiness
                promotionSection
            }
            .padding(24)
        }
        .onAppear {
            loadProfile()
        }
        .onChange(of: person.id) { _, _ in
            loadProfile()
        }
    }

    private func loadProfile() {
        if let existing = dataStore.careerProfile(for: person.id) {
            profile = existing
        } else {
            profile = dataStore.createCareerProfile(for: person.id)
        }
    }

    private func saveProfile() {
        if let profile = profile {
            dataStore.updateCareerProfile(profile, for: person.id)
        }
    }

    // MARK: - Person Header

    private var personHeader: some View {
        HStack(spacing: 16) {
            Text(person.initials)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 64, height: 64)
                .background(Circle().fill(ModernColors.purple))

            VStack(alignment: .leading, spacing: 4) {
                Text(person.name)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(ModernColors.textPrimary)

                if let title = person.title {
                    Text(title)
                        .font(.system(size: 14))
                        .foregroundColor(ModernColors.textSecondary)
                }
            }

            Spacer()

            if let profile = profile {
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Last Updated")
                        .font(.system(size: 11))
                        .foregroundColor(ModernColors.textTertiary)
                    Text(profile.updatedAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 13))
                        .foregroundColor(ModernColors.textSecondary)
                }
            }
        }
        .padding(20)
        .glassCard()
    }

    // MARK: - Aspirations Section

    private var aspirationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Career Aspirations")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(ModernColors.textPrimary)

            VStack(alignment: .leading, spacing: 16) {
                // Current role
                VStack(alignment: .leading, spacing: 6) {
                    Text("Current Role")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ModernColors.textTertiary)
                    TextField("e.g., Software Engineer", text: Binding(
                        get: { profile?.currentRole ?? "" },
                        set: { profile?.currentRole = $0; saveProfile() }
                    ))
                    .formTextField()
                }

                // Target role
                VStack(alignment: .leading, spacing: 6) {
                    Text("Target Role")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ModernColors.textTertiary)
                    TextField("e.g., Senior Software Engineer", text: Binding(
                        get: { profile?.targetRole ?? "" },
                        set: { profile?.targetRole = $0; saveProfile() }
                    ))
                    .formTextField()
                }

                // Career goals
                VStack(alignment: .leading, spacing: 6) {
                    Text("Career Goals")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ModernColors.textTertiary)
                    TextEditor(text: Binding(
                        get: { profile?.careerGoals ?? "" },
                        set: { profile?.careerGoals = $0; saveProfile() }
                    ))
                    .font(.system(size: 14))
                    .frame(height: 80)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                }
            }
        }
        .padding(20)
        .glassCard()
    }

    // MARK: - Skills Section

    private var skillsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Skills")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(ModernColors.textPrimary)

                Spacer()

                Button {
                    showAddSkill.toggle()
                } label: {
                    Label("Add Skill", systemImage: "plus")
                        .font(.system(size: 13))
                        .foregroundColor(ModernColors.cyan)
                }
                .buttonStyle(.plain)
            }

            if showAddSkill {
                HStack(spacing: 12) {
                    TextField("Skill name", text: $newSkillName)
                        .formTextField()

                    Picker("Level", selection: $newSkillLevel) {
                        ForEach(SkillLevel.allCases, id: \.self) { level in
                            Text(level.name).tag(level)
                        }
                    }
                    .frame(width: 120)

                    Button("Add") {
                        addSkill()
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(ModernColors.cyan)
                    .disabled(newSkillName.isEmpty)
                }
                .padding(12)
                .background(Color.white.opacity(0.05))
                .cornerRadius(10)
            }

            if let skills = profile?.skills, !skills.isEmpty {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(skills) { skill in
                        SkillCard(skill: skill) {
                            removeSkill(skill)
                        }
                    }
                }
            } else {
                Text("No skills added yet")
                    .font(.system(size: 14))
                    .foregroundColor(ModernColors.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(20)
            }
        }
        .padding(20)
        .glassCard()
    }

    private func addSkill() {
        let skill = Skill(name: newSkillName, level: newSkillLevel)
        profile?.skills.append(skill)
        saveProfile()
        newSkillName = ""
        newSkillLevel = .beginner
        showAddSkill = false
    }

    private func removeSkill(_ skill: Skill) {
        profile?.skills.removeAll { $0.id == skill.id }
        saveProfile()
    }

    // MARK: - Training Section

    private var trainingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Training & Development")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(ModernColors.textPrimary)

                Spacer()

                Button {
                    showAddTraining.toggle()
                } label: {
                    Label("Add Training", systemImage: "plus")
                        .font(.system(size: 13))
                        .foregroundColor(ModernColors.cyan)
                }
                .buttonStyle(.plain)
            }

            if let trainings = profile?.trainings, !trainings.isEmpty {
                ForEach(trainings) { item in
                    TrainingCard(training: item) {
                        removeTraining(item)
                    }
                }
            } else {
                Text("No training records yet")
                    .font(.system(size: 14))
                    .foregroundColor(ModernColors.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(20)
            }
        }
        .padding(20)
        .glassCard()
        .sheet(isPresented: $showAddTraining) {
            AddTrainingView { training in
                profile?.trainings.append(training)
                saveProfile()
            }
        }
    }

    private func removeTraining(_ training: Training) {
        profile?.trainings.removeAll { $0.id == training.id }
        saveProfile()
    }

    // MARK: - Promotion Section

    private var promotionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Promotion Readiness")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(ModernColors.textPrimary)

            VStack(alignment: .leading, spacing: 16) {
                // Readiness selector
                HStack(spacing: 12) {
                    ForEach(PromotionReadiness.allCases, id: \.self) { readiness in
                        Button {
                            profile?.promotionReadiness = readiness
                            saveProfile()
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: iconForReadiness(readiness))
                                    .font(.system(size: 20))
                                Text(readiness.rawValue)
                                    .font(.system(size: 11))
                            }
                            .foregroundColor(profile?.promotionReadiness == readiness ? Color(hex: readiness.color) : ModernColors.textTertiary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(profile?.promotionReadiness == readiness ? Color(hex: readiness.color).opacity(0.15) : Color.white.opacity(0.03))
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Strengths
                VStack(alignment: .leading, spacing: 6) {
                    Text("Strengths")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ModernColors.textTertiary)

                    if let strengths = profile?.strengths, !strengths.isEmpty {
                        FlowLayout(spacing: 8) {
                            ForEach(strengths, id: \.self) { strength in
                                Text(strength)
                                    .font(.system(size: 12))
                                    .foregroundColor(ModernColors.accentGreen)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(ModernColors.accentGreen.opacity(0.15))
                                    .cornerRadius(8)
                            }
                        }
                    } else {
                        Text("No strengths recorded")
                            .font(.system(size: 13))
                            .foregroundColor(ModernColors.textTertiary)
                    }
                }

                // Areas for growth
                VStack(alignment: .leading, spacing: 6) {
                    Text("Areas for Growth")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ModernColors.textTertiary)

                    if let areas = profile?.areasForGrowth, !areas.isEmpty {
                        FlowLayout(spacing: 8) {
                            ForEach(areas, id: \.self) { area in
                                Text(area)
                                    .font(.system(size: 12))
                                    .foregroundColor(ModernColors.orange)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(ModernColors.orange.opacity(0.15))
                                    .cornerRadius(8)
                            }
                        }
                    } else {
                        Text("No areas recorded")
                            .font(.system(size: 13))
                            .foregroundColor(ModernColors.textTertiary)
                    }
                }
            }
        }
        .padding(20)
        .glassCard()
    }

    private func iconForReadiness(_ readiness: PromotionReadiness) -> String {
        switch readiness {
        case .notReady: return "xmark.circle"
        case .developing: return "arrow.up.circle"
        case .almostReady: return "clock"
        case .ready: return "checkmark.circle"
        case .exceeding: return "star.circle"
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var positions: [CGPoint] = []
        var size: CGSize = .zero

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }
                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
                self.size.width = max(self.size.width, x)
            }
            self.size.height = y + rowHeight
        }
    }
}

// MARK: - Skill Card

struct SkillCard: View {
    let skill: Skill
    let onDelete: () -> Void

    private func colorForLevel(_ level: SkillLevel) -> Color {
        switch level {
        case .beginner: return ModernColors.textTertiary
        case .developing: return ModernColors.orange
        case .proficient: return ModernColors.yellow
        case .advanced: return ModernColors.accentGreen
        case .expert: return ModernColors.cyan
        }
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(skill.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ModernColors.textPrimary)

                HStack(spacing: 4) {
                    ForEach(0..<5) { index in
                        Circle()
                            .fill(index < skill.level.rawValue ? colorForLevel(skill.level) : Color.white.opacity(0.1))
                            .frame(width: 8, height: 8)
                    }
                    Text(skill.level.name)
                        .font(.system(size: 11))
                        .foregroundColor(ModernColors.textTertiary)
                }
            }

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 12))
                    .foregroundColor(ModernColors.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(10)
    }
}

// MARK: - Training Card

struct TrainingCard: View {
    let training: Training
    let onDelete: () -> Void

    private func iconForStatus(_ status: TrainingStatus) -> String {
        switch status {
        case .notStarted: return "circle"
        case .inProgress: return "clock"
        case .completed: return "checkmark.circle.fill"
        case .onHold: return "pause.circle"
        case .cancelled: return "xmark.circle"
        }
    }

    var body: some View {
        HStack {
            Image(systemName: iconForStatus(training.status))
                .font(.system(size: 20))
                .foregroundColor(Color(hex: training.status.color))
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(training.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ModernColors.textPrimary)

                HStack(spacing: 8) {
                    Text(training.type.rawValue)
                        .font(.system(size: 11))
                        .foregroundColor(ModernColors.textTertiary)

                    if let date = training.completionDate {
                        Text("Completed \(date.formatted(date: .abbreviated, time: .omitted))")
                            .font(.system(size: 11))
                            .foregroundColor(ModernColors.accentGreen)
                    } else if let date = training.startDate {
                        Text("Started: \(date.formatted(date: .abbreviated, time: .omitted))")
                            .font(.system(size: 11))
                            .foregroundColor(ModernColors.orange)
                    }
                }
            }

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 12))
                    .foregroundColor(ModernColors.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(10)
    }
}

// MARK: - Add Training View

struct AddTrainingView: View {
    @Environment(\.dismiss) var dismiss
    let onAdd: (Training) -> Void

    @State private var title = ""
    @State private var type: TrainingType = .course
    @State private var provider = ""
    @State private var status: TrainingStatus = .notStarted
    @State private var startDate = Date()

    var body: some View {
        ZStack {
            ModernColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Text("Add Training")
                        .font(.system(size: 20, weight: .bold))
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
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Title")
                                .formLabel()
                            TextField("e.g., AWS Certification", text: $title)
                                .formTextField()
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Type")
                                .formLabel()
                            Picker("", selection: $type) {
                                ForEach(TrainingType.allCases, id: \.self) { t in
                                    Text(t.rawValue).tag(t)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Provider (optional)")
                                .formLabel()
                            TextField("e.g., Coursera, LinkedIn Learning", text: $provider)
                                .formTextField()
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Status")
                                .formLabel()
                            Picker("", selection: $status) {
                                ForEach(TrainingStatus.allCases, id: \.self) { s in
                                    Text(s.rawValue).tag(s)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Start Date")
                                .formLabel()
                            DatePicker("", selection: $startDate, displayedComponents: .date)
                                .labelsHidden()
                        }

                        Button {
                            let training = Training(
                                title: title,
                                type: type,
                                provider: provider.isEmpty ? nil : provider,
                                status: status
                            )
                            onAdd(training)
                            dismiss()
                        } label: {
                            Text("Add Training")
                                .frame(maxWidth: .infinity)
                                .primaryButton()
                        }
                        .buttonStyle(.plain)
                        .disabled(title.isEmpty)
                    }
                    .padding(24)
                }
            }
        }
        .frame(width: 450, height: 550)
    }
}

#Preview {
    CareerView()
        .environmentObject(DataStore.shared)
}
