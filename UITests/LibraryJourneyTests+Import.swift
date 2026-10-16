// LibraryJourneyTests+Import.swift: J1, import a folder (packet
// docs/blueprints/library/features/import.md, Journey steps). Steps 1-5 run
// live on real files the spine's LibraryFiles helpers write: import a mixed
// folder, import it again, then an unreadable one. Step 6 runs on the fakes
// (`-LibraryFixture shoot-unimported -LibraryFakeMode slow`) to catch the
// progress row before the slow importer moves on. The progress row is
// `library.import.progress` (its label the text), the notice
// `library.import.notice` with its Show and Close buttons.
import XCTest

extension LibraryJourneyTests {
    /// J1: File > Import Folder… brings a folder's photos into the grid, says
    /// what it skipped, finds nothing new the second time, and says when it
    /// can't read a folder.
    @MainActor func testImportAFolder() throws {
        if Self.waitsOnGridIdentifiers {
            throw XCTSkip(
                "waits on #779 and #1368: ThumbnailGrid cells and its scroller carry no identifier, so every imported cell is a new audit violation (#1367)"
            )
        }
        // Step 1: 24 JPEGs (4 in day2/), 1 PNG, 1 HEIC, broken.jpg and notes.txt.
        let folder = try LibraryFiles.freshCatalogDir()
        let catalog = try LibraryFiles.freshCatalogDir()
        addTeardownBlock { for url in [folder, catalog] { try? FileManager.default.removeItem(at: url) } }
        try LibraryFiles.write(20, in: folder)
        try LibraryFiles.write(4, in: folder, subfolder: "day2")
        try LibraryFiles.write(1, kinds: [.png, .heic], in: folder)
        let broken = try LibraryFiles.broken(in: folder)
        try Data("not a photo".utf8).write(to: folder.appending(path: "notes.txt"))
        let name = folder.lastPathComponent
        var library = Journey("Library", self, arguments: [
            "-LibraryImportFolder", folder.path, "-LibraryCatalogDir", catalog.path,
        ])
        XCTAssert(library.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")

        // Step 2: Import Folder… starts the import.
        library.click("Import Folder…", in: .window, step: "importing")

        // Step 3: the progress row goes; 26 photos, the earliest first, one failure listed.
        let notice = library.element("library.import.notice")
        XCTAssert(notice.waitForExistence(timeout: 60), "no import notice (library.import.notice)")
        XCTAssert(library.element("library.import.progress").waitForNonExistence(timeout: 10), "the progress row stayed")
        expectAllPhotos(26, library)
        shrinkThumbnails(library)
        let filled = Self.waitFor { self.gridCells(library).count == 26 }
        let cells = gridCells(library).count
        XCTAssert(filled, "the grid has \(cells) cells, not 26")
        let first = gridCells(library).firstMatch.label
        XCTAssert(first.contains("-0001"), "the first cell is \(first), not one of the earliest written (…-0001)")
        expectNotice("Imported 26 photos. 1 file couldn't be imported.", library)
        let show = library.element("library.import.notice.show")
        XCTAssert(show.waitForExistence(timeout: 5), "the notice has no Show (library.import.notice.show)")
        show.click()
        expectNotice("broken.jpg: not an image file", library)
        let mentions = notice.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", "notes.txt", "notes.txt"))
        XCTAssertEqual(mentions.count, 0, "the notice mentions notes.txt")
        library.shot("imported")

        // Step 4: without broken.jpg, the same folder again brings nothing new.
        try FileManager.default.removeItem(at: broken)
        importFromFileMenu(library)
        expectNotice("No new photos in \(name).", library)
        library.shot("import-again")
        XCTAssertEqual(gridCells(library).count, 26, "importing again changed the grid's cell count")
        expectAllPhotos(26, library)
        library.app.terminate()

        // Step 5: a folder Library can't list gives the error notice.
        let denied = try LibraryFiles.unreadableFolder()
        let deniedCatalog = try LibraryFiles.freshCatalogDir()
        addTeardownBlock {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: denied.path)
            for url in [denied, deniedCatalog] { try? FileManager.default.removeItem(at: url) }
        }
        library = Journey("Library", self, arguments: [
            "-LibraryImportFolder", denied.path, "-LibraryCatalogDir", deniedCatalog.path,
        ])
        XCTAssert(library.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        importFromFileMenu(library)
        expectNotice("Library can't read \(denied.lastPathComponent). Check that you have access to it.", library)
        library.shot("import-denied")
        library.app.terminate()

        // Step 6 (fakes): the slow importer shows "Importing 1 of 24" within 2 s.
        library = Journey("Library", self, arguments: [
            "-LibraryFixture", "shoot-unimported", "-LibraryFakeMode", "slow", "-LibraryImportFolder", "/fake-shoot",
        ])
        XCTAssert(library.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        importFromFileMenu(library)
        let progress = library.element("library.import.progress")
        let start = Date()
        var reads = ""
        while Date().timeIntervalSince(start) < 2, reads != "Importing 1 of 24" {
            reads = progress.exists ? progress.label : ""
        }
        library.shot("import-progress")
        XCTAssertEqual(reads, "Importing 1 of 24", "library.import.progress within 2 s of File > Import Folder…")
    }

    // MARK: - Import helpers

    /// J1 skips until #779 and #1368 give the grid's cells and scroller
    /// identifiers (#1367); set false to run it again. A flag, not a bare
    /// throw, so the journey below compiles without unreachable-code warnings.
    static let waitsOnGridIdentifiers = true

    /// File > Import Folder….
    @MainActor private func importFromFileMenu(_ library: Journey) {
        let file = library.app.menuBars.firstMatch.menuBarItems["File"]
        XCTAssert(file.waitForExistence(timeout: 5), "no File menu")
        file.click()
        let item = file.menuItems["Import Folder…"]
        XCTAssert(item.waitForExistence(timeout: 3), "the File menu has no Import Folder…")
        XCTAssert(item.isEnabled, "File > Import Folder… is disabled")
        item.click()
    }

    /// The import notice shows `text` within ten seconds.
    @MainActor private func expectNotice(_ text: String, _ library: Journey) {
        let match = library.element("library.import.notice").descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@ OR value == %@", text, text)).firstMatch
        XCTAssert(match.waitForExistence(timeout: 10), "the import notice doesn't read \"\(text)\"")
    }

    /// The sidebar's All Photos row shows `count`.
    @MainActor private func expectAllPhotos(_ count: Int, _ library: Journey) {
        let rowTypes = [XCUIElement.ElementType.tableRow, .outlineRow, .cell].map { NSNumber(value: $0.rawValue) }
        let row = library.element("suite.sidebar").descendants(matching: .any)
            .matching(NSPredicate(format: "elementType IN %@", rowTypes))
            .containing(NSPredicate(format: "label == %@ OR value == %@", "All Photos", "All Photos")).firstMatch
        XCTAssert(row.waitForExistence(timeout: 10), "the sidebar has no All Photos row")
        let badge = row.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@ OR value == %@", "\(count)", "\(count)")).firstMatch
        XCTAssert(badge.waitForExistence(timeout: 10), "All Photos doesn't count \(count)")
    }

    /// View > Zoom Out to the smallest thumbnails, so every cell of a
    /// 26-photo grid is on screen (the lazy grid lists only what it draws).
    @MainActor private func shrinkThumbnails(_ library: Journey) {
        for _ in 0..<2 { library.press(character: "-", .command) }
    }

    /// The grid's photo cells: buttons named after a LibraryFiles file.
    @MainActor private func gridCells(_ library: Journey) -> XCUIElementQuery {
        library.app.splitGroups.descendants(matching: .button)
            .matching(NSPredicate(format: "label MATCHES %@", ".*(jpeg|png|heic)-[0-9]{4}.*"))
    }

    /// Polls `condition` for up to ten seconds.
    @MainActor private static func waitFor(_ condition: () -> Bool) -> Bool {
        for _ in 0..<50 {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return condition()
    }
}
