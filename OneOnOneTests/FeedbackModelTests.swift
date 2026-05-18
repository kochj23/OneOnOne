//
//  FeedbackModelTests.swift
//  OneOnOneTests
//
//  Unit tests for Feedback, FeedbackType, FeedbackDirection, PraiseSummary
//  Created by Jordan Koch on 2026-05-01.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import XCTest
@testable import OneOnOne

final class FeedbackModelTests: XCTestCase {

    // MARK: - Initialization

    func testFeedbackDefaultInit() {
        let personId = UUID()
        let fb = Feedback(
            personId: personId,
            type: .praise,
            direction: .given,
            content: "Great presentation"
        )

        XCTAssertEqual(fb.personId, personId)
        XCTAssertEqual(fb.type, .praise)
        XCTAssertEqual(fb.direction, .given)
        XCTAssertEqual(fb.content, "Great presentation")
        XCTAssertNil(fb.context)
        XCTAssertNil(fb.meetingId)
        XCTAssertTrue(fb.tags.isEmpty)
    }

    func testFeedbackCustomInit() {
        let personId = UUID()
        let meetingId = UUID()
        let fb = Feedback(
            personId: personId,
            type: .constructive,
            direction: .received,
            content: "Could improve documentation",
            context: "Code review",
            meetingId: meetingId,
            tags: ["docs", "code-quality"]
        )

        XCTAssertEqual(fb.context, "Code review")
        XCTAssertEqual(fb.meetingId, meetingId)
        XCTAssertEqual(fb.tags, ["docs", "code-quality"])
    }

    // MARK: - Codable

    func testFeedbackEncodeDecode() throws {
        let personId = UUID()
        let fb = Feedback(
            personId: personId,
            type: .achievement,
            direction: .given,
            content: "Shipped on time"
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(fb)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Feedback.self, from: data)

        XCTAssertEqual(decoded.id, fb.id)
        XCTAssertEqual(decoded.type, .achievement)
        XCTAssertEqual(decoded.direction, .given)
        XCTAssertEqual(decoded.content, "Shipped on time")
    }

    // MARK: - FeedbackType

    func testFeedbackTypeCases() {
        XCTAssertEqual(FeedbackType.allCases.count, 6)
    }

    func testFeedbackTypeHasIconAndColor() {
        for ft in FeedbackType.allCases {
            XCTAssertFalse(ft.icon.isEmpty, "\(ft) should have an icon")
            XCTAssertTrue(ft.color.hasPrefix("#"), "\(ft) color should be hex")
        }
    }

    // MARK: - FeedbackDirection

    func testFeedbackDirectionCases() {
        XCTAssertEqual(FeedbackDirection.allCases.count, 2)
        XCTAssertEqual(FeedbackDirection.given.rawValue, "Given")
        XCTAssertEqual(FeedbackDirection.received.rawValue, "Received")
    }

    func testFeedbackDirectionIcons() {
        XCTAssertFalse(FeedbackDirection.given.icon.isEmpty)
        XCTAssertFalse(FeedbackDirection.received.icon.isEmpty)
    }

    // MARK: - PraiseSummary

    func testPraiseRatioCalculation() {
        let summary = PraiseSummary(
            personId: UUID(),
            totalPraise: 10,
            praiseGiven: 4,
            praiseReceived: 6,
            recentPraise: [],
            topTags: []
        )
        XCTAssertEqual(summary.praiseRatio, 1.5, accuracy: 0.001)
    }

    func testPraiseRatioZeroGiven() {
        let summary = PraiseSummary(
            personId: UUID(),
            totalPraise: 5,
            praiseGiven: 0,
            praiseReceived: 5,
            recentPraise: [],
            topTags: []
        )
        XCTAssertEqual(summary.praiseRatio, 0.0, "Ratio should be 0 when no praise given")
    }
}
