//
//  CareerDevelopmentModelTests.swift
//  OneOnOneTests
//
//  Unit tests for Skill, CareerProfile, Training, and related enums
//  Created by Jordan Koch on 2026-05-01.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import XCTest
@testable import OneOnOne

final class CareerDevelopmentModelTests: XCTestCase {

    // MARK: - Skill

    func testSkillDefaultInit() {
        let skill = Skill(name: "Swift")
        XCTAssertEqual(skill.name, "Swift")
        XCTAssertEqual(skill.category, .technical)
        XCTAssertEqual(skill.level, .beginner)
        XCTAssertNil(skill.targetLevel)
        XCTAssertNil(skill.notes)
    }

    func testSkillHasGap() {
        let skill = Skill(name: "Leadership", level: .developing, targetLevel: .advanced)
        XCTAssertTrue(skill.hasGap)
        XCTAssertEqual(skill.gapSize, 2) // advanced(4) - developing(2)
    }

    func testSkillNoGapWhenAtTarget() {
        let skill = Skill(name: "Swift", level: .expert, targetLevel: .expert)
        XCTAssertFalse(skill.hasGap)
        XCTAssertEqual(skill.gapSize, 0)
    }

    func testSkillNoGapWhenNoTarget() {
        let skill = Skill(name: "Python")
        XCTAssertFalse(skill.hasGap)
        XCTAssertEqual(skill.gapSize, 0)
    }

    func testSkillNoGapWhenExceedingTarget() {
        let skill = Skill(name: "Swift", level: .expert, targetLevel: .proficient)
        XCTAssertFalse(skill.hasGap)
        XCTAssertEqual(skill.gapSize, 0)
    }

    // MARK: - SkillCategory

    func testSkillCategoryCases() {
        XCTAssertEqual(SkillCategory.allCases.count, 8)
        for cat in SkillCategory.allCases {
            XCTAssertFalse(cat.icon.isEmpty)
            XCTAssertTrue(cat.color.hasPrefix("#"))
        }
    }

    // MARK: - SkillLevel

    func testSkillLevelRawValues() {
        XCTAssertEqual(SkillLevel.beginner.rawValue, 1)
        XCTAssertEqual(SkillLevel.developing.rawValue, 2)
        XCTAssertEqual(SkillLevel.proficient.rawValue, 3)
        XCTAssertEqual(SkillLevel.advanced.rawValue, 4)
        XCTAssertEqual(SkillLevel.expert.rawValue, 5)
    }

    func testSkillLevelHasNameAndDescription() {
        for level in SkillLevel.allCases {
            XCTAssertFalse(level.name.isEmpty)
            XCTAssertFalse(level.description.isEmpty)
        }
    }

    // MARK: - CareerProfile

    func testCareerProfileInit() {
        let personId = UUID()
        let profile = CareerProfile(personId: personId)

        XCTAssertEqual(profile.personId, personId)
        XCTAssertNil(profile.currentRole)
        XCTAssertNil(profile.targetRole)
        XCTAssertNil(profile.careerGoals)
        XCTAssertTrue(profile.skills.isEmpty)
        XCTAssertTrue(profile.trainings.isEmpty)
        XCTAssertTrue(profile.strengths.isEmpty)
        XCTAssertTrue(profile.areasForGrowth.isEmpty)
        XCTAssertEqual(profile.promotionReadiness, .notReady)
    }

    func testCareerProfileSkillGapCount() {
        let profile = CareerProfile(
            personId: UUID(),
            skills: [
                Skill(name: "Swift", level: .proficient, targetLevel: .expert),
                Skill(name: "Python", level: .expert, targetLevel: .expert),
                Skill(name: "Leadership", level: .developing, targetLevel: .advanced)
            ]
        )
        XCTAssertEqual(profile.skillGapCount, 2)
    }

    func testCareerProfileTrainingCounts() {
        let profile = CareerProfile(
            personId: UUID(),
            trainings: [
                Training(title: "Swift Advanced", status: .completed),
                Training(title: "SwiftUI", status: .inProgress),
                Training(title: "Kotlin", status: .notStarted),
                Training(title: "Docker", status: .completed)
            ]
        )
        XCTAssertEqual(profile.completedTrainings, 2)
        XCTAssertEqual(profile.inProgressTrainings, 1)
    }

    // MARK: - Training

    func testTrainingInit() {
        let training = Training(title: "AWS Certification", type: .certification, provider: "AWS")
        XCTAssertEqual(training.title, "AWS Certification")
        XCTAssertEqual(training.type, .certification)
        XCTAssertEqual(training.provider, "AWS")
        XCTAssertEqual(training.status, .notStarted)
    }

    // MARK: - PromotionReadiness

    func testPromotionReadinessCases() {
        XCTAssertEqual(PromotionReadiness.allCases.count, 5)
        for readiness in PromotionReadiness.allCases {
            XCTAssertTrue(readiness.color.hasPrefix("#"))
            XCTAssertFalse(readiness.description.isEmpty)
        }
    }

    // MARK: - TrainingType & TrainingStatus

    func testTrainingTypeCases() {
        XCTAssertEqual(TrainingType.allCases.count, 8)
        for tt in TrainingType.allCases {
            XCTAssertFalse(tt.icon.isEmpty)
        }
    }

    func testTrainingStatusCases() {
        XCTAssertEqual(TrainingStatus.allCases.count, 5)
        for ts in TrainingStatus.allCases {
            XCTAssertTrue(ts.color.hasPrefix("#"))
        }
    }

    // MARK: - Codable

    func testCareerProfileCodable() throws {
        let profile = CareerProfile(
            personId: UUID(),
            currentRole: "Senior Engineer",
            targetRole: "Staff Engineer",
            skills: [Skill(name: "Swift", level: .advanced)]
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(profile)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(CareerProfile.self, from: data)

        XCTAssertEqual(decoded.id, profile.id)
        XCTAssertEqual(decoded.currentRole, "Senior Engineer")
        XCTAssertEqual(decoded.skills.count, 1)
    }
}
