//
//  OLMImportService.swift
//  OneOnOne
//
//  Parses Outlook for Mac (.olm) export files to extract calendar events
//  OLM files are ZIP archives containing OPF XML calendar message files
//
//  Created by Jordan Koch on 2026-02-19.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation
import CryptoKit

#if os(macOS)

// MARK: - OLM Calendar Event

struct OLMCalendarEvent: Identifiable {
    let id: String // olmMessageId for dedup
    let subject: String
    let startDate: Date?
    let endDate: Date?
    let location: String?
    let body: String?
    let isRecurring: Bool
    let attendees: [OLMAttendee]
    let organizerEmail: String?
    let organizerName: String?

    var olmMessageId: String { id }

    var duration: TimeInterval {
        guard let start = startDate, let end = endDate else { return 3600 }
        let d = end.timeIntervalSince(start)
        return d > 0 ? d : 3600
    }
}

struct OLMAttendee {
    let name: String?
    let email: String
}

// MARK: - Parse Result

struct OLMParseResult {
    let events: [OLMCalendarEvent]
    let parseErrors: [String]
    let totalFilesScanned: Int
}

// MARK: - Errors

enum OLMImportError: LocalizedError {
    case fileNotFound
    case invalidFormat
    case extractionFailed(String)
    case noCalendarDataFound
    case parsingFailed(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "OLM file not found or not accessible."
        case .invalidFormat:
            return "The selected file is not a valid OLM archive."
        case .extractionFailed(let detail):
            return "Failed to extract OLM file: \(detail)"
        case .noCalendarDataFound:
            return "No calendar events found in this OLM file. The archive may only contain emails or contacts."
        case .parsingFailed(let detail):
            return "Failed to parse calendar data: \(detail)"
        }
    }
}

// MARK: - OLM Import Service

class OLMImportService {

    private var tempDir: URL?

    deinit {
        cleanup()
    }

    /// Main entry point: parse an OLM file and return all calendar events found
    func parseOLMFile(at fileURL: URL) async throws -> OLMParseResult {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw OLMImportError.fileNotFound
        }

        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("OLMImport-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        self.tempDir = temp

        defer { cleanup() }

        // Extract calendar files from the ZIP archive
        try extractCalendarFiles(from: fileURL, to: temp)

        // Find all calendar event files
        let calendarFiles = findCalendarFiles(in: temp)

        guard !calendarFiles.isEmpty else {
            throw OLMImportError.noCalendarDataFound
        }

        // Parse each file
        var events: [OLMCalendarEvent] = []
        var parseErrors: [String] = []

        for file in calendarFiles {
            do {
                if let event = try parseCalendarFile(at: file) {
                    events.append(event)
                }
            } catch {
                parseErrors.append("\(file.lastPathComponent): \(error.localizedDescription)")
            }
        }

        if events.isEmpty && !parseErrors.isEmpty {
            throw OLMImportError.parsingFailed("All \(calendarFiles.count) calendar files failed to parse.")
        }

        if events.isEmpty {
            throw OLMImportError.noCalendarDataFound
        }

        // Sort by start date
        let sorted = events.sorted { ($0.startDate ?? .distantPast) < ($1.startDate ?? .distantPast) }

        return OLMParseResult(
            events: sorted,
            parseErrors: parseErrors,
            totalFilesScanned: calendarFiles.count
        )
    }

    // MARK: - ZIP Extraction

    /// Extracts only calendar-related files from the OLM archive using /usr/bin/unzip
    private func extractCalendarFiles(from olmURL: URL, to tempDir: URL) throws {
        // First try extracting only calendar paths (efficient for large archives)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-o", olmURL.path, "*Calendar*", "*calendar*", "-d", tempDir.path]

        let errorPipe = Pipe()
        process.standardOutput = Pipe() // suppress stdout
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        // If wildcard extraction found nothing, try extracting everything
        // (some OLM formats use different folder names)
        if process.terminationStatus != 0 || findCalendarFiles(in: tempDir).isEmpty {
            let fullProcess = Process()
            fullProcess.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            fullProcess.arguments = ["-o", olmURL.path, "-d", tempDir.path]

            let fullErrorPipe = Pipe()
            fullProcess.standardOutput = Pipe()
            fullProcess.standardError = fullErrorPipe

            try fullProcess.run()
            fullProcess.waitUntilExit()

            if fullProcess.terminationStatus != 0 {
                let errorData = fullErrorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorOutput = String(data: errorData, encoding: .utf8) ?? "Unknown extraction error"
                throw OLMImportError.extractionFailed(String(errorOutput.prefix(300)))
            }
        }
    }

    // MARK: - File Discovery

    /// Finds all calendar event files in the extracted directory
    private func findCalendarFiles(in directory: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var calendarEntries: [URL] = []

        while let url = enumerator.nextObject() as? URL {
            let name = url.lastPathComponent.lowercased()

            // Match OLK calendar message files/directories
            if name.hasSuffix("calmessage") ||
               name.hasSuffix(".olk14calmessage") ||
               name.hasSuffix(".olk15calmessage") ||
               name.hasSuffix(".olk16calmessage") {
                calendarEntries.append(url)
            }
        }

        // Resolve directories to their inner message files
        var resolvedFiles: [URL] = []
        let fm = FileManager.default

        for entry in calendarEntries {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: entry.path, isDirectory: &isDir) else { continue }

            if isDir.boolValue {
                // Directory-based format: look for message.xml or any XML file inside
                let messageXML = entry.appendingPathComponent("message.xml")
                let message = entry.appendingPathComponent("message")

                if fm.fileExists(atPath: messageXML.path) {
                    resolvedFiles.append(messageXML)
                } else if fm.fileExists(atPath: message.path) {
                    resolvedFiles.append(message)
                } else {
                    // Try any XML file in the directory
                    if let contents = try? fm.contentsOfDirectory(at: entry, includingPropertiesForKeys: nil) {
                        if let xmlFile = contents.first(where: { $0.pathExtension.lowercased() == "xml" }) {
                            resolvedFiles.append(xmlFile)
                        } else if let firstFile = contents.first {
                            // Last resort: try the first file
                            resolvedFiles.append(firstFile)
                        }
                    }
                }
            } else {
                // Direct file format
                resolvedFiles.append(entry)
            }
        }

        return resolvedFiles
    }

    // MARK: - XML Parsing

    /// Parses a single calendar event file
    private func parseCalendarFile(at fileURL: URL) throws -> OLMCalendarEvent? {
        let data = try Data(contentsOf: fileURL)
        guard !data.isEmpty else { return nil }

        let delegate = OPFXMLParserDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.parse()

        // Must have at least a subject
        guard let subject = delegate.subject, !subject.isEmpty else { return nil }

        let startDate = parseOLMDate(dateString: delegate.startDate, timeString: delegate.startTime)
        let endDate = parseOLMDate(dateString: delegate.endDate, timeString: delegate.endTime)

        // Generate deterministic event ID for deduplication
        let eventId = generateEventId(subject: subject, startDate: startDate, endDate: endDate)

        // Build body text (prefer plain text, fall back to stripping HTML preview)
        let body: String? = {
            if let b = delegate.body, !b.isEmpty { return b }
            if let html = delegate.htmlBody, !html.isEmpty {
                // Simple HTML tag stripping for preview
                return html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return nil
        }()

        return OLMCalendarEvent(
            id: eventId,
            subject: subject,
            startDate: startDate,
            endDate: endDate,
            location: delegate.location,
            body: body,
            isRecurring: delegate.isRecurring,
            attendees: delegate.attendees,
            organizerEmail: delegate.organizerEmail,
            organizerName: delegate.organizerName
        )
    }

    // MARK: - Date Parsing

    /// Parses OLM dates which come in various formats
    private func parseOLMDate(dateString: String?, timeString: String?) -> Date? {
        guard let dateStr = dateString, !dateStr.isEmpty else { return nil }

        let combined: String
        if let timeStr = timeString, !timeStr.isEmpty, !dateStr.contains("T") {
            combined = "\(dateStr)T\(timeStr)"
        } else {
            combined = dateStr
        }

        // Try ISO 8601 with fractional seconds
        let f1 = ISO8601DateFormatter()
        f1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f1.date(from: combined) { return d }

        // Try ISO 8601 without fractional seconds
        let f2 = ISO8601DateFormatter()
        f2.formatOptions = [.withInternetDateTime]
        if let d = f2.date(from: combined) { return d }

        // Try common date formats
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")

        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSS",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss Z",
            "MM/dd/yyyy HH:mm:ss",
            "yyyyMMdd'T'HHmmss'Z'",
            "yyyyMMdd'T'HHmmss",
            "yyyy-MM-dd",
        ]

        for format in formats {
            df.dateFormat = format
            if let d = df.date(from: combined) { return d }
        }

        return nil
    }

    // MARK: - Event ID Generation

    /// Generates a deterministic ID from event properties for deduplication
    private func generateEventId(subject: String, startDate: Date?, endDate: Date?) -> String {
        let components = [
            subject,
            startDate.map { String($0.timeIntervalSince1970) } ?? "",
            endDate.map { String($0.timeIntervalSince1970) } ?? ""
        ].joined(separator: "|")

        let hash = SHA256.hash(data: Data(components.utf8))
        let hashPrefix = hash.prefix(16).map { String(format: "%02x", $0) }.joined()
        return "olm-\(hashPrefix)"
    }

    // MARK: - Cleanup

    private func cleanup() {
        guard let dir = tempDir else { return }
        try? FileManager.default.removeItem(at: dir)
        tempDir = nil
    }
}

// MARK: - OPF XML Parser Delegate

private class OPFXMLParserDelegate: NSObject, XMLParserDelegate {
    var subject: String?
    var startDate: String?
    var startTime: String?
    var endDate: String?
    var endTime: String?
    var location: String?
    var body: String?
    var htmlBody: String?
    var organizerEmail: String?
    var organizerName: String?
    var attendees: [OLMAttendee] = []
    var isRecurring = false

    private var currentElement = ""
    private var currentText = ""

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName
        currentText = ""
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        let value = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            currentElement = ""
            currentText = ""
            return
        }

        let lower = elementName.lowercased()

        // Subject / Title
        if lower.contains("subject") || lower == "title" || lower == "summary" {
            if subject == nil { subject = value }
        }

        // Start date/time
        if lower.contains("startdate") || lower == "dtstart" {
            if startDate == nil { startDate = value }
        }
        if lower.contains("starttime") {
            if startTime == nil { startTime = value }
        }

        // End date/time
        if lower.contains("enddate") || lower == "dtend" {
            if endDate == nil { endDate = value }
        }
        if lower.contains("endtime") {
            if endTime == nil { endTime = value }
        }

        // Location
        if lower.contains("location") {
            if location == nil { location = value }
        }

        // Body (plain text)
        if (lower.contains("body") || lower.contains("description") || lower.contains("notes"))
            && !lower.contains("html") {
            if body == nil { body = value }
        }

        // HTML Body
        if lower.contains("htmlbody") || (lower.contains("body") && lower.contains("html")) {
            if htmlBody == nil { htmlBody = value }
        }

        // Organizer
        if lower.contains("organizer") && (lower.contains("address") || lower.contains("email")) {
            if organizerEmail == nil && value.contains("@") { organizerEmail = value }
        }
        if lower.contains("organizer") && lower.contains("name") {
            if organizerName == nil { organizerName = value }
        }
        if lower.contains("senderaddress") || lower.contains("sender") && lower.contains("address") {
            if organizerEmail == nil && value.contains("@") { organizerEmail = value }
        }
        if lower.contains("sendername") || lower.contains("sender") && lower.contains("name") {
            if organizerName == nil { organizerName = value }
        }

        // Attendee emails
        if (lower.contains("attendee") || lower.contains("recipient") || lower.contains("toaddress"))
            && (lower.contains("address") || lower.contains("email")) {
            if value.contains("@") {
                attendees.append(OLMAttendee(name: nil, email: value))
            }
        }
        // Generic email element within attendee context
        if lower == "emailaddress" || lower == "address" {
            if value.contains("@") && !attendees.contains(where: { $0.email.lowercased() == value.lowercased() }) {
                attendees.append(OLMAttendee(name: nil, email: value))
            }
        }

        // Recurring
        if lower.contains("recurring") || lower.contains("isrecurring") {
            isRecurring = value.lowercased() == "true" || value == "1"
        }

        currentElement = ""
        currentText = ""
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        // XML parsing errors are non-fatal - we extract what we can
        print("OLMImport: XML parse warning: \(parseError.localizedDescription)")
    }
}

#endif  // os(macOS)
