//
//  SyncService.swift
//  OneOnOne
//
//  Import/Export service for syncing data across computers
//  Created by Jordan Koch on 2026-02-02.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation
import SwiftUI

#if os(macOS)
import AppKit
#endif

@MainActor
class SyncService: ObservableObject {
    static let shared = SyncService()

    @Published var lastExportDate: Date?
    @Published var lastImportDate: Date?
    @Published var isExporting = false
    @Published var isImporting = false
    @Published var lastError: String?

    // For iOS share sheet
    @Published var exportedFileURL: URL?
    @Published var showingShareSheet = false

    private init() {}

    // MARK: - Export

    #if os(macOS)
    /// Exports all data to a file (macOS - uses NSSavePanel)
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

    /// Imports data from a file (macOS - uses NSOpenPanel)
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

    #elseif os(iOS)
    /// Exports all data to a file (iOS - creates file for share sheet)
    func exportData() async {
        isExporting = true
        lastError = nil

        defer { isExporting = false }

        guard let data = DataStore.shared.exportData() else {
            lastError = "Failed to prepare export data"
            return
        }

        // Create temp file for sharing
        let tempDir = FileManager.default.temporaryDirectory
        let filename = "OneOnOne-Export-\(formatDate(Date())).json"
        let fileURL = tempDir.appendingPathComponent(filename)

        do {
            try data.write(to: fileURL)
            exportedFileURL = fileURL
            showingShareSheet = true
            lastExportDate = Date()
            print("Data exported to: \(fileURL.path)")
        } catch {
            lastError = "Export failed: \(error.localizedDescription)"
            print("Export error: \(error)")
        }
    }

    /// Imports data from a URL (iOS - called from document picker)
    func importData(from url: URL) async {
        isImporting = true
        lastError = nil

        defer { isImporting = false }

        do {
            // Start accessing security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                lastError = "Cannot access file"
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            let data = try Data(contentsOf: url)
            try DataStore.shared.importData(from: data)
            lastImportDate = Date()
            print("Data imported from: \(url.path)")
        } catch {
            lastError = "Import failed: \(error.localizedDescription)"
            print("Import error: \(error)")
        }
    }

    /// Stub for iOS (not used - uses document picker instead)
    func importData() async {
        // iOS uses document picker - this is handled by the UI
    }
    #endif

    /// Exports data to a specific URL (for automated sync - all platforms)
    func exportData(to url: URL) async throws {
        guard let data = DataStore.shared.exportData() else {
            throw SyncError.exportFailed
        }

        try data.write(to: url)
        lastExportDate = Date()
    }

    /// Imports data from a specific URL (all platforms)
    func importDataFromURL(_ url: URL) async throws {
        let data = try Data(contentsOf: url)
        try DataStore.shared.importData(from: data)
        lastImportDate = Date()
    }

    // MARK: - Auto Sync (macOS only - uses file system watches)

    #if os(macOS)
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
                    try await importDataFromURL(fileURL)
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
    #endif

    // MARK: - Backup (all platforms)

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
        try await importDataFromURL(url)
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

// MARK: - Share Sheet for iOS

#if os(iOS)
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct DocumentPicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.json])
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void

        init(onPick: @escaping (URL) -> Void) {
            self.onPick = onPick
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first {
                onPick(url)
            }
        }
    }
}
#endif
