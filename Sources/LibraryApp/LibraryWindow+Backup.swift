// LibraryWindow+Backup.swift: the backup area (catalog-backup BK-4). File >
// Restore Catalog Backup… (LibraryBackupCommands, fed by the focused window's
// LibraryBackupMenu) opens LibraryBackupSheet. Open runs `catalog.backups` and
// Restore runs `catalog.restore-backup`, both through the kernel catalog of
// LibraryCatalog.backupSpecs, so the menu, the sheet and the CLI share one
// availability: on the stubs the item and Restore are disabled with "Backups
// arrive with BK-3.". The sheet's state lives in LibraryBackupArea's own
// @State, not in LibraryWindow, so opening and closing it re-renders no window
// body and never the grid (RenderBudgetLibraryBackupTests).
import LibraryModel
import SuiteKernel
import SuiteUI
import SwiftUI

/// What the menu bar reads: Restore Catalog Backup…'s action, nil while `help` says why it can't run.
struct LibraryBackupMenu {
    var open: LibraryMenu.Action?
    var help: String?
}

extension FocusedValues {
    @Entry var libraryBackup: LibraryBackupMenu?
}

/// File > Restore Catalog Backup…, beside the import and export items.
struct LibraryBackupCommands: Commands {
    @FocusedValue(\.libraryBackup) private var focused

    var body: some Commands {
        CommandGroup(after: .importExport) {
            MenuCommand(LibraryBackupMenuState.open, on: LibraryBackupMenuState(hasWindow: focused != nil, restoreWhy: focused?.help),
                        systemImage: "clock.arrow.circlepath") { focused?.open?() }
                .accessibilityIdentifier("library.backup.menu")
        }
    }
}

/// The open sheet's backups and its last refusal.
@Observable final class BackupAreaState {
    var showing = false
    var rows: [LibraryBackupRow] = []
    var message: String?
}

/// Publishes the menu item and presents the sheet. `restoreWhy` is the
/// restore command's reason (nil when it can run); `list` and `restore` run
/// the two commands on the window's catalog.
struct LibraryBackupArea: ViewModifier {
    let restoreWhy: String?
    let list: @MainActor () throws(CatalogError) -> [LibraryBackupRow]
    let restore: @MainActor (String) throws(CatalogError) -> Void
    @State private var state = BackupAreaState()
    #if DEBUG
    /// Opens the sheet on the given backups: the render budget's way in while the menu item is disabled.
    @MainActor static var present: (@MainActor ([LibraryBackupRow]) -> Void)?
    #endif

    func body(content: Content) -> some View {
        content
            .focusedSceneValue(\.libraryBackup, menu)
            .sheet(isPresented: showing) { sheet }
            .onAppear { hook() }
    }

    private var menu: LibraryBackupMenu {
        var action: LibraryMenu.Action?
        if restoreWhy == nil { action = { open() } }
        return LibraryBackupMenu(open: action, help: restoreWhy)
    }

    private var showing: Binding<Bool> {
        let shown = state
        return Binding<Bool>(get: { shown.showing }, set: { (value: Bool) -> Void in shown.showing = value })
    }

    private var sheet: LibraryBackupSheet {
        let shown = state
        let restore: @MainActor (String) -> Void = { (name: String) -> Void in perform(name) }
        let close: LibraryMenu.Action = { shown.showing = false }
        return LibraryBackupSheet(
            rows: state.rows, restoreHelp: restoreWhy, message: state.message,
            actions: LibraryBackupSheet.Actions(restore: restore, close: close))
    }

    private func hook() {
        #if DEBUG
        let shown = state
        Self.present = { (rows: [LibraryBackupRow]) -> Void in (shown.rows, shown.message, shown.showing) = (rows, nil, true) }
        #endif
    }

    /// Lists the backups, then shows the sheet; a refusal shows in the sheet with no rows.
    private func open() {
        do {
            let rows = try list()
            (state.rows, state.message) = (rows, nil)
        } catch { (state.rows, state.message) = ([], String(describing: error)) }
        state.showing = true
    }

    /// Restores `name`, closing the sheet; a refusal stays in the sheet.
    private func perform(_ name: String) {
        do {
            try restore(name)
            state.showing = false
        } catch { state.message = String(describing: error) }
    }
}

extension LibraryWindow {
    /// The backup commands as a kernel catalog. Neither is an undo step, so the history is never read.
    nonisolated static let backups: CommandCatalog<LibraryCatalog> =
        (try? CommandCatalog(app: "library", LibraryCatalog.backupSpecs, history: { _ in History<Int>() })) ?? .empty(app: "library")

    /// The area on the window's catalog: the query runs on a copy, so opening never writes the window's state.
    var backupArea: LibraryBackupArea {
        LibraryBackupArea(
            restoreWhy: Self.backups.availability("catalog.restore-backup", on: model).why,
            list: { () throws(CatalogError) -> [LibraryBackupRow] in
                var probe = model
                let result = try Self.backups.run("catalog.backups", params: .object([:]), on: &probe).result
                do { return try result.decode([LibraryBackupRow].self) } catch {
                    throw .failed(id: "catalog.backups", message: "The backup list couldn't be read.")
                }
            },
            restore: { (name: String) throws(CatalogError) -> Void in
                _ = try Self.backups.run("catalog.restore-backup", params: .object(["name": .string(name)]), on: &model)
            })
    }
}
