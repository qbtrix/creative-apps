// LibraryBackupSheet+Suite.swift: File > Restore Catalog Backup…'s sheet
// (catalog-backup BK-4). It lists the catalog's backups, newest first, as
// SuiteUI sidebar rows (the date as the title, the photo count as the badge),
// the newest selected. Restore asks first in a confirmation dialog whose text
// says what happens to the current catalog: Library backs it up, then replaces
// it. Values in, closures out, as the export sheet does: a nil action disables
// its button, and `restoreHelp` is the reason Restore can't run (no backups
// yet, or an import running). Its frame, message line and Cancel /
// Restore… row are SuiteUI's SuiteSheet.
import Foundation
import LibraryModel
import SuiteUI
import SwiftUI

struct LibraryBackupSheet: View {
    struct Actions {
        var restore: (@MainActor (String) -> Void)?
        var close: LibraryMenu.Action?
    }

    let rows: [LibraryBackupRow], restoreHelp: String?, message: String?, actions: Actions
    @State private var selected: String?
    @State private var confirming = false

    init(rows: [LibraryBackupRow], restoreHelp: String?, message: String? = nil, actions: Actions = Actions()) {
        (self.rows, self.restoreHelp, self.message, self.actions) = (rows, restoreHelp, message, actions)
        _selected = State(initialValue: rows.first?.name)
    }

    var body: some View {
        let blocked = Self.blocked(restoreHelp: restoreHelp, selected: selected, canRestore: actions.restore != nil)
        SuiteSheet(
            "Restore Catalog Backup", message: message, messageID: "library.backup.message", width: SuiteSize.contentIdealWidth,
            cancelID: "library.backup.cancel", onCancel: { actions.close?() },
            action: MenuCommand(LibraryCatalog.restoreControlSpec, on: LibraryRestoreControl(help: blocked), title: "Restore…") {
                confirming = true
            },
            actionID: "library.backup.restore"
        ) {
            if rows.isEmpty {
                Text(Self.emptyText).foregroundStyle(SuiteColor.secondaryText)
                    .accessibilityIdentifier("library.backup.empty")
            } else {
                List(selection: $selected) {
                    ForEach(rows, id: \.name) { (row: LibraryBackupRow) in
                        SidebarRow(SidebarItem(id: row.name, title: Self.title(row), systemImage: "clock.arrow.circlepath",
                                               count: row.photos))
                            .tag(row.name)
                            .help(Self.photos(row.photos))
                            .accessibilityIdentifier("library.backup.row")
                    }
                }
                .frame(minHeight: SuiteSize.contentMinimum.height)
            }
        }
        .confirmationDialog("Restore This Backup?", isPresented: $confirming, titleVisibility: .visible) {
            MenuCommand(LibraryCatalog.restoreControlSpec, on: LibraryRestoreControl(help: blocked), title: "Restore",
                        role: .destructive) { if let selected { actions.restore?(selected) } }
                .accessibilityIdentifier("library.backup.confirm")
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(Self.confirmText(rows.first { $0.name == selected }))
        }
    }

    static let emptyText = "There are no backups yet. Library makes one each time it saves the catalog."

    /// The backup's date and time, as the row's title.
    nonisolated static func title(_ row: LibraryBackupRow) -> String {
        Date(timeIntervalSince1970: row.date).formatted(date: .abbreviated, time: .shortened)
    }

    /// "1 photo", "60 photos".
    nonisolated static func photos(_ count: Int) -> String { count == 1 ? "1 photo" : "\(count) photos" }

    /// Why Restore can't run: the command's reason first, then no action, then no selection; nil when it can.
    nonisolated static func blocked(restoreHelp: String?, selected: String?, canRestore: Bool) -> String? {
        if let restoreHelp { return restoreHelp }
        if !canRestore { return "Restore isn't available right now." }
        return selected == nil ? "Choose a backup to restore." : nil
    }

    /// What Restore does to the current catalog: backed up first, then replaced.
    nonisolated static func confirmText(_ row: LibraryBackupRow?) -> String {
        let source = row.map { "the backup from \(title($0)) (\(photos($0.photos)))" } ?? "the selected backup"
        return "Library backs up the current catalog first, then replaces it with \(source). "
            + "To go back, restore the backup it just made."
    }
}
