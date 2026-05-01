//
//  IntegrationTests.swift
//  OneOnOneTests
//
//  Integration tests: local API health check, data flow, search behavior
//  Created by Jordan Koch on 2026-05-01.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import XCTest
@testable import OneOnOne

final class IntegrationTests: XCTestCase {

    // MARK: - Nova API Server Health Check (port 37421)

    /// Attempts a health-check GET /api/status on the local Nova API server.
    /// This test will only pass when the OneOnOne app is running.
    /// It is designed for local QE validation, not CI.
    func testNovaAPIStatusEndpoint() async throws {
        let url = URL(string: "http://127.0.0.1:37421/api/status")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 3

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let httpResponse = response as? HTTPURLResponse

            XCTAssertEqual(httpResponse?.statusCode, 200)

            let json = try JSONSerialization.jsonObject(with: data) as? [String: String]
            XCTAssertEqual(json?["status"], "running")
            XCTAssertEqual(json?["app"], "OneOnOne")
            XCTAssertEqual(json?["port"], "37421")
        } catch {
            // If the app is not running, this is expected to fail.
            // Mark as skipped rather than failing the suite.
            throw XCTSkip("OneOnOne app not running -- Nova API health check skipped: \(error.localizedDescription)")
        }
    }

    /// Verifies the /api/people endpoint returns valid JSON array.
    func testNovaAPIPeopleEndpoint() async throws {
        let url = URL(string: "http://127.0.0.1:37421/api/people")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 3

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let httpResponse = response as? HTTPURLResponse

            XCTAssertEqual(httpResponse?.statusCode, 200)

            // Should decode as array (might be empty)
            let json = try JSONSerialization.jsonObject(with: data)
            XCTAssertTrue(json is [Any], "People endpoint should return a JSON array")
        } catch {
            throw XCTSkip("OneOnOne app not running -- skipped: \(error.localizedDescription)")
        }
    }

    /// Verifies the /api/meetings endpoint returns valid JSON array.
    func testNovaAPIMeetingsEndpoint() async throws {
        let url = URL(string: "http://127.0.0.1:37421/api/meetings?limit=5")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 3

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let httpResponse = response as? HTTPURLResponse

            XCTAssertEqual(httpResponse?.statusCode, 200)

            let json = try JSONSerialization.jsonObject(with: data)
            XCTAssertTrue(json is [Any], "Meetings endpoint should return a JSON array")
        } catch {
            throw XCTSkip("OneOnOne app not running -- skipped: \(error.localizedDescription)")
        }
    }

    /// Verifies that an invalid meeting UUID returns 400.
    func testNovaAPIInvalidMeetingUUID() async throws {
        let url = URL(string: "http://127.0.0.1:37421/api/meetings/not-a-uuid")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 3

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let httpResponse = response as? HTTPURLResponse

            XCTAssertEqual(httpResponse?.statusCode, 400)
        } catch {
            throw XCTSkip("OneOnOne app not running -- skipped: \(error.localizedDescription)")
        }
    }

    /// Verifies that a non-existent endpoint returns 404.
    func testNovaAPINotFoundEndpoint() async throws {
        let url = URL(string: "http://127.0.0.1:37421/api/nonexistent")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 3

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let httpResponse = response as? HTTPURLResponse

            XCTAssertEqual(httpResponse?.statusCode, 404)
        } catch {
            throw XCTSkip("OneOnOne app not running -- skipped: \(error.localizedDescription)")
        }
    }

    /// Verifies POST without auth token returns 401.
    func testNovaAPISummarizeRequiresAuth() async throws {
        let url = URL(string: "http://127.0.0.1:37421/api/summarize")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data("{\"content\":\"test\"}".utf8)
        request.timeoutInterval = 3

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let httpResponse = response as? HTTPURLResponse

            XCTAssertEqual(httpResponse?.statusCode, 401, "POST without Bearer token should return 401")
        } catch {
            throw XCTSkip("OneOnOne app not running -- skipped: \(error.localizedDescription)")
        }
    }

    // MARK: - Search Models

    func testSearchFiltersDefaults() {
        let filters = SearchFilters()
        XCTAssertTrue(filters.includeMeetings)
        XCTAssertTrue(filters.includePeople)
        XCTAssertTrue(filters.includeGoals)
        XCTAssertTrue(filters.includeFeedback)
        XCTAssertTrue(filters.includeOKRs)
        XCTAssertNil(filters.startDate)
        XCTAssertNil(filters.endDate)
    }

    func testSearchResultTypeProperties() {
        for resultType in [SearchResultType.meeting, .person, .goal, .feedback, .okr] {
            XCTAssertFalse(resultType.rawValue.isEmpty)
            XCTAssertFalse(resultType.icon.isEmpty)
            XCTAssertTrue(resultType.color.hasPrefix("#"))
        }
    }

    // MARK: - Data Flow: Meeting Creation with Action Items

    func testMeetingCreationDataFlow() {
        let personId = UUID()
        let meetingId = UUID()

        // Create a person
        let person = Person(id: personId, name: "Test Person", title: "Engineer")

        // Create a meeting with action items, decisions, follow-ups
        let actionItem = ActionItem(
            title: "Implement feature X",
            assigneeId: personId,
            priority: .high,
            meetingId: meetingId
        )
        let decision = Decision(
            title: "Use SwiftUI",
            rationale: "Modern framework",
            participants: [personId],
            meetingId: meetingId
        )
        let followUp = FollowUp(
            topic: "Check progress next week",
            meetingId: meetingId
        )

        let meeting = Meeting(
            id: meetingId,
            title: "Sprint Planning",
            attendees: [personId],
            meetingType: .planning,
            notes: "Planned sprint work",
            actionItems: [actionItem],
            decisions: [decision],
            followUps: [followUp]
        )

        // Verify relationships
        XCTAssertTrue(meeting.attendees.contains(personId))
        XCTAssertEqual(meeting.actionItems.first?.assigneeId, personId)
        XCTAssertEqual(meeting.decisions.first?.participants.first, personId)
        XCTAssertEqual(meeting.openActionItemsCount, 1)
        XCTAssertEqual(meeting.completedActionItemsCount, 0)

        // Verify person initials work
        XCTAssertEqual(person.initials, "TP")
    }

    // MARK: - OKR Cascading Relationship

    func testOKRCascadingHierarchy() {
        let companyOKR = Objective(
            title: "Double Revenue",
            level: .company,
            quarter: "Q2 2026"
        )
        let teamOKR = Objective(
            title: "Increase Enterprise Sales",
            level: .team,
            parentId: companyOKR.id,
            quarter: "Q2 2026"
        )
        let individualOKR = Objective(
            title: "Close 5 Enterprise Deals",
            level: .individual,
            parentId: teamOKR.id,
            quarter: "Q2 2026",
            keyResults: [
                KeyResult(title: "Deals Closed", startValue: 0, currentValue: 3, targetValue: 5)
            ]
        )

        XCTAssertEqual(individualOKR.parentId, teamOKR.id)
        XCTAssertEqual(teamOKR.parentId, companyOKR.id)
        XCTAssertNil(companyOKR.parentId)
        XCTAssertEqual(individualOKR.progress, 0.6, accuracy: 0.001)
    }
}
