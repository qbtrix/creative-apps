// LibraryJourneyTests+CollectionsFile.swift: J16, your collections survive a
// relaunch (packet docs/blueprints/library/features/filters-collections.md,
// Journey steps; slice FC-e). Its own XCTestCase class. Written before its
// code (FC-13, contract rule 13): FC-14 sets `waitsOn` to nil once FC-15's
// store has merged. Steps 1-3 run on the `shoot` fakes, step 4 live
// on `LibraryFiles.writeShoot`'s JPEGs; every launch passes a fresh
// `-LibraryCatalogDir`, the folder `collections.json` lives in. "Saved" is
// the hidden `library.collections` element (`collectionsFileValue`) once
// the file on disk holds the change.
import XCTest

final class LibraryCollectionsFileJourneyTests: XCTestCase {
    /// Why J16 is skipped; FC-14 sets it to nil.
    private static let waitsOn: String? = "waits on FC-14"

    @MainActor func testCollectionsSurviveRelaunch() throws {
        if let reason = Self.waitsOn { throw XCTSkip(reason) }
        // Step 1 (F): Keepers of IMG_0001-IMG_0003, renamed, rejects hidden.
        let catalog = try LibraryFiles.freshCatalogDir()
        addTeardownBlock { try? FileManager.default.removeItem(at: catalog) }
        let file = catalog.appending(path: "collections.json")
        let arguments = ["-LibraryFixture", "shoot", "-LibraryCatalogDir", catalog.path]
        var library = Journey("Library", self, arguments: arguments)
        makeKeepers(library)
        click("library.filter.hideRejected", library)
        expectValue("Rejects hidden; 3 of 3", library)

        // Step 2 (F): once the file holds it, terminate and relaunch.
        expectSaved(file, holding: ["\"Keepers\"", "\"hidesRejected\" : true"], library)
        library.app.terminate()
        library = Journey("Library", self, arguments: arguments)
        expectRow("Keepers", 3, library)
        library.shot("collections-relaunched")
        expectValue("Rejects hidden; 3 of 3", library)
        library.app.terminate()

        // Step 3 (F): a damaged file is set aside with the notice; no rows of yours.
        let damaged = Data("not json".utf8)
        try damaged.write(to: file)
        library = Journey("Library", self, arguments: arguments)
        expectRow("All Photos", 24, library)
        expectNotice(
            "Library couldn't read your collections. The file was set aside as collections.json.bad.", library)
        library.shot("collections-damaged")
        XCTAssertFalse(row("Keepers", library).exists, "Keepers survived a damaged collections file")
        expectValue("All photos; 24 of 24", library)
        let setAside = catalog.appending(path: "collections.json.bad")
        XCTAssert(Self.wait(10) { (try? Data(contentsOf: setAside)) == damaged }, "collections.json.bad isn't the old file")
        library.app.terminate()

        // Step 4 (L): live photos; persist restores them, this file their membership.
        let folder = try LibraryFiles.freshPhotoFolder()
        let live = try LibraryFiles.freshCatalogDir()
        addTeardownBlock { for url in [folder, live] { try? FileManager.default.removeItem(at: url) } }
        try LibraryFiles.writeShoot(in: folder)
        library = Journey("Library", self, arguments: [
            "-LibraryImportFolder", folder.path, "-LibraryCatalogDir", live.path, "-LibraryImportOnLaunch",
        ])
        expectRow("All Photos", 24, library, timeout: 60)
        makeKeepers(library)
        let readout = library.element("library.catalog")
        XCTAssert(Self.wait(15) { Self.text(readout) == "saved" }, "library.catalog never read saved")
        expectSaved(live.appending(path: "collections.json"), holding: ["\"Keepers\""], library)
        library.app.terminate()
        library = Journey("Library", self, arguments: ["-LibraryCatalogDir", live.path])
        expectRow("Keepers", 3, library, timeout: 30)
        library.shot("collections-relaunched-live")
        library.app.terminate()
    }

    /// Name order; IMG_0001 to IMG_0003 into a new collection renamed Keepers.
    @MainActor private func makeKeepers(_ library: Journey) {
        XCTAssert(cell("IMG_0024", library).waitForExistence(timeout: 60), "no grid cell for IMG_0024")
        menu("View", "Sort By", "Name", in: library).click()
        cell("IMG_0001", library).click()
        XCUIElement.perform(withKeyModifiers: .shift) { cell("IMG_0003", library).click() }
        library.press(character: "n", .command)
        expectRow("Untitled Collection", 3, library)
        row("Untitled Collection", library).doubleClick()
        library.app.typeText("Keepers\r")
        expectRow("Keepers", 3, library)
    }

    /// Within ten seconds `file` holds every one of `parts` and `library.collections` reads saved.
    @MainActor private func expectSaved(_ file: URL, holding parts: [String], _ library: Journey) {
        let written = Self.wait(10) {
            guard let data = try? Data(contentsOf: file) else { return false }
            let text = String(decoding: data, as: UTF8.self)
            return parts.allSatisfy(text.contains)
        }
        XCTAssert(written, "\(file.lastPathComponent) never held \(parts)")
        let marker = library.element("library.collections")
        XCTAssert(Self.wait(10) { Self.text(marker) == "saved" }, "library.collections reads \(Self.text(marker))")
    }

    /// The grid cell `library.grid.cell.<id>` whose id names `name`.
    @MainActor private func cell(_ name: String, _ library: Journey) -> XCUIElement {
        library.app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "library.grid.cell."))
            .matching(NSPredicate(format: "identifier CONTAINS %@", name)).firstMatch
    }
    /// The sidebar row titled `title`.
    @MainActor private func row(_ title: String, _ library: Journey) -> XCUIElement {
        let types = [XCUIElement.ElementType.tableRow, .outlineRow, .cell].map { NSNumber(value: $0.rawValue) }
        return library.element("suite.sidebar").descendants(matching: .any)
            .matching(NSPredicate(format: "elementType IN %@", types))
            .containing(NSPredicate(format: "label == %@ OR value == %@", title, title)).firstMatch
    }
    /// The sidebar row `title` exists and shows `count`.
    @MainActor private func expectRow(_ title: String, _ count: Int, _ library: Journey, timeout: TimeInterval = 10) {
        let found = row(title, library)
        XCTAssert(found.waitForExistence(timeout: timeout), "the sidebar has no \(title) row")
        let badge = found.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@ OR value == %@", "\(count)", "\(count)")).firstMatch
        XCTAssert(badge.waitForExistence(timeout: 10), "\(title) doesn't count \(count)")
    }
    /// Opens `bar` and returns its item `path`, hovering each submenu on the way.
    @MainActor private func menu(_ bar: String, _ path: String..., in library: Journey) -> XCUIElement {
        var item = library.app.menuBars.firstMatch.menuBarItems[bar]
        item.click()
        for (index, title) in path.enumerated() {
            if index > 0 { item.hover() }
            item = item.menuItems[title]
            XCTAssert(item.waitForExistence(timeout: 3), "\(bar) has no \(path.joined(separator: " > "))")
        }
        return item
    }
    @MainActor private func click(_ identifier: String, _ library: Journey) {
        let control = library.element(identifier)
        XCTAssert(control.waitForExistence(timeout: 5), "no \(identifier)")
        XCTAssert(control.isEnabled, "\(identifier) is disabled")
        control.click()
    }
    /// Within `timeout` the filter bar (`library.filter`) reads `expected`.
    @MainActor private func expectValue(_ expected: String, _ library: Journey, timeout: TimeInterval = 5) {
        let bar = library.element("library.filter")
        let reads = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", expected), object: bar)
        XCTAssertEqual(XCTWaiter.wait(for: [reads], timeout: timeout), .completed, "the filter bar isn't \(expected)")
    }
    /// Within ten seconds the notice (`library.notice`) reads `text`.
    @MainActor private func expectNotice(_ text: String, _ library: Journey) {
        let message = library.element("library.notice").descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", text, text)).firstMatch
        XCTAssert(message.waitForExistence(timeout: 10), "the notice (library.notice) doesn't read \"\(text)\"")
    }
    @MainActor private static func wait(_ seconds: TimeInterval, _ condition: () -> Bool) -> Bool {
        let deadline = Date(timeIntervalSinceNow: seconds)
        while Date() < deadline, !condition() { Thread.sleep(forTimeInterval: 0.1) }
        return condition()
    }
    /// What an element reads: its value, else its label.
    @MainActor private static func text(_ element: XCUIElement) -> String {
        let value = element.value as? String ?? ""
        return value.isEmpty ? element.label : value
    }
}
