// LibraryJourneyTests+Share.swift: share three photos through the system's
// share sheet (packet docs/blueprints/library/features/share-sheet.md,
// Journey; slice SH-4). Its own XCTestCase class, like +Export.swift. All
// live: the 24 JPEGs `LibraryFiles.writeShoot` writes, imported on launch into
// a fresh `-LibraryCatalogDir`. The grid's Share button is SuiteUI's
// ShareButton (`suite.share`); File > Share… is found by title.
//
// Written before its code (lead.md, contract rule 13, SH-4); live since SH-5,
// which makes the share copies reach the sheet and puts File > Share… on.
import Foundation
import XCTest

final class LibraryShareJourneyTests: XCTestCase {
    /// Select three photos, Share in the grid: the button prepares, offers
    /// "Share 3 Photos" and opens the system sheet; cancel it; File > Share…
    /// is on for the same selection.
    @MainActor func testShareThreePhotos() throws {
        let folder = try LibraryFiles.freshPhotoFolder()
        let catalog = try LibraryFiles.freshCatalogDir()
        addTeardownBlock { for url in [folder, catalog] { try? FileManager.default.removeItem(at: url) } }
        try LibraryFiles.writeShoot(in: folder)
        let library = Journey("Library", self, arguments: [
            // The switch goes last: AppKit reads `-Key value` pairs, so mid-list it would swallow
            // `-LibraryCatalogDir` and leave the catalog path to open as a document (#4823).
            "-LibraryImportFolder", folder.path, "-LibraryCatalogDir", catalog.path, "-LibraryImportOnLaunch",
        ])
        XCTAssert(library.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        XCTAssert(gridCell("IMG_0024", library).waitForExistence(timeout: 60), "no grid cell for IMG_0024")

        // Step 1: nothing selected, Share is off and says why.
        let share = library.element("suite.share")
        XCTAssert(share.waitForExistence(timeout: 5), "the grid has no Share button")
        XCTAssertFalse(share.isEnabled, "Share is on with nothing selected")

        // Step 2: select three photos; Share prepares, then offers the three.
        gridCell("IMG_0001", library).click()
        XCUIElement.perform(withKeyModifiers: .command) {
            gridCell("IMG_0002", library).click()
            gridCell("IMG_0003", library).click()
        }
        XCTAssert(share.isEnabled, "Share is off with three photos selected")
        library.shot("grid-share-button")
        share.click()
        let ready = library.app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Share 3 Photos")).firstMatch
        XCTAssert(ready.waitForExistence(timeout: 20), "Share never offered the three photos")

        // Step 3: the system sheet opens for them; cancel it.
        ready.click()
        library.shot("share-sheet", screen: true)
        library.press(.escape)

        // Step 4: File > Share… is on for the same selection.
        let file = library.app.menuBars.firstMatch.menuBarItems["File"]
        file.click()
        let item = file.menuItems["Share…"]
        XCTAssert(item.waitForExistence(timeout: 5), "File has no Share…")
        XCTAssert(item.isEnabled, "File > Share… is off with three photos selected")
        library.shot("file-share-menu", screen: true)
        library.press(.escape)
        library.app.terminate()
    }

    /// The grid cell `library.grid.cell.<id>` whose photo id names `name`.
    @MainActor private func gridCell(_ name: String, _ library: Journey) -> XCUIElement {
        library.app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND identifier CONTAINS %@", "library.grid.cell.", name)).firstMatch
    }
}
