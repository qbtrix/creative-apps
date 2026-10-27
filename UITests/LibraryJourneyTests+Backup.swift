// LibraryJourneyTests+Backup.swift: LJ-BK (packet docs/blueprints/library/features/catalog-backup.md, Journey
// steps; BK-2 written, BK-5 turned on live). On a catalog with fixture backups, rate a photo, File > Restore
// Catalog Backup…, pick yesterday's, confirm; the rating is yesterday's; reopen the sheet: today's catalog is now
// a backup. -LibraryFixtureBackups seeds three backups of the samples in a scratch folder (LibraryLaunch.backups).
import XCTest

final class LibraryBackupJourneyTests: XCTestCase {
    @MainActor func testRestoreBackup() throws {
        // Step 1: launch Library with the sample catalog and its fixture backups.
        let library = Journey("Library", self, arguments: ["-LibraryFixture", "samples", "-LibraryFixtureBackups", "1"])
        XCTAssert(library.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")

        // Rate the first photo five stars.
        let first = library.app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "library.grid.cell.")).firstMatch
        XCTAssert(first.waitForExistence(timeout: 10), "no first photo in the grid")
        first.click()
        library.press(character: "5", step: "rate five stars")

        // File > Restore Catalog Backup… opens the sheet with a row per backup.
        let file = library.app.menuBars.firstMatch.menuBarItems["File"]
        file.click()
        let item = file.menuItems["Restore Catalog Backup…"]
        XCTAssert(item.waitForExistence(timeout: 5), "File has no Restore Catalog Backup…")
        XCTAssert(item.isEnabled, "Restore Catalog Backup… is off with backups on disk")
        item.click()
        let rows = library.app.descendants(matching: .any).matching(identifier: "library.backup.row")
        XCTAssert(rows.firstMatch.waitForExistence(timeout: 5), "the sheet lists no backups")
        let before = rows.count
        library.shot("restore-backup-sheet", screen: true)

        // Pick yesterday's (the second row; the newest is first) and confirm.
        rows.element(boundBy: min(1, before - 1)).click()
        library.app.buttons["library.backup.restore"].click()
        let confirm = library.app.buttons["library.backup.confirm"]
        XCTAssert(confirm.waitForExistence(timeout: 5), "Restore asked for no confirm")
        library.shot("restore-confirm", screen: true)
        confirm.click()

        // The rating is yesterday's: the first photo no longer shows five stars.
        XCTAssert(first.waitForExistence(timeout: 10), "the grid didn't come back after the restore")
        XCTAssertFalse((first.value as? String ?? "").contains("5 stars"), "the restore kept today's rating")

        // Reopen the sheet: today's catalog is now a backup.
        file.click()
        file.menuItems["Restore Catalog Backup…"].click()
        XCTAssert(rows.firstMatch.waitForExistence(timeout: 5), "the sheet lists no backups after the restore")
        XCTAssertEqual(rows.count, before + 1, "the restore didn't back up today's catalog first")
        library.press(.escape)
    }
}
