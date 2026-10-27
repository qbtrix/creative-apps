// LibraryBackupSnapshots.swift: the Restore Catalog Backup sheet (catalog-backup
// BK-4), five backups listed with Restore disabled (no backups attached to the
// fixture catalog), and with no backups yet, in Light and Dark: library-backup and
// library-backup-empty. macOS only.
import LibraryModel
import SwiftUI
import Testing

@testable import LibraryApp

@MainActor
@Suite struct LibraryBackupSnapshots {
    @Test func backupSheet() throws {
        let rows = (0..<5).map { i in
            LibraryBackupRow(name: "catalog backup \(i).json", date: 1_792_000_000 - Double(i) * 86_400, photos: 60 - i * 3)
        }
        let help = LibraryWindow.backups.availability("catalog.restore-backup", on: LibraryCatalog(services: .fake())).why
        for scheme in [ColorScheme.light, .dark] {
            let name = scheme == .dark ? "dark" : "light"
            try snapshot(LibraryBackupSheet(rows: rows, restoreHelp: help), name: "library-backup-\(name)", scheme: scheme)
            try snapshot(LibraryBackupSheet(rows: [], restoreHelp: help), name: "library-backup-empty-\(name)", scheme: scheme)
        }
    }

    @Test func sheetTexts() {
        let row = LibraryBackupRow(name: "a.json", date: 0, photos: 1)
        #expect(LibraryBackupSheet.photos(1) == "1 photo" && LibraryBackupSheet.photos(60) == "60 photos")
        #expect(LibraryBackupSheet.blocked(restoreHelp: LibraryBackups.noBackups, selected: "a", canRestore: true)
            == LibraryBackups.noBackups)
        #expect(LibraryBackupSheet.blocked(restoreHelp: nil, selected: nil, canRestore: true) == "Choose a backup to restore.")
        #expect(LibraryBackupSheet.blocked(restoreHelp: nil, selected: "a", canRestore: true) == nil)
        let confirm = LibraryBackupSheet.confirmText(row)
        #expect(confirm.contains("backs up the current catalog first, then replaces it") && confirm.contains("1 photo"))
    }

    @Test func stubsDisableRestore() {
        let catalog = LibraryCatalog(services: .fake())
        #expect(LibraryWindow.backups.availability("catalog.restore-backup", on: catalog).why == LibraryBackups.noBackups)
        #expect(LibraryWindow.backups.ids == ["catalog.backups", "catalog.restore-backup"])
    }
}
