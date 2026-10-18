// LibraryJourneyTests+Persist.swift: J8 and J9, the catalog across launches
// (packet docs/blueprints/library/features/persist.md, Journey steps). Both
// run live on files LibraryFiles writes, and every relaunch reuses the
// journey's `-LibraryCatalogDir`. The window publishes no `library.catalog`
// readout yet, so "saved" is read from disk: the journey waits until
// `catalog.json` holds the changes before it terminates the app (terminate
// kills it, so the quit flush never runs). A cell is found by its identifier,
// `library.grid.cell.<photo id>`, the id being the file's path; its value is
// the catalog's `cellValue` ("ready 640×480 4 stars, Picked, Red label",
// "unreadable No stars"). The catalog notice is `library.notice`, its Show in
// Finder button `library.notice.action`.
import XCTest

extension LibraryJourneyTests {
    /// J8: ratings, flags and labels come back after a relaunch, and photos
    /// whose files went away show as unreadable but can still be rated.
    @MainActor func testCatalogSurvivesRelaunch() throws {
        // Step 1: 6 JPEGs, 2 in day2/, imported on launch; rate, pick and label one each.
        let folder = try LibraryFiles.freshPhotoFolder()
        let catalog = try LibraryFiles.freshCatalogDir()
        addTeardownBlock { for url in [folder, catalog] { try? FileManager.default.removeItem(at: url) } }
        try LibraryFiles.write(4, in: folder)
        try LibraryFiles.write(2, in: folder, subfolder: "day2")
        let top = "/\(folder.lastPathComponent)/jpeg-"
        let (rated, picked, labelled) = ("\(top)0001.jpg", "\(top)0002.jpg", "\(top)0003.jpg")
        let gone = ["/day2/jpeg-0001.jpg", "/day2/jpeg-0002.jpg"]
        var library = Journey("Library", self, arguments: [
            "-LibraryImportFolder", folder.path, "-LibraryCatalogDir", catalog.path, "-LibraryImportOnLaunch",
        ])
        expectPersistCells(6, library, timeout: 60)
        persistCell(rated, library).click()
        library.press(character: "4")
        expectPersistCell(rated, contains: "4 stars", library)
        persistCell(picked, library).click()
        library.press(character: "p")
        expectPersistCell(picked, contains: "Picked", library)
        persistCell(labelled, library).click()
        setLabelRed(library)
        expectPersistCell(labelled, contains: "Red", library)

        // Step 2: once catalog.json holds the changes, quit and relaunch with no import.
        expectSaved(in: catalog) { photos in
            photos.count == 6 && photos.contains { $0["rating"] as? Int == 4 }
                && photos.contains { $0["flag"] as? String == "Pick" }
                && photos.contains { $0["label"] as? String == "Red" }
        }
        library.app.terminate()
        library = Journey("Library", self, arguments: ["-LibraryCatalogDir", catalog.path])
        expectPersistCells(6, library, timeout: 30)
        library.shot("relaunched")
        expectPersistCell(rated, contains: "4 stars", library)
        expectPersistCell(picked, contains: "Picked", library)
        expectPersistCell(labelled, contains: "Red", library)
        expectPersistSidebarCount("Favorites", 1, library)
        library.app.terminate()

        // Step 3: day2/ is deleted; its two photos come back unreadable, and still rate.
        try FileManager.default.removeItem(at: folder.appending(path: "day2", directoryHint: .isDirectory))
        library = Journey("Library", self, arguments: ["-LibraryCatalogDir", catalog.path])
        expectPersistCells(6, library, timeout: 30)
        library.shot("missing-files")
        for suffix in gone {
            let value = persistValue(of: persistCell(suffix, library))
            XCTAssert(value.hasPrefix("unreadable"), "\(suffix)'s cell reads \"\(value)\", not unreadable")
        }
        let missing = persistCell(gone[0], library)
        expectMissingHelp(on: missing, library)
        missing.click()
        library.press(character: "1")
        expectPersistCell(gone[0], contains: "1 star", library)
        library.app.terminate()
    }

    /// J9: a damaged catalog is set aside with a notice and Show in Finder; a
    /// catalog from a newer Library is refused and never written over.
    @MainActor func testDamagedCatalogIsSetAside() throws {
        // Step 1: `not json` as catalog.json: a new empty catalog, the notice, the file set aside.
        let folder = try LibraryFiles.freshPhotoFolder()
        let catalog = try LibraryFiles.freshCatalogDir()
        addTeardownBlock { for url in [folder, catalog] { try? FileManager.default.removeItem(at: url) } }
        let file = catalog.appending(path: "catalog.json")
        let setAside = catalog.appending(path: "catalog.json.bad")
        let damaged = Data("not json".utf8)
        try damaged.write(to: file)
        var library = Journey("Library", self, arguments: ["-LibraryCatalogDir", catalog.path])
        XCTAssert(library.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        expectCatalogNotice(
            "Library couldn't read its catalog and started a new one. The old file is catalog.json.bad.", library)
        let show = library.element("library.notice.action")
        XCTAssert(show.waitForExistence(timeout: 5), "the notice has no Show in Finder (library.notice.action)")
        XCTAssertEqual(show.label, "Show in Finder", "the damaged notice's button")
        expectPersistText("New Catalog Started", library)
        library.shot("catalog-damaged")
        XCTAssert(Self.persistWait { (try? Data(contentsOf: setAside)) == damaged }, "catalog.json.bad doesn't hold the old file")
        library.app.terminate()

        // Step 2: a catalog from a newer Library: the notice, no action; an
        // import and a rating leave catalog.json byte for byte as it was.
        let newer = Data(#"{"version": 2}"#.utf8)
        try newer.write(to: file)
        try LibraryFiles.write(2, in: folder)
        library = Journey("Library", self, arguments: [
            "-LibraryImportFolder", folder.path, "-LibraryCatalogDir", catalog.path,
        ])
        XCTAssert(library.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        let refusal = "This catalog was made by a newer Library. Update Library to open it."
        expectCatalogNotice(refusal, library)
        XCTAssertFalse(library.element("library.notice.action").exists, "the newer notice offers an action")
        expectPersistText("Catalog Not Opened", library)
        library.shot("catalog-newer")
        let menu = library.app.menuBars.firstMatch.menuBarItems["File"]
        menu.click()
        let item = menu.menuItems["Import Folder…"]
        XCTAssert(item.waitForExistence(timeout: 3), "the File menu has no Import Folder…")
        XCTAssert(item.isEnabled, "File > Import Folder… is disabled over a newer catalog")
        item.click()
        expectPersistCells(2, library, timeout: 60)
        let first = "/\(folder.lastPathComponent)/jpeg-0001.jpg"
        persistCell(first, library).click()
        library.press(character: "1")
        expectPersistCell(first, contains: "1 star", library)
        expectCatalogNotice(refusal, library)
        // Past the 500 ms save delay several times over: nothing was written.
        Thread.sleep(forTimeInterval: 3)
        XCTAssertEqual(try Data(contentsOf: file), newer, "catalog.json changed over a newer catalog")
        XCTAssertEqual(try Data(contentsOf: setAside), damaged, "a newer catalog was set aside")
        library.app.terminate()
    }

    // MARK: - Persist helpers

    private static let persistCellPrefix = "library.grid.cell."

    /// The grid cells (`library.grid.cell.<id>`).
    @MainActor private func persistCells(_ library: Journey) -> XCUIElementQuery {
        library.app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", Self.persistCellPrefix))
    }

    /// The grid cell whose photo's path ends `suffix`.
    @MainActor private func persistCell(_ suffix: String, _ library: Journey) -> XCUIElement {
        let cell = persistCells(library).matching(NSPredicate(format: "identifier ENDSWITH %@", suffix)).firstMatch
        XCTAssert(cell.waitForExistence(timeout: 10), "no grid cell for …\(suffix)")
        return cell
    }

    /// A cell's value (its `cellValue`), else its label.
    @MainActor private func persistValue(of cell: XCUIElement) -> String {
        let value = (cell.value as? String) ?? ""
        return value.isEmpty ? cell.label : value
    }

    /// Within `timeout`, All Photos counts `count` and the grid shows that many cells.
    @MainActor private func expectPersistCells(_ count: Int, _ library: Journey, timeout: TimeInterval) {
        XCTAssert(library.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        expectPersistSidebarCount("All Photos", count, library, timeout: timeout)
        let shown = Self.persistWait { self.persistCells(library).count == count }
        XCTAssert(shown, "the grid shows \(persistCells(library).count) cells, not \(count)")
    }

    /// Within five seconds the cell for `suffix` has `text` in its value.
    @MainActor private func expectPersistCell(_ suffix: String, contains text: String, _ library: Journey) {
        let cell = persistCell(suffix, library)
        let found = Self.persistWait { self.persistValue(of: cell).contains(text) }
        XCTAssert(found, "…\(suffix)'s cell reads \"\(persistValue(of: cell))\", without \(text)")
    }

    /// Metadata > Set Label > Red on the selection.
    @MainActor private func setLabelRed(_ library: Journey) {
        let metadata = library.app.menuBars.firstMatch.menuBarItems["Metadata"]
        metadata.click()
        let parent = metadata.menuItems["Set Label"]
        XCTAssert(parent.waitForExistence(timeout: 3), "the Metadata menu has no Set Label")
        parent.hover()
        let red = parent.menuItems["Red"]
        XCTAssert(red.waitForExistence(timeout: 3), "Metadata > Set Label has no Red")
        XCTAssert(red.isEnabled, "Metadata > Set Label > Red is disabled with a photo selected")
        red.click()
    }

    /// The missing photo's help reads "The file is missing." when the runner
    /// shows a help tag; the shell journey notes it may not (#1678's runner),
    /// so a missing tag is recorded, not failed, and LibraryReadoutsTests
    /// proves the text.
    @MainActor private func expectMissingHelp(on cell: XCUIElement, _ library: Journey) {
        let text = "The file is missing."
        cell.hover()
        let tag = library.app.helpTags.firstMatch
        guard tag.waitForExistence(timeout: 3) else {
            XCTContext.runActivity(named: "no help tag on hover; \"\(text)\" is unchecked here") { _ in }
            return
        }
        let match = library.app.helpTags.matching(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", text, text))
        let inside = tag.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", text, text))
        XCTAssert(match.count + inside.count > 0, "the missing photo's help tag doesn't read \"\(text)\"")
    }

    /// Within ten seconds the catalog notice (`library.notice`) reads `text`.
    @MainActor private func expectCatalogNotice(_ text: String, _ library: Journey) {
        let message = library.element("library.notice").descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", text, text)).firstMatch
        XCTAssert(message.waitForExistence(timeout: 10), "the catalog notice (library.notice) doesn't read \"\(text)\"")
    }

    /// Some text in the window reads `text` (an empty state's title).
    @MainActor private func expectPersistText(_ text: String, _ library: Journey) {
        let match = library.app.windows.firstMatch.staticTexts
            .matching(NSPredicate(format: "label == %@ OR value == %@", text, text)).firstMatch
        XCTAssert(match.waitForExistence(timeout: 10), "the window doesn't show \"\(text)\"")
    }

    /// The sidebar row `title` shows `count`.
    @MainActor private func expectPersistSidebarCount(
        _ title: String, _ count: Int, _ library: Journey, timeout: TimeInterval = 10
    ) {
        let rowTypes = [XCUIElement.ElementType.tableRow, .outlineRow, .cell].map { NSNumber(value: $0.rawValue) }
        let row = library.element("suite.sidebar").descendants(matching: .any)
            .matching(NSPredicate(format: "elementType IN %@", rowTypes))
            .containing(NSPredicate(format: "label == %@ OR value == %@", title, title)).firstMatch
        XCTAssert(row.waitForExistence(timeout: 10), "the sidebar has no \(title) row")
        let badge = row.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@ OR value == %@", "\(count)", "\(count)")).firstMatch
        XCTAssert(badge.waitForExistence(timeout: timeout), "\(title) doesn't count \(count)")
    }

    /// Within ten seconds `catalog.json` in `catalog` is a v1 file whose
    /// photos satisfy `check`: the app saved (the `library.catalog` stand-in).
    @MainActor private func expectSaved(in catalog: URL, _ check: @escaping ([[String: Any]]) -> Bool) {
        let file = catalog.appending(path: "catalog.json")
        let saved = Self.persistWait {
            guard let data = try? Data(contentsOf: file),
                let top = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                top["version"] as? Int == 1, let photos = top["photos"] as? [[String: Any]]
            else { return false }
            return check(photos)
        }
        XCTAssert(saved, "catalog.json never held the changes")
    }

    /// Polls `condition` for up to ten seconds.
    @MainActor private static func persistWait(_ condition: () -> Bool) -> Bool {
        for _ in 0..<50 {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return condition()
    }
}
