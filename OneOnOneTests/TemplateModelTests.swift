//
//  TemplateModelTests.swift
//  OneOnOneTests
//
//  Unit tests for MeetingTemplate and AgendaItem
//  Created by Jordan Koch on 2026-05-01.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import XCTest
@testable import OneOnOne

final class TemplateModelTests: XCTestCase {

    // MARK: - MeetingTemplate

    func testTemplateDefaultInit() {
        let template = MeetingTemplate(name: "Custom Template")

        XCTAssertEqual(template.name, "Custom Template")
        XCTAssertNil(template.description)
        XCTAssertEqual(template.meetingType, .oneOnOne)
        XCTAssertEqual(template.defaultDuration, 3600)
        XCTAssertTrue(template.agendaItems.isEmpty)
        XCTAssertTrue(template.suggestedQuestions.isEmpty)
        XCTAssertFalse(template.isBuiltIn)
    }

    // MARK: - Agenda Generation

    func testGenerateAgendaWithDurations() {
        let template = MeetingTemplate(
            name: "Test",
            agendaItems: [
                AgendaItem(title: "Intro", duration: 300),
                AgendaItem(title: "Discussion", duration: 900),
                AgendaItem(title: "Wrap up", duration: 0)
            ]
        )

        let agenda = template.generateAgenda()
        XCTAssertTrue(agenda.contains("1. Intro (5 min)"))
        XCTAssertTrue(agenda.contains("2. Discussion (15 min)"))
        XCTAssertTrue(agenda.contains("3. Wrap up"))
        XCTAssertFalse(agenda.contains("3. Wrap up ("), "Zero-duration items should not show duration")
    }

    func testGenerateAgendaEmpty() {
        let template = MeetingTemplate(name: "Empty")
        XCTAssertEqual(template.generateAgenda(), "")
    }

    // MARK: - Built-in Templates

    func testBuiltInTemplatesCount() {
        let templates = MeetingTemplate.builtInTemplates
        XCTAssertEqual(templates.count, 8, "Should have 8 built-in templates")
    }

    func testBuiltInTemplatesAreMarkedBuiltIn() {
        for template in MeetingTemplate.builtInTemplates {
            XCTAssertTrue(template.isBuiltIn, "\(template.name) should be marked as built-in")
        }
    }

    func testBuiltInTemplatesHaveAgendaItems() {
        for template in MeetingTemplate.builtInTemplates {
            XCTAssertFalse(template.agendaItems.isEmpty, "\(template.name) should have agenda items")
        }
    }

    func testBuiltInTemplateNames() {
        let names = MeetingTemplate.builtInTemplates.map(\.name)
        XCTAssertTrue(names.contains("1:1 Check-in"))
        XCTAssertTrue(names.contains("Performance Review"))
        XCTAssertTrue(names.contains("Project Kickoff"))
        XCTAssertTrue(names.contains("Daily Stand-up"))
        XCTAssertTrue(names.contains("Sprint Retrospective"))
        XCTAssertTrue(names.contains("Career Development"))
        XCTAssertTrue(names.contains("Skip Level"))
        XCTAssertTrue(names.contains("Interview"))
    }

    func testStandUpDuration() {
        let standUp = MeetingTemplate.builtInTemplates.first { $0.name == "Daily Stand-up" }
        XCTAssertNotNil(standUp)
        XCTAssertEqual(standUp?.defaultDuration, 900, "Stand-up should be 15 minutes")
    }

    // MARK: - AgendaItem

    func testAgendaItemInit() {
        let item = AgendaItem(title: "Review goals", description: "Q2 goals", duration: 600, isRequired: true)
        XCTAssertEqual(item.title, "Review goals")
        XCTAssertEqual(item.description, "Q2 goals")
        XCTAssertEqual(item.duration, 600)
        XCTAssertTrue(item.isRequired)
    }

    func testAgendaItemDefaults() {
        let item = AgendaItem(title: "Optional topic")
        XCTAssertNil(item.description)
        XCTAssertEqual(item.duration, 0)
        XCTAssertFalse(item.isRequired)
    }

    // MARK: - Codable

    func testTemplateCodable() throws {
        let template = MeetingTemplate(
            name: "Codable Test",
            description: "Testing",
            meetingType: .review,
            agendaItems: [AgendaItem(title: "Item 1", duration: 300)],
            suggestedQuestions: ["How is it going?"]
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(template)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(MeetingTemplate.self, from: data)

        XCTAssertEqual(decoded.id, template.id)
        XCTAssertEqual(decoded.name, "Codable Test")
        XCTAssertEqual(decoded.meetingType, .review)
        XCTAssertEqual(decoded.agendaItems.count, 1)
        XCTAssertEqual(decoded.suggestedQuestions.count, 1)
    }
}
