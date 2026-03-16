//
//  NovaAPIServer.swift
//  OneOnOne
//
//  Local HTTP API server for Nova (OpenClaw) integration.
//  Listens on 127.0.0.1:37421 — loopback only, no external exposure.
//
//  Nova can interact via curl:
//    curl http://127.0.0.1:37421/api/status
//    curl http://127.0.0.1:37421/api/meetings?limit=5
//    curl http://127.0.0.1:37421/api/meetings/{uuid}
//    curl http://127.0.0.1:37421/api/people
//    curl -X POST http://127.0.0.1:37421/api/summarize \
//         -H "Content-Type: application/json" \
//         -d '{"content":"email body here","context":"optional context"}'
//    curl -X POST http://127.0.0.1:37421/api/meetings/{uuid}/summary
//
//  Created by Jordan Koch on 2026-03-16.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

#if os(macOS)
import Foundation
import Network

@MainActor
class NovaAPIServer {
    static let shared = NovaAPIServer()

    let port: UInt16 = 37421
    private var listener: NWListener?

    private init() {}

    // MARK: - Lifecycle

    func start() {
        do {
            let params = NWParameters.tcp
            params.requiredLocalEndpoint = NWEndpoint.hostPort(
                host: "127.0.0.1",
                port: NWEndpoint.Port(rawValue: port)!
            )
            listener = try NWListener(using: params)
            listener?.newConnectionHandler = { [weak self] connection in
                Task { @MainActor in
                    self?.handleConnection(connection)
                }
            }
            let boundPort = port
            listener?.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    print("NovaAPIServer: ready on 127.0.0.1:\(boundPort)")
                case .failed(let error):
                    print("NovaAPIServer: failed — \(error)")
                default:
                    break
                }
            }
            listener?.start(queue: .main)
        } catch {
            print("NovaAPIServer: could not start — \(error)")
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        print("NovaAPIServer: stopped")
    }

    // MARK: - Connection Handling

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .main)
        receive(from: connection, buffer: Data())
    }

    private func receive(from connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            Task { @MainActor [weak self] in
                guard let self else { return }

                var accumulated = buffer
                if let data { accumulated.append(data) }

                if let request = self.parseHTTPRequest(accumulated) {
                    let responseString = await self.route(request)
                    let responseData = responseString.data(using: .utf8) ?? Data()
                    connection.send(content: responseData, completion: .contentProcessed { _ in
                        connection.cancel()
                    })
                } else if !isComplete && error == nil {
                    self.receive(from: connection, buffer: accumulated)
                } else {
                    connection.cancel()
                }
            }
        }
    }

    // MARK: - HTTP Parsing

    private struct HTTPRequest {
        let method: String
        let path: String
        let body: String
    }

    private func parseHTTPRequest(_ data: Data) -> HTTPRequest? {
        guard let raw = String(data: data, encoding: .utf8) else { return nil }

        // Must have header terminator
        guard raw.contains("\r\n\r\n") else { return nil }

        let parts = raw.components(separatedBy: "\r\n\r\n")
        let headerSection = parts[0]
        let body = parts.dropFirst().joined(separator: "\r\n\r\n")

        let headerLines = headerSection.components(separatedBy: "\r\n")
        guard let requestLine = headerLines.first else { return nil }

        let tokens = requestLine.components(separatedBy: " ")
        guard tokens.count >= 2 else { return nil }

        // Check Content-Length to ensure body is fully received
        if let clLine = headerLines.first(where: { $0.lowercased().hasPrefix("content-length:") }) {
            let clStr = clLine.components(separatedBy: ":").dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)
            if let contentLength = Int(clStr), body.utf8.count < contentLength {
                return nil // Body not fully received yet
            }
        }

        return HTTPRequest(method: tokens[0], path: tokens[1], body: body)
    }

    // MARK: - Routing

    private func route(_ request: HTTPRequest) async -> String {
        // Strip query string for path matching
        let pathOnly = request.path.components(separatedBy: "?").first ?? request.path

        switch (request.method, pathOnly) {

        case ("GET", "/api/status"):
            return jsonResponse([
                "status": "running",
                "app": "OneOnOne",
                "version": "1.0",
                "port": "\(port)"
            ])

        case ("GET", "/api/people"):
            return encodableResponse(DataStore.shared.people)

        case ("GET", "/api/meetings"):
            let limit = queryParam("limit", in: request.path).flatMap(Int.init) ?? 20
            return encodableResponse(DataStore.shared.recentMeetings(limit: limit))

        case ("GET", _) where pathOnly.hasPrefix("/api/meetings/"):
            let idString = pathOnly.replacingOccurrences(of: "/api/meetings/", with: "")
            guard let uuid = UUID(uuidString: idString) else {
                return errorResponse(status: 400, message: "Invalid UUID: \(idString)")
            }
            guard let meeting = DataStore.shared.meetings.first(where: { $0.id == uuid }) else {
                return errorResponse(status: 404, message: "Meeting not found")
            }
            return encodableResponse(meeting)

        case ("POST", "/api/summarize"):
            return await handleSummarize(body: request.body)

        case ("POST", _) where pathOnly.hasSuffix("/summary"):
            // /api/meetings/{uuid}/summary
            let components = pathOnly.split(separator: "/").map(String.init)
            guard components.count == 4,
                  let uuid = UUID(uuidString: components[2]) else {
                return errorResponse(status: 400, message: "Invalid meeting UUID")
            }
            return await handleGenerateMeetingSummary(meetingId: uuid)

        case ("OPTIONS", _):
            return httpResponse(status: 200, contentType: "text/plain", body: "")

        default:
            return errorResponse(status: 404, message: "Endpoint not found: \(request.method) \(pathOnly)")
        }
    }

    // MARK: - Handlers

    private func handleSummarize(body: String) async -> String {
        guard let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
              let content = json["content"], !content.isEmpty else {
            return errorResponse(status: 400, message: "Request body must be JSON with a non-empty 'content' field")
        }

        let context = json["context"] ?? ""

        do {
            let summary = try await AIService.shared.summarizeEmailForNova(content: content, context: context)
            return jsonResponse(["summary": summary])
        } catch {
            return errorResponse(status: 500, message: "AI summarization failed: \(error.localizedDescription)")
        }
    }

    private func handleGenerateMeetingSummary(meetingId: UUID) async -> String {
        guard let meeting = DataStore.shared.meetings.first(where: { $0.id == meetingId }) else {
            return errorResponse(status: 404, message: "Meeting not found")
        }

        guard !meeting.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return errorResponse(status: 422, message: "Meeting has no notes to summarize")
        }

        let attendeeNames = meeting.attendees.compactMap { DataStore.shared.person(for: $0)?.name }

        do {
            let summary = try await AIService.shared.generateMeetingSummary(
                notes: meeting.notes,
                attendees: attendeeNames
            )
            var updated = meeting
            updated.summary = summary
            DataStore.shared.updateMeeting(updated)
            return jsonResponse(["summary": summary, "meetingId": meetingId.uuidString])
        } catch {
            return errorResponse(status: 500, message: "Summary generation failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Response Helpers

    private func encodableResponse<T: Encodable>(_ value: T) -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(value),
              let json = String(data: data, encoding: .utf8) else {
            return errorResponse(status: 500, message: "Encoding error")
        }
        return httpResponse(status: 200, contentType: "application/json", body: json)
    }

    private func jsonResponse(_ dict: [String: String]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted),
              let json = String(data: data, encoding: .utf8) else {
            return errorResponse(status: 500, message: "Encoding error")
        }
        return httpResponse(status: 200, contentType: "application/json", body: json)
    }

    private func errorResponse(status: Int, message: String) -> String {
        let dict: [String: String] = ["error": message]
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let json = String(data: data, encoding: .utf8) else {
            return httpResponse(status: status, contentType: "text/plain", body: message)
        }
        return httpResponse(status: status, contentType: "application/json", body: json)
    }

    private func httpResponse(status: Int, contentType: String, body: String) -> String {
        let statusText: String
        switch status {
        case 200: statusText = "OK"
        case 400: statusText = "Bad Request"
        case 404: statusText = "Not Found"
        case 422: statusText = "Unprocessable Entity"
        case 500: statusText = "Internal Server Error"
        default:  statusText = "Unknown"
        }
        let bodyBytes = body.utf8.count
        return [
            "HTTP/1.1 \(status) \(statusText)",
            "Content-Type: \(contentType); charset=utf-8",
            "Content-Length: \(bodyBytes)",
            "Access-Control-Allow-Origin: *",
            "Connection: close",
            "",
            body
        ].joined(separator: "\r\n")
    }

    // MARK: - Utilities

    private func queryParam(_ name: String, in path: String) -> String? {
        guard let queryStart = path.firstIndex(of: "?") else { return nil }
        let query = String(path[path.index(after: queryStart)...])
        for pair in query.components(separatedBy: "&") {
            let kv = pair.components(separatedBy: "=")
            if kv.count == 2, kv[0] == name {
                return kv[1].removingPercentEncoding
            }
        }
        return nil
    }
}
#endif
