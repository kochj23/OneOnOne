//
//  SentimentModelTests.swift
//  OneOnOneTests
//
//  Unit tests for Sentiment, RelationshipHealth, and related enums
//  Created by Jordan Koch on 2026-05-01.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import XCTest
@testable import OneOnOne

final class SentimentModelTests: XCTestCase {

    // MARK: - SentimentEntry

    func testSentimentEntryDefaultInit() {
        let personId = UUID()
        let entry = SentimentEntry(personId: personId)

        XCTAssertEqual(entry.personId, personId)
        XCTAssertEqual(entry.sentiment, .neutral)
        XCTAssertEqual(entry.energyLevel, .moderate)
        XCTAssertEqual(entry.engagementLevel, .engaged)
        XCTAssertTrue(entry.stressIndicators.isEmpty)
        XCTAssertNil(entry.notes)
    }

    func testOverallScoreNeutral() {
        let entry = SentimentEntry(
            personId: UUID(),
            sentiment: .neutral,     // 3
            energyLevel: .moderate,  // 3
            engagementLevel: .neutral // 3
        )
        // Each normalized: (3/5) = 0.6. Average: 0.6. No stress penalty.
        XCTAssertEqual(entry.overallScore, 0.6, accuracy: 0.001)
    }

    func testOverallScoreMaximum() {
        let entry = SentimentEntry(
            personId: UUID(),
            sentiment: .veryPositive,     // 5
            energyLevel: .veryHigh,       // 5
            engagementLevel: .highlyEngaged // 5
        )
        XCTAssertEqual(entry.overallScore, 1.0, accuracy: 0.001)
    }

    func testOverallScoreMinimum() {
        let entry = SentimentEntry(
            personId: UUID(),
            sentiment: .veryNegative,  // 1
            energyLevel: .veryLow,     // 1
            engagementLevel: .disengaged // 1
        )
        // Each: 1/5 = 0.2, avg = 0.2
        XCTAssertEqual(entry.overallScore, 0.2, accuracy: 0.001)
    }

    func testOverallScoreWithStressPenalty() {
        let entry = SentimentEntry(
            personId: UUID(),
            sentiment: .neutral,
            energyLevel: .moderate,
            engagementLevel: .neutral,
            stressIndicators: [.workload, .deadlines, .teamConflict]
        )
        // Base: 0.6, penalty: 3 * 0.1 = 0.3 => 0.3
        XCTAssertEqual(entry.overallScore, 0.3, accuracy: 0.001)
    }

    func testOverallScoreFlooredAtZero() {
        let entry = SentimentEntry(
            personId: UUID(),
            sentiment: .veryNegative,
            energyLevel: .veryLow,
            engagementLevel: .disengaged,
            stressIndicators: [.workload, .deadlines, .teamConflict, .resources, .unclear]
        )
        // Base: 0.2, penalty: 5 * 0.1 = 0.5. Result would be -0.3, floored to 0.
        XCTAssertEqual(entry.overallScore, 0.0, accuracy: 0.001)
    }

    // MARK: - SentimentLevel

    func testSentimentLevelRawValues() {
        XCTAssertEqual(SentimentLevel.veryNegative.rawValue, 1)
        XCTAssertEqual(SentimentLevel.negative.rawValue, 2)
        XCTAssertEqual(SentimentLevel.neutral.rawValue, 3)
        XCTAssertEqual(SentimentLevel.positive.rawValue, 4)
        XCTAssertEqual(SentimentLevel.veryPositive.rawValue, 5)
    }

    func testSentimentLevelCaseIterable() {
        XCTAssertEqual(SentimentLevel.allCases.count, 5)
    }

    func testSentimentLevelHasNameIconColor() {
        for level in SentimentLevel.allCases {
            XCTAssertFalse(level.name.isEmpty)
            XCTAssertFalse(level.icon.isEmpty)
            XCTAssertTrue(level.color.hasPrefix("#"))
        }
    }

    // MARK: - EnergyLevel

    func testEnergyLevelCases() {
        XCTAssertEqual(EnergyLevel.allCases.count, 5)
        XCTAssertEqual(EnergyLevel.veryLow.rawValue, 1)
        XCTAssertEqual(EnergyLevel.veryHigh.rawValue, 5)
    }

    // MARK: - EngagementLevel

    func testEngagementLevelCases() {
        XCTAssertEqual(EngagementLevel.allCases.count, 5)
        XCTAssertEqual(EngagementLevel.disengaged.rawValue, 1)
        XCTAssertEqual(EngagementLevel.highlyEngaged.rawValue, 5)
    }

    // MARK: - StressIndicator

    func testStressIndicatorCases() {
        XCTAssertEqual(StressIndicator.allCases.count, 9)
        for indicator in StressIndicator.allCases {
            XCTAssertFalse(indicator.icon.isEmpty)
            XCTAssertFalse(indicator.rawValue.isEmpty)
        }
    }

    // MARK: - RelationshipHealth

    func testHealthLevelExcellent() {
        let health = RelationshipHealth(
            id: UUID(), personId: UUID(),
            healthScore: 0.9, trend: .improving,
            sentimentHistory: [], riskFactors: [], recommendations: []
        )
        XCTAssertEqual(health.healthLevel, .excellent)
    }

    func testHealthLevelGood() {
        let health = RelationshipHealth(
            id: UUID(), personId: UUID(),
            healthScore: 0.7, trend: .stable,
            sentimentHistory: [], riskFactors: [], recommendations: []
        )
        XCTAssertEqual(health.healthLevel, .good)
    }

    func testHealthLevelFair() {
        let health = RelationshipHealth(
            id: UUID(), personId: UUID(),
            healthScore: 0.5, trend: .stable,
            sentimentHistory: [], riskFactors: [], recommendations: []
        )
        XCTAssertEqual(health.healthLevel, .fair)
    }

    func testHealthLevelPoor() {
        let health = RelationshipHealth(
            id: UUID(), personId: UUID(),
            healthScore: 0.3, trend: .declining,
            sentimentHistory: [], riskFactors: [], recommendations: []
        )
        XCTAssertEqual(health.healthLevel, .poor)
    }

    func testHealthLevelCritical() {
        let health = RelationshipHealth(
            id: UUID(), personId: UUID(),
            healthScore: 0.1, trend: .declining,
            sentimentHistory: [], riskFactors: [], recommendations: []
        )
        XCTAssertEqual(health.healthLevel, .critical)
    }

    // MARK: - HealthTrend

    func testHealthTrendValues() {
        XCTAssertEqual(HealthTrend.improving.rawValue, "Improving")
        XCTAssertEqual(HealthTrend.stable.rawValue, "Stable")
        XCTAssertEqual(HealthTrend.declining.rawValue, "Declining")

        for trend in [HealthTrend.improving, .stable, .declining] {
            XCTAssertFalse(trend.icon.isEmpty)
            XCTAssertTrue(trend.color.hasPrefix("#"))
        }
    }

    // MARK: - Codable

    func testSentimentEntryCodable() throws {
        let entry = SentimentEntry(
            personId: UUID(),
            sentiment: .positive,
            energyLevel: .high,
            engagementLevel: .engaged,
            stressIndicators: [.workload],
            notes: "Good week"
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(entry)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(SentimentEntry.self, from: data)

        XCTAssertEqual(decoded.id, entry.id)
        XCTAssertEqual(decoded.sentiment, .positive)
        XCTAssertEqual(decoded.stressIndicators, [.workload])
    }
}
