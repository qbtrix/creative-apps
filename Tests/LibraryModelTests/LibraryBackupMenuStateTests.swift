// LibraryBackupMenuStateTests.swift (catalog-backup BK-u): the backup menu item's and the Restore sheet's
// specs say why they can't run: no window, the restore command's reason, no restore action, no backup chosen.
// Runs on Linux and macOS.
@testable import LibraryModel
import SuiteKernel
import Testing

@Suite struct LibraryBackupMenuStateTests {
    static let stub = "Backups arrive with BK-3."

    @Test func theMenuItemNeedsAWindowAndARestore() {
        #expect(LibraryBackupMenuState.open.availability(LibraryBackupMenuState()) == .unavailable("Open the Library window first."))
        #expect(LibraryBackupMenuState.open.availability(LibraryBackupMenuState(hasWindow: true, restoreWhy: Self.stub))
            == .unavailable(Self.stub))
        #expect(LibraryBackupMenuState.open.availability(LibraryBackupMenuState(hasWindow: true)) == .available)
        #expect(LibraryBackupMenuState.open.title == "Restore Catalog Backup…")
    }

    @Test func restoreSaysTheCommandsReasonFirst() {
        let state = LibraryBackupMenuState(hasWindow: true, restoreWhy: Self.stub, selected: nil, canRestore: false)
        #expect(LibraryBackupMenuState.restore.availability(state) == .unavailable(Self.stub))
    }

    @Test func restoreNeedsAnActionThenASelection() {
        let noAction = LibraryBackupMenuState(hasWindow: true, selected: "a", canRestore: false)
        #expect(noAction.sheetWhy == "Restore isn't available right now.")
        let noSelection = LibraryBackupMenuState(hasWindow: true, selected: nil, canRestore: true)
        #expect(noSelection.sheetWhy == "Choose a backup to restore.")
        let ready = LibraryBackupMenuState(hasWindow: true, selected: "a", canRestore: true)
        #expect(LibraryBackupMenuState.restore.availability(ready) == .available)
        #expect(LibraryBackupMenuState.restore.summary == "Restore the selected backup.")
    }
}
