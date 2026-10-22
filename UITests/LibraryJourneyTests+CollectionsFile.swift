// LibraryJourneyTests+CollectionsFile.swift: J16, collections survive a
// relaunch (filters-collections; slice FC-e). Written by FC-13, enabled by
// FC-14 (the codec) on FC-15's store. Steps 1-3 fake (`shoot`), step 4 live
// on `LibraryFiles.writeShoot`'s JPEGs.
import XCTest

final class LibraryCollectionsFileJourneyTests: XCTestCase {
    @MainActor func testCollectionsSurviveRelaunch() throws {
        // Step 1 (F): Keepers of IMG_0001-IMG_0003, rejects hidden.
        let catalog = try LibraryFiles.freshCatalogDir()
        let folder = try LibraryFiles.freshPhotoFolder()
        let live = try LibraryFiles.freshCatalogDir()
        addTeardownBlock { for url in [catalog, folder, live] { try? FileManager.default.removeItem(at: url) } }
        let file = catalog.appending(path: "collections.json")
        let arguments = ["-LibraryFixture", "shoot", "-LibraryCatalogDir", catalog.path]
        var library = Journey("Library", self, arguments: arguments)
        makeKeepers(library)
        library.element("library.filter.hideRejected").click()
        expectValue("library.filter", "Rejects hidden; 3 of 3", library)
        // Step 2 (F): saved, terminated, relaunched.
        expectSaved(file, holding: ["\"Keepers\"", "\"hidesRejected\" : true"], library)
        library.app.terminate()
        library = Journey("Library", self, arguments: arguments)
        expectRow("Keepers", 3, library)
        library.shot("collections-relaunched")
        expectValue("library.filter", "Rejects hidden; 3 of 3", library)
        library.app.terminate()
        // Step 3 (F): a damaged file is set aside with the notice.
        let damaged = Data("not json".utf8)
        try damaged.write(to: file)
        library = Journey("Library", self, arguments: arguments)
        expectRow("All Photos", 24, library)
        let notice = "Library couldn't read your collections. The file was set aside as collections.json.bad."
        let message = library.element("library.notice").descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", notice, notice)).firstMatch
        XCTAssert(message.waitForExistence(timeout: 10), "the notice doesn't read \"\(notice)\"")
        library.shot("collections-damaged")
        XCTAssertFalse(row("Keepers", library).exists, "Keepers survived a damaged file")
        expectValue("library.filter", "All photos; 24 of 24", library)  // All Photos selected
        let setAside = catalog.appending(path: "collections.json.bad")
        XCTAssert(wait(10) { (try? Data(contentsOf: setAside)) == damaged }, "collections.json.bad isn't the old file")
        library.app.terminate()
        // Step 4 (L): live photos keep their membership across a relaunch.
        try LibraryFiles.writeShoot(in: folder)
        library = Journey("Library", self, arguments: [
            "-LibraryImportFolder", folder.path, "-LibraryCatalogDir", live.path, "-LibraryImportOnLaunch",
        ])
        makeKeepers(library)
        expectValue("library.catalog", "saved", library, timeout: 15)
        expectSaved(live.appending(path: "collections.json"), holding: ["\"Keepers\""], library)
        library.app.terminate()
        library = Journey("Library", self, arguments: ["-LibraryCatalogDir", live.path])
        expectRow("Keepers", 3, library, timeout: 30)
        library.app.terminate()
    }

    /// View > Sort By > Name; IMG_0001 to IMG_0003 into a new collection renamed Keepers.
    @MainActor private func makeKeepers(_ library: Journey) {
        XCTAssert(cell("IMG_0024", library).waitForExistence(timeout: 60), "no grid cell for IMG_0024")
        let view = library.app.menuBars.firstMatch.menuBarItems["View"]
        view.click()
        view.menuItems["Sort By"].hover()
        view.menuItems["Sort By"].menuItems["Name"].click()
        cell("IMG_0001", library).click()
        XCUIElement.perform(withKeyModifiers: .shift) { cell("IMG_0003", library).click() }
        library.press(character: "n", .command)
        expectRow("Untitled Collection", 3, library)
        row("Untitled Collection", library).doubleClick()
        library.app.typeText("Keepers\r")
        expectRow("Keepers", 3, library)
    }

    /// `file` holds every one of `parts`, then `library.collections` reads saved.
    @MainActor private func expectSaved(_ file: URL, holding parts: [String], _ library: Journey) {
        let written = wait(10) {
            let text = (try? Data(contentsOf: file)).map { String(decoding: $0, as: UTF8.self) } ?? ""
            return parts.allSatisfy(text.contains)
        }
        XCTAssert(written, "\(file.lastPathComponent) never held \(parts)")
        expectValue("library.collections", "saved", library, timeout: 10)
    }
    @MainActor private func cell(_ name: String, _ library: Journey) -> XCUIElement {
        library.app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND identifier CONTAINS %@", "library.grid.cell.", name)).firstMatch
    }
    @MainActor private func row(_ title: String, _ library: Journey) -> XCUIElement {
        let types = [XCUIElement.ElementType.tableRow, .outlineRow, .cell].map { NSNumber(value: $0.rawValue) }
        return library.element("suite.sidebar").descendants(matching: .any)
            .matching(NSPredicate(format: "elementType IN %@", types))
            .containing(NSPredicate(format: "label == %@ OR value == %@", title, title)).firstMatch
    }
    @MainActor private func expectRow(_ title: String, _ count: Int, _ library: Journey, timeout: TimeInterval = 10) {
        let found = row(title, library)
        XCTAssert(found.waitForExistence(timeout: timeout), "the sidebar has no \(title) row")
        let badge = found.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@ OR value == %@", "\(count)", "\(count)")).firstMatch
        XCTAssert(badge.waitForExistence(timeout: 10), "\(title) doesn't count \(count)")
    }
    @MainActor private func expectValue(_ id: String, _ expected: String, _ library: Journey, timeout: TimeInterval = 5) {
        let reads = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", expected), object: library.element(id))
        XCTAssertEqual(XCTWaiter.wait(for: [reads], timeout: timeout), .completed, "\(id) doesn't read \(expected)")
    }
    @MainActor private func wait(_ seconds: TimeInterval, _ condition: () -> Bool) -> Bool {
        let deadline = Date(timeIntervalSinceNow: seconds)
        while Date() < deadline, !condition() { Thread.sleep(forTimeInterval: 0.1) }
        return condition()
    }
}
