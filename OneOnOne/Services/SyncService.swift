//
//  SyncService.swift
//  OneOnOne
//
//  Import/Export service for syncing data across computers
//  Created by Jordan Koch on 2026-02-02.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation
import AppKit

@MainActor
class SyncService: ObservableObject {
    static let shared = SyncService()

    @Published var lastExportDate: Date?
    @Published var lastImportDate: Date?
    @Published var isExporting = false
    @Published var isImporting = false
    @Published var lastError: String?

    private init() {}

    // MARK: - Export

    /// Exports all data to a file
    func exportData() async {
        isExporting = true
        lastError = nil

        defer { isExporting = false }

        guard let data = DataStore.shared.exportData() else {
            lastError = "Failed to prepare export data"
            return
        }

        // Create save panel
        let savePanel = NSSavePanel()
        savePanel.title = "Export OneOnOne Data"
        savePanel.nameFieldStringValue = "OneOnOne-Export-\(formatDate(Date())).json"
        savePanel.allowedContentTypes = [.json]
        savePanel.canCreateDirectories = true

        let response = await savePanel.begin()

        guard response == .OK, let url = savePanel.url else {
            return
        }

        do {
            try data.write(to: url)
            lastExportDate = Date()
            print("Data exported to: \(url.path)")
        } catch {
            lastError = "Export failed: \(error.localizedDescription)"
            print("Export error: \(error)")
        }
    }

    /// Exports data to a specific URL (for automated sync)
    func exportData(to url: URL) async throws {
        guard let data = DataStore.shared.exportData() else {
            throw SyncError.exportFailed
        }

        try data.write(to: url)
        lastExportDate = Date()
    }

    // MARK: - Import

    /// Imports data from a file
    func importData() async {
        isImporting = true
        lastError = nil

        defer { isImporting = false }

        // Create open panel
        let openPanel = NSOpenPanel()
        openPanel.title = "Import OneOnOne Data"
        openPanel.allowedContentTypes = [.json]
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false

        let response = await openPanel.begin()

        guard response == .OK, let url = openPanel.url else {
            return
        }

        do {
            let data = try Data(contentsOf: url)
            try DataStore.shared.importData(from: data)
            lastImportDate = Date()
            print("Data imported from: \(url.path)")
        } catch {
            lastError = "Import failed: \(error.localizedDescription)"
            print("Import error: \(error)")
        }
    }

    /// Imports data from a specific URL
    func importData(from url: URL) async throws {
        let data = try Data(contentsOf: url)
        try DataStore.shared.importData(from: data)
        lastImportDate = Date()
    }

    // MARK: - Auto Sync

    /// Sets up automatic sync to a folder
    func setupAutoSync(folder: URL, interval: TimeInterval = 3600) {
        // Create sync timer
        Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performAutoSync(to: folder)
            }
        }
    }

    private func performAutoSync(to folder: URL) async {
        let filename = "OneOnOne-AutoSync.json"
        let fileURL = folder.appendingPathComponent(filename)

        // Check if remote file is newer
        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                if let modDate = attributes[.modificationDate] as? Date,
                   let lastExport = lastExportDate,
                   modDate > lastExport {
                    // Remote is newer - import
                    try await importData(from: fileURL)
                    return
                }
            } catch {
                print("Auto sync check failed: \(error)")
            }
        }

        // Export our data
        do {
            try await exportData(to: fileURL)
        } catch {
            print("Auto sync export failed: \(error)")
        }
    }

    // MARK: - Backup

    /// Creates a timestamped backup
    func createBackup() async throws -> URL {
        guard let data = DataStore.shared.exportData() else {
            throw SyncError.exportFailed
        }

        let backupDir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("OneOnOne/Backups", isDirectory: true)

        try FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)

        let filename = "Backup-\(formatDate(Date())).json"
        let backupURL = backupDir.appendingPathComponent(filename)

        try data.write(to: backupURL)

        // Clean old backups (keep last 10)
        cleanOldBackups(in: backupDir, keepCount: 10)

        return backupURL
    }

    /// Lists available backups
    func listBackups() -> [(url: URL, date: Date)] {
        let backupDir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("OneOnOne/Backups", isDirectory: true)

        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: backupDir,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return contents.compactMap { url in
            guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
                  let date = attrs[.creationDate] as? Date else {
                return nil
            }
            return (url: url, date: date)
        }.sorted { $0.date > $1.date }
    }

    /// Restores from a backup
    func restoreBackup(from url: URL) async throws {
        try await importData(from: url)
    }

    // MARK: - Helpers

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter.string(from: date)
    }

    private func cleanOldBackups(in directory: URL, keepCount: Int) {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        let sorted = contents.sorted { url1, url2 in
            let date1 = (try? FileManager.default.attributesOfItem(atPath: url1.path)[.creationDate] as? Date) ?? Date.distantPast
            let date2 = (try? FileManager.default.attributesOfItem(atPath: url2.path)[.creationDate] as? Date) ?? Date.distantPast
            return date1 > date2
        }

        if sorted.count > keepCount {
            for url in sorted.dropFirst(keepCount) {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }
}

// MARK: - Errors

enum SyncError: LocalizedError {
    case exportFailed
    case importFailed
    case backupFailed

    var errorDescription: String? {
        switch self {
        case .exportFailed:
            return "Failed to export data"
        case .importFailed:
            return "Failed to import data"
        case .backupFailed:
            return "Failed to create backup"
        }
    }
}
