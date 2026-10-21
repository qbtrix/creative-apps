// LibraryJourneyTests+Folders.swift: LJ-FO (folders), browse the catalog by the folders its photos sit in
// (packet docs/blueprints/library/features/folders.md, Journey step 1). Three fixture folders are imported
// into one catalog, `trips` with 2025/ and 2026/ inside: FOLDERS shows each with its count, a subfolder's click
// shows only its photos, and Include Subfolders off on `trips` shows only its own, which a later click on it
// keeps. The three sit in the temporary folder, so FOLDERS roots there and the test opens each collapsed
// group until the row it wants shows. Rows are found by title in `suite.sidebar`, grid cells by id prefix.
// On since FO-6.
import XCTest

final class LibraryFoldersJourneyTests: XCTestCase {
    @MainActor func testBrowseFolders() throws {
        let catalog = try LibraryFiles.freshCatalogDir()
        let trips = try LibraryFiles.freshPhotoFolder(), family = try LibraryFiles.freshPhotoFolder()
        let pets = try LibraryFiles.freshPhotoFolder()
        addTeardownBlock { for url in [catalog, trips, family, pets] { try? FileManager.default.removeItem(at: url) } }
        try LibraryFiles.write(1, in: trips)
        try LibraryFiles.write(2, in: trips, subfolder: "2025")
        try LibraryFiles.write(1, in: trips, subfolder: "2026")
        try LibraryFiles.write(2, in: family)
        try LibraryFiles.write(3, in: pets)

        // Import each folder into the same catalog, one launch each.
        var library: Journey?
        for folder in [trips, family, pets] {
            library?.app.terminate()
            let next = Journey("Library", self, arguments: ["-LibraryImportFolder", folder.path, "-LibraryCatalogDir", catalog.path])
            XCTAssert(next.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
            next.click("Import Folder…", in: .window, step: "import-\(folder.lastPathComponent)")
            XCTAssert(next.element("library.import.notice").waitForExistence(timeout: 60), "no import notice")
            library = next
        }
        let browser = try XCTUnwrap(library)

        // FOLDERS shows each imported folder.
        let root = folderRow(trips.lastPathComponent, browser)
        XCTAssert(root.exists, "no FOLDERS row for trips")
        for folder in [family, pets] {
            XCTAssert(folderRow(folder.lastPathComponent, browser).exists, "no FOLDERS row for \(folder.lastPathComponent)")
        }
        browser.shot("library-sidebar-folders", element: browser.element("suite.sidebar"))

        // Open trips, click 2025: the grid shows its two photos.
        let year = folderRow("2025", browser)
        XCTAssert(year.exists, "trips didn't open to 2025")
        year.click()
        expectCells(2, browser, "2025's click")
        browser.shot("library-folder-selected")

        // Include Subfolders off on trips: only its own photo, and a click on trips keeps it.
        root.rightClick()
        browser.app.menuItems["Include Subfolders"].click()
        expectCells(1, browser, "Include Subfolders off on trips")
        root.click()
        expectCells(1, browser, "a click on trips after Include Subfolders")
    }

    /// The sidebar row titled `title`, opening every collapsed group in the sidebar until it shows.
    @MainActor private func folderRow(_ title: String, _ library: Journey) -> XCUIElement {
        let types = [XCUIElement.ElementType.tableRow, .outlineRow, .cell].map { NSNumber(value: $0.rawValue) }
        let sidebar = library.element("suite.sidebar")
        let row = sidebar.descendants(matching: .any).matching(NSPredicate(format: "elementType IN %@", types))
            .containing(NSPredicate(format: "label == %@ OR value == %@", title, title)).firstMatch
        let closed = sidebar.disclosureTriangles.matching(NSPredicate(format: "value == 0"))
        for _ in 0..<12 where !row.waitForExistence(timeout: 2) && closed.count > 0 { closed.firstMatch.click() }
        return row
    }

    /// The grid shows `count` cells.
    @MainActor private func expectCells(_ count: Int, _ library: Journey, _ step: String) {
        let cells = library.app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "library.grid.cell."))
        let settled = NSPredicate { _, _ in cells.count == count }
        _ = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: settled, object: nil)], timeout: 5)
        XCTAssertEqual(cells.count, count, step)
    }
}
