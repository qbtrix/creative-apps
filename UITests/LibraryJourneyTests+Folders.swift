// LibraryJourneyTests+Folders.swift: LJ-FO (folders), browse the catalog by the folders its photos sit in
// (packet docs/blueprints/library/features/folders.md, Journey step 1). Three fixture folders are imported
// into one catalog, `trips` with 2025/ and 2026/ inside: FOLDERS shows three roots with counts, a subfolder's
// click shows only its photos, and Include Subfolders off on `trips` shows only its own. Written first
// (FO-1): skips until FO-6 puts the section on live.
import XCTest

final class LibraryFoldersJourneyTests: XCTestCase {
    @MainActor func testBrowseFolders() throws {
        throw XCTSkip("waits on FO-6")
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

        // FOLDERS shows three roots with their counts.
        let root = browser.element("library.folders.\(trips.path)")
        XCTAssert(root.waitForExistence(timeout: 10), "no FOLDERS row for trips")
        for folder in [family, pets] {
            XCTAssert(browser.element("library.folders.\(folder.path)").exists, "no FOLDERS row for \(folder.lastPathComponent)")
        }
        browser.shot("library-sidebar-folders", element: browser.element("library.folders"))

        // Expand trips, click 2025: the grid shows its two photos.
        root.disclosureTriangles.firstMatch.click()
        let year = browser.element("library.folders.\(trips.appending(path: "2025").path)")
        XCTAssert(year.waitForExistence(timeout: 5), "trips didn't expand to 2025")
        year.click()
        XCTAssertEqual(browser.app.descendants(matching: .any).matching(identifier: "library.grid.cell").count, 2)
        browser.shot("library-folder-selected")

        // Include Subfolders off on trips: only its own photo.
        root.rightClick()
        browser.app.menuItems["Include Subfolders"].click()
        root.click()
        XCTAssertEqual(browser.app.descendants(matching: .any).matching(identifier: "library.grid.cell").count, 1)
    }
}
