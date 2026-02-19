//
//  SharedDataManager.swift
//  OneOnOne Widget
//
//  Manages data sharing between the main app and widget via App Groups
//  Created by Jordan Koch on 2026-02-04.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation
import WidgetKit

/// Manages shared data between the main app and widget extension using App Groups
class SharedDataManager {
    static let shared = SharedDataManager()

    /// App Group identifier for data sharing
    private let appGroupIdentifier = "group.com.jkoch.oneonone"

    /// File name for shared widget data
    private let sharedDataFileName = "widget_data.json"

    private init() {}

    // MARK: - App Group Container

    /// Returns the shared container URL for the app group
    private var sharedContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }

    /// Returns the URL for the shared data file
    private var sharedDataFileURL: URL? {
        sharedContainerURL?.appendingPathComponent(sharedDataFileName)
    }

    // MARK: - Read Data

    /// Reads the shared widget data from the app group container
    func readWidgetData() -> SharedWidgetData {
        guard let fileURL = sharedDataFileURL else {
            print("SharedDataManager: Could not get shared container URL")
            return .empty
        }

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("SharedDataManager: Widget data file does not exist")
            return .empty
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let widgetData = try decoder.decode(SharedWidgetData.self, from: data)
            print("SharedDataManager: Successfully read widget data with \(widgetData.upcomingMeetings.count) meetings")
            return widgetData
        } catch {
            print("SharedDataManager: Error reading widget data: \(error)")
            return .empty
        }
    }

    // MARK: - Write Data

    /// Writes the shared widget data to the app group container
    func writeWidgetData(_ data: SharedWidgetData) {
        guard let fileURL = sharedDataFileURL else {
            print("SharedDataManager: Could not get shared container URL")
            return
        }

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let jsonData = try encoder.encode(data)
            try jsonData.write(to: fileURL)
            print("SharedDataManager: Successfully wrote widget data")

            // Reload widget timelines
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            print("SharedDataManager: Error writing widget data: \(error)")
        }
    }

    // MARK: - Convenience Methods

    /// Refreshes widget data from the main app
    static func refreshWidgetData() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
