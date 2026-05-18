//
//  PersonModelTests.swift
//  OneOnOneTests
//
//  Unit tests for Person model and MeetingFrequency
//  Created by Jordan Koch on 2026-05-01.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import XCTest
@testable import OneOnOne

final class PersonModelTests: XCTestCase {

    // MARK: - Initialization

    func testPersonDefaultInitialization() {
        let person = Person(name: "Alice Smith")

        XCTAssertEqual(person.name, "Alice Smith")
        XCTAssertNil(person.email)
        XCTAssertNil(person.title)
        XCTAssertNil(person.department)
        XCTAssertNil(person.notes)
        XCTAssertFalse(person.avatarColor.isEmpty)
        XCTAssertTrue(person.tags.isEmpty)
        XCTAssertEqual(person.meetingFrequency, .weekly)
        XCTAssertNil(person.lastMeetingDate)
        XCTAssertNil(person.nextScheduledMeeting)
    }

    func testPersonCustomInitialization() {
        let person = Person(
            name: "Bob Jones",
            email: "bob@example.com",
            title: "Senior Engineer",
            department: "Platform",
            notes: "Great communicator",
            avatarColor: "#FF5999",
            tags: ["team-lead"],
            meetingFrequency: .biweekly
        )

        XCTAssertEqual(person.email, "bob@example.com")
        XCTAssertEqual(person.title, "Senior Engineer")
        XCTAssertEqual(person.department, "Platform")
        XCTAssertEqual(person.notes, "Great communicator")
        XCTAssertEqual(person.avatarColor, "#FF5999")
        XCTAssertEqual(person.tags, ["team-lead"])
        XCTAssertEqual(person.meetingFrequency, .biweekly)
    }

    // MARK: - Initials

    func testInitialsTwoNames() {
        let person = Person(name: "Alice Smith")
        XCTAssertEqual(person.initials, "AS")
    }

    func testInitialsThreeNames() {
        let person = Person(name: "Alice Marie Smith")
        XCTAssertEqual(person.initials, "AM")
    }

    func testInitialsSingleName() {
        let person = Person(name: "Alice")
        XCTAssertEqual(person.initials, "AL")
    }

    func testInitialsEmptyName() {
        let person = Person(name: "")
        XCTAssertEqual(person.initials, "?")
    }

    func testInitialsLowercase() {
        let person = Person(name: "alice smith")
        XCTAssertEqual(person.initials, "AS")
    }

    // MARK: - Display Title

    func testDisplayTitleBoth() {
        let person = Person(name: "X", title: "Engineer", department: "iOS")
        XCTAssertEqual(person.displayTitle, "Engineer - iOS")
    }

    func testDisplayTitleOnly() {
        let person = Person(name: "X", title: "Engineer")
        XCTAssertEqual(person.displayTitle, "Engineer")
    }

    func testDisplayDepartmentOnly() {
        let person = Person(name: "X", department: "iOS")
        XCTAssertEqual(person.displayTitle, "iOS")
    }

    func testDisplayTitleEmpty() {
        let person = Person(name: "X")
        XCTAssertEqual(person.displayTitle, "")
    }

    // MARK: - Avatar Color

    func testRandomAvatarColorIsValid() {
        let validColors = ["#3BDAFC", "#9966FF", "#FF5999", "#FF9933", "#4DE094", "#5AB3FF"]
        for _ in 0..<20 {
            let color = Person.randomAvatarColor()
            XCTAssertTrue(validColors.contains(color), "Color \(color) should be in the valid set")
        }
    }

    // MARK: - Codable

    func testPersonEncodeDecode() throws {
        let person = Person(
            name: "Test User",
            email: "test@example.com",
            title: "Manager",
            department: "Eng",
            tags: ["vip"],
            meetingFrequency: .monthly
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(person)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Person.self, from: data)

        XCTAssertEqual(decoded.id, person.id)
        XCTAssertEqual(decoded.name, "Test User")
        XCTAssertEqual(decoded.email, "test@example.com")
        XCTAssertEqual(decoded.meetingFrequency, .monthly)
    }

    // MARK: - Hashable

    func testPersonHashableIdentity() {
        // Person uses synthesized Hashable, so same-ID different-name are distinct in Set
        // because Person compares all fields (unlike Meeting which overrides == to use id only)
        let id = UUID()
        let date = Date()
        let p1 = Person(id: id, name: "Alice")
        // Two Person values created from the same init call at different times
        // will have different createdAt/updatedAt, so they differ.
        // Verify that at minimum, identical structs hash equally:
        var p2 = p1
        var set: Set<Person> = [p1]
        set.insert(p2)
        XCTAssertEqual(set.count, 1, "Identical Person values should deduplicate in Set")
    }

    func testPersonEqualitySameValues() {
        let id = UUID()
        let p1 = Person(id: id, name: "Alice", avatarColor: "#3BDAFC")
        let p2 = p1 // copy
        XCTAssertEqual(p1, p2)
    }

    // MARK: - MeetingFrequency

    func testCalendarDays() {
        XCTAssertEqual(MeetingFrequency.daily.calendarDays, 1)
        XCTAssertEqual(MeetingFrequency.weekly.calendarDays, 7)
        XCTAssertEqual(MeetingFrequency.biweekly.calendarDays, 14)
        XCTAssertEqual(MeetingFrequency.monthly.calendarDays, 30)
        XCTAssertEqual(MeetingFrequency.quarterly.calendarDays, 90)
        XCTAssertNil(MeetingFrequency.asNeeded.calendarDays)
    }

    func testMeetingFrequencyCaseIterable() {
        XCTAssertEqual(MeetingFrequency.allCases.count, 6)
    }
}
