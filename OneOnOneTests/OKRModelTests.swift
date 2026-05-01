//
//  OKRModelTests.swift
//  OneOnOneTests
//
//  Unit tests for Objective, KeyResult, and OKR enums
//  Created by Jordan Koch on 2026-05-01.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import XCTest
@testable import OneOnOne

final class OKRModelTests: XCTestCase {

    // MARK: - Objective

    func testObjectiveDefaultInit() {
        let obj = Objective(title: "Improve reliability")
        XCTAssertEqual(obj.title, "Improve reliability")
        XCTAssertEqual(obj.level, .individual)
        XCTAssertEqual(obj.status, .onTrack)
        XCTAssertTrue(obj.keyResults.isEmpty)
        XCTAssertEqual(obj.progress, 0.0)
    }

    func testObjectiveProgressCalculation() {
        let obj = Objective(
            title: "Growth",
            keyResults: [
                KeyResult(title: "Revenue", startValue: 0, currentValue: 50, targetValue: 100),
                KeyResult(title: "Users", startValue: 0, currentValue: 100, targetValue: 100)
            ]
        )
        // KR1 progress = 0.5, KR2 progress = 1.0, average = 0.75
        XCTAssertEqual(obj.progress, 0.75, accuracy: 0.001)
    }

    func testObjectiveProgressNoKeyResults() {
        let obj = Objective(title: "Empty")
        XCTAssertEqual(obj.progress, 0.0)
    }

    func testObjectiveCompletedKeyResults() {
        let obj = Objective(
            title: "Test",
            keyResults: [
                KeyResult(title: "A", startValue: 0, currentValue: 100, targetValue: 100),
                KeyResult(title: "B", startValue: 0, currentValue: 50, targetValue: 100),
                KeyResult(title: "C", startValue: 0, currentValue: 100, targetValue: 100)
            ]
        )
        XCTAssertEqual(obj.completedKeyResults, 2)
    }

    func testObjectiveIsComplete() {
        let obj = Objective(
            title: "Done",
            keyResults: [
                KeyResult(title: "A", startValue: 0, currentValue: 100, targetValue: 100)
            ]
        )
        XCTAssertTrue(obj.isComplete)
    }

    func testObjectiveIsNotComplete() {
        let obj = Objective(
            title: "WIP",
            keyResults: [
                KeyResult(title: "A", startValue: 0, currentValue: 50, targetValue: 100)
            ]
        )
        XCTAssertFalse(obj.isComplete)
    }

    // MARK: - KeyResult Progress

    func testKeyResultIncreaseProgress() {
        let kr = KeyResult(title: "Revenue", metricType: .increase, startValue: 0, currentValue: 75, targetValue: 100)
        XCTAssertEqual(kr.progress, 0.75, accuracy: 0.001)
    }

    func testKeyResultIncreaseProgressCapped() {
        let kr = KeyResult(title: "Revenue", metricType: .increase, startValue: 0, currentValue: 150, targetValue: 100)
        XCTAssertEqual(kr.progress, 1.0, "Progress should be capped at 1.0")
    }

    func testKeyResultDecreaseProgress() {
        // Start at 100, target is 0, currently at 25 (75% of the way)
        let kr = KeyResult(title: "Bugs", metricType: .decrease, startValue: 100, currentValue: 25, targetValue: 0)
        XCTAssertEqual(kr.progress, 0.75, accuracy: 0.001)
    }

    func testKeyResultDecreaseFullyAchieved() {
        let kr = KeyResult(title: "Bugs", metricType: .decrease, startValue: 100, currentValue: 0, targetValue: 0)
        XCTAssertEqual(kr.progress, 1.0, accuracy: 0.001)
    }

    func testKeyResultBinaryAchieved() {
        let kr = KeyResult(title: "Launch", metricType: .binary, startValue: 0, currentValue: 1, targetValue: 1)
        XCTAssertEqual(kr.progress, 1.0)
    }

    func testKeyResultBinaryNotAchieved() {
        let kr = KeyResult(title: "Launch", metricType: .binary, startValue: 0, currentValue: 0, targetValue: 1)
        XCTAssertEqual(kr.progress, 0.0)
    }

    func testKeyResultMaintainWithinRange() {
        let kr = KeyResult(title: "SLA", metricType: .maintain, startValue: 95, currentValue: 99.5, targetValue: 99.9)
        // Within 10% variance of |start - target| = |95 - 99.9| = 4.9, threshold = 0.49
        // variance = |99.5 - 99.9| = 0.4, which is <= 0.49
        XCTAssertEqual(kr.progress, 1.0, accuracy: 0.001)
    }

    func testKeyResultSameStartAndTarget() {
        let kr = KeyResult(title: "Edge", metricType: .increase, startValue: 50, currentValue: 50, targetValue: 50)
        XCTAssertEqual(kr.progress, 1.0, "When start == target and current >= target, progress should be 1.0")
    }

    // MARK: - KeyResult Formatting

    func testFormattedCurrentWithUnit() {
        let kr = KeyResult(title: "Revenue", currentValue: 50000, targetValue: 100000, unit: "USD")
        XCTAssertEqual(kr.formattedCurrent, "50000 USD")
        XCTAssertEqual(kr.formattedTarget, "100000 USD")
    }

    func testFormattedCurrentWithoutUnit() {
        let kr = KeyResult(title: "Count", currentValue: 42, targetValue: 100)
        XCTAssertEqual(kr.formattedCurrent, "42")
        XCTAssertEqual(kr.formattedTarget, "100")
    }

    func testFormattedCurrentDecimal() {
        let kr = KeyResult(title: "Pct", currentValue: 99.5, targetValue: 100)
        XCTAssertEqual(kr.formattedCurrent, "99.5")
    }

    // MARK: - KRUpdate

    func testKRUpdateInit() {
        let update = KRUpdate(value: 42, notes: "Midway check")
        XCTAssertEqual(update.value, 42)
        XCTAssertEqual(update.notes, "Midway check")
    }

    // MARK: - Enums

    func testMetricTypeCases() {
        XCTAssertEqual(MetricType.allCases.count, 4)
        for mt in MetricType.allCases {
            XCTAssertFalse(mt.icon.isEmpty)
        }
    }

    func testOKRLevelCases() {
        XCTAssertEqual(OKRLevel.allCases.count, 4)
        for level in OKRLevel.allCases {
            XCTAssertFalse(level.icon.isEmpty)
            XCTAssertTrue(level.color.hasPrefix("#"))
        }
    }

    func testOKRStatusCases() {
        XCTAssertEqual(OKRStatus.allCases.count, 5)
        for status in OKRStatus.allCases {
            XCTAssertFalse(status.icon.isEmpty)
            XCTAssertTrue(status.color.hasPrefix("#"))
        }
    }

    // MARK: - Codable

    func testObjectiveEncodeDecode() throws {
        let obj = Objective(
            title: "Test OKR",
            level: .team,
            quarter: "Q2 2026",
            keyResults: [
                KeyResult(title: "KR1", startValue: 0, currentValue: 50, targetValue: 100)
            ],
            status: .atRisk
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(obj)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Objective.self, from: data)

        XCTAssertEqual(decoded.id, obj.id)
        XCTAssertEqual(decoded.title, "Test OKR")
        XCTAssertEqual(decoded.level, .team)
        XCTAssertEqual(decoded.quarter, "Q2 2026")
        XCTAssertEqual(decoded.keyResults.count, 1)
        XCTAssertEqual(decoded.status, .atRisk)
    }
}
