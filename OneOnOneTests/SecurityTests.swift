//
//  SecurityTests.swift
//  OneOnOneTests
//
//  Security audit tests: credential scanning, input sanitization, data storage
//  Created by Jordan Koch on 2026-05-01.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import XCTest
@testable import OneOnOne

final class SecurityTests: XCTestCase {

    // MARK: - Credential Scanning

    /// Scans all .swift source files for hardcoded API keys, tokens, and passwords.
    /// This test reads the project directory at build time to catch any secrets
    /// that might have slipped through pre-commit hooks.
    func testNoHardcodedCredentials() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // OneOnOneTests/
            .deletingLastPathComponent()  // OneOnOne project root

        let sourceDir = projectRoot.appendingPathComponent("OneOnOne")
        guard FileManager.default.fileExists(atPath: sourceDir.path) else {
            // When running in CI the source tree layout may differ; skip gracefully
            return
        }

        let enumerator = FileManager.default.enumerator(at: sourceDir, includingPropertiesForKeys: nil)
        var violations: [String] = []

        let patterns: [(label: String, regex: String)] = [
            ("AWS Access Key", "AKIA[0-9A-Z]{16}"),
            ("OpenAI/Anthropic API Key", "sk-[a-zA-Z0-9]{20,}"),
            ("GitHub PAT", "ghp_[a-zA-Z0-9]{36}"),
            ("Slack Token", "xox[bpoas]-[a-zA-Z0-9-]+"),
            ("Generic Secret Assignment", "(?i)(password|secret|apikey|api_key)\\s*=\\s*\"[^\"]{8,}\""),
        ]

        while let url = enumerator?.nextObject() as? URL {
            guard url.pathExtension == "swift" else { continue }
            guard !url.path.contains("SecurityTests.swift") else { continue }
            guard !url.path.contains("/build/") else { continue }

            let content = try String(contentsOf: url, encoding: .utf8)

            for (label, pattern) in patterns {
                if let regex = try? NSRegularExpression(pattern: pattern),
                   regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)) != nil {
                    let relativePath = url.path.replacingOccurrences(of: projectRoot.path + "/", with: "")
                    violations.append("\(label) found in \(relativePath)")
                }
            }
        }

        XCTAssertTrue(violations.isEmpty, "Hardcoded credentials detected:\n\(violations.joined(separator: "\n"))")
    }

    // MARK: - Input Sanitization

    func testMeetingNotesAcceptUnicodeWithoutCrash() {
        let meeting = Meeting(
            title: "Unicode test \u{1F680}",
            notes: "Notes with emoji \u{2728} and CJK: \u{4F60}\u{597D} and Arabic: \u{0645}\u{0631}\u{062D}\u{0628}\u{0627}"
        )
        XCTAssertFalse(meeting.title.isEmpty)
        XCTAssertFalse(meeting.notes.isEmpty)
    }

    func testVeryLongStringDoesNotCrash() {
        let longString = String(repeating: "A", count: 100_000)
        let meeting = Meeting(title: longString, notes: longString)
        XCTAssertEqual(meeting.title.count, 100_000)

        // Verify it can be encoded/decoded
        let encoder = JSONEncoder()
        let data = try? encoder.encode(meeting)
        XCTAssertNotNil(data)
    }

    func testSpecialCharactersInPersonName() {
        let person = Person(name: "O'Brien \"Bob\" <script>alert(1)</script>")
        XCTAssertEqual(person.name, "O'Brien \"Bob\" <script>alert(1)</script>")
        XCTAssertFalse(person.initials.isEmpty)
    }

    func testHTMLInjectionInNotes() {
        // Verify that HTML content is stored as-is (no HTML rendering = safe)
        let meeting = Meeting(
            title: "Test",
            notes: "<script>document.cookie</script><img onerror=alert(1) src=x>"
        )
        XCTAssertTrue(meeting.notes.contains("<script>"))
        // Since notes are rendered as plain text / markdown, HTML is not executed.
        // This test documents that the app stores raw text safely.
    }

    func testSQLInjectionPayloadInSearch() {
        // Search queries should be treated as plain text, not SQL
        let maliciousQuery = "'; DROP TABLE meetings; --"
        // The search service uses in-memory array filtering, not SQL,
        // so this should simply not match anything without side effects.
        // We test that the model structures handle this input safely.
        let meeting = Meeting(title: maliciousQuery, notes: "Normal notes")
        XCTAssertEqual(meeting.title, maliciousQuery)
    }

    // MARK: - Data Storage Safety

    func testNoSensitiveFileTypesInProject() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        guard FileManager.default.fileExists(atPath: projectRoot.path) else { return }

        let enumerator = FileManager.default.enumerator(at: projectRoot, includingPropertiesForKeys: nil)
        let sensitiveExtensions = ["p12", "cer", "mobileprovision", "env", "pem", "key"]
        var found: [String] = []

        while let url = enumerator?.nextObject() as? URL {
            if url.path.contains("/build/") || url.path.contains("/.git/") { continue }
            if sensitiveExtensions.contains(url.pathExtension.lowercased()) {
                found.append(url.lastPathComponent)
            }
        }

        XCTAssertTrue(found.isEmpty, "Sensitive files found in project: \(found.joined(separator: ", "))")
    }

    // MARK: - UUID Handling

    func testInvalidUUIDDoesNotCrash() {
        let invalidStrings = ["", "not-a-uuid", "12345", "zzzzzzzz-zzzz-zzzz-zzzz-zzzzzzzzzzzz"]
        for str in invalidStrings {
            XCTAssertNil(UUID(uuidString: str), "\(str) should not produce a valid UUID")
        }
    }

    // MARK: - Codable Safety

    func testDecodeInvalidMeetingTypeGracefully() {
        let json = """
        {
            "id": "00000000-0000-0000-0000-000000000001",
            "title": "Test",
            "date": "2026-05-01T00:00:00Z",
            "duration": 3600,
            "attendees": [],
            "meetingType": "INVALID_TYPE",
            "notes": "",
            "actionItems": [],
            "decisions": [],
            "followUps": [],
            "tags": [],
            "isRecurring": false,
            "createdAt": "2026-05-01T00:00:00Z",
            "updatedAt": "2026-05-01T00:00:00Z"
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // MeetingType uses raw string values; an unknown value should throw
        XCTAssertThrowsError(try decoder.decode(Meeting.self, from: Data(json.utf8)))
    }

    // MARK: - NovaAPI Token (anti-CSRF)

    func testNovaAPITokenNotEmpty() {
        // The anti-CSRF token is generated at init and should never be empty
        let token = UserDefaults.standard.string(forKey: "NovaAPIToken")
        // Token may not exist in test runner, but if it does it should not be empty
        if let token = token {
            XCTAssertFalse(token.isEmpty)
        }
    }

    // MARK: - Entitlements

    func testAppSandboxDisabled() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let entitlements = projectRoot
            .appendingPathComponent("OneOnOne")
            .appendingPathComponent("OneOnOne.entitlements")

        guard FileManager.default.fileExists(atPath: entitlements.path) else { return }

        let content = try String(contentsOf: entitlements, encoding: .utf8)
        // Per Jordan's policy: no sandbox for macOS apps
        XCTAssertTrue(content.contains("com.apple.security.app-sandbox"))
        XCTAssertTrue(content.contains("<false/>"), "App sandbox should be disabled per distribution policy")
    }
}
