// LibraryJourneyTests+Filters.swift: J13, filter by flag and rating (packet
// docs/blueprints/library/features/filters-collections.md). Written before its
// code (FC-6, contract rule 13) and enabled by FC-7. It walks the
// `shoot` fakes, then every step live on `LibraryFiles.writeShoot`'s JPEGs
// (shots end `-live`); step 6 needs live Auto Advance, so it runs live only.
import XCTest

final class LibraryFiltersJourneyTests: XCTestCase {
    /// J13: the bar narrows the grid, says "N of M" and keeps its filter across collections.
    @MainActor func testFilterByFlagAndRating() throws {
        walk(Journey("Library", self, arguments: ["-LibraryFixture", "shoot"]), live: false)

        let folder = try LibraryFiles.freshPhotoFolder()
        let catalog = try LibraryFiles.freshCatalogDir()
        addTeardownBlock { for url in [folder, catalog] { try? FileManager.default.removeItem(at: url) } }
        try LibraryFiles.writeShoot(in: folder)
        walk(Journey("Library", self, arguments: [
            "-LibraryImportFolder", folder.path, "-LibraryCatalogDir", catalog.path, "-LibraryImportOnLaunch",
        ]), live: true)
    }

    @MainActor private func walk(_ library: Journey, live: Bool) {
        let suffix = live ? "-live" : ""
        // Step 1: name order; cull IMG_0001 to IMG_0006 in the loupe with Auto Advance.
        XCTAssert(library.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        expectValue("All photos; 24 of 24", library, timeout: 60)
        menu("View", "Sort By", "Name", library: library)
        cells("IMG_0001", library).firstMatch.doubleClick()
        XCTAssert(library.element("library.loupe").waitForExistence(timeout: 10), "double-click opened no loupe")
        for key in ["5", "3", "p", "x", "3", "p"] { library.press(character: key) }
        library.press(.escape)
        expectValue("All photos; 24 of 24", library)

        // Step 2: Hide Rejected.
        click("library.filter.hideRejected", library)
        library.shot("filter-no-rejects\(suffix)")
        expectValue("Rejects hidden; 23 of 24", library)
        XCTAssertFalse(cells("IMG_0004", library).firstMatch.exists, "Hide Rejected left IMG_0004's cell")

        // Steps 3-4: the rating menu.
        chooseRating("At Least 3 Stars", library)
        library.shot("filter-rating\(suffix)")
        expectValue("At least 3 stars, Rejects hidden; 3 of 24", library)
        expectCells(["IMG_0001", "IMG_0002", "IMG_0005"], library)
        chooseRating("Exactly 3 Stars", library)
        expectCells(["IMG_0002", "IMG_0005"], library)

        // Step 5: Any Rating, then Picked.
        chooseRating("Any Rating", library)
        click("library.filter.flag.pick", library)
        expectValue("Picked, Rejects hidden; 2 of 24", library)
        expectCells(["IMG_0003", "IMG_0006"], library)

        // Step 6 (live): unflag both picks from the loupe; the grid says why it is empty.
        if live {
            cells("IMG_0003", library).firstMatch.doubleClick()
            library.press(character: "u")
            let position = library.element("library.loupe.position")
            let moved = NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", "IMG_0006", "IMG_0006")
            XCTAssert(position.waitForExistence(timeout: 5) && moved.evaluate(with: position), "U didn't advance")
            library.press(character: "u")
            library.shot("filter-empty")
            let empty = library.app.staticTexts["No Matching Photos"].firstMatch
            XCTAssert(empty.waitForExistence(timeout: 10), "no No Matching Photos")
            XCTAssert(library.element("library.filter.empty.clear").exists, "the empty grid has no Clear Filter")
            for _ in 0..<2 { menu("Edit", "Undo Clear Flag", library: library) }
            expectCells(["IMG_0003", "IMG_0006"], library)
        }

        // Step 7: Favorites keeps the filter.
        clickSidebar("Favorites", library)
        expectValue("Picked, Rejects hidden; 2 of 2", library)

        // Step 8: View > Filter > Clear Filter; All Photos; View > Filter > Hide Rejected.
        menu("View", "Filter", "Clear Filter", library: library)
        clickSidebar("All Photos", library)
        expectValue("All photos; 24 of 24", library)
        menu("View", "Filter", "Hide Rejected", library: library)
        expectValue("Rejects hidden; 23 of 24", library)
        library.app.terminate()
    }

    /// Chooses the menu bar item at `path`, such as View > Sort By > Name.
    @MainActor private func menu(_ path: String..., library: Journey) {
        guard let top = path.first else { return }
        var item = library.app.menuBars.firstMatch.menuBarItems[top]
        item.click()
        for (index, title) in path.enumerated().dropFirst() {
            item = item.menuItems[title]
            XCTAssert(item.waitForExistence(timeout: 3), "no \(path.prefix(index + 1).joined(separator: " > "))")
            XCTAssert(item.isEnabled, "\(path.joined(separator: " > ")) is disabled")
            if index < path.count - 1 { item.hover() } else { item.click() }
        }
    }

    @MainActor private func click(_ identifier: String, _ library: Journey) {
        let control = library.element(identifier)
        XCTAssert(control.waitForExistence(timeout: 5), "no \(identifier)")
        XCTAssert(control.isEnabled, "\(identifier) is disabled")
        control.click()
    }

    @MainActor private func chooseRating(_ title: String, _ library: Journey) {
        click("library.filter.rating", library)
        let item = library.app.menuItems[title].firstMatch
        XCTAssert(item.waitForExistence(timeout: 3), "the rating menu has no \(title)")
        item.click()
    }

    @MainActor private func expectValue(_ expected: String, _ library: Journey, timeout: TimeInterval = 5) {
        let bar = library.element("library.filter")
        let reads = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", expected), object: bar)
        XCTAssertEqual(XCTWaiter.wait(for: [reads], timeout: timeout), .completed, "the filter bar isn't \(expected)")
    }

    @MainActor private func cells(_ name: String, _ library: Journey) -> XCUIElementQuery {
        library.app.splitGroups.descendants(matching: .button).matching(NSPredicate(format: "label CONTAINS %@", name))
    }

    @MainActor private func expectCells(_ names: [String], _ library: Journey) {
        for name in names { XCTAssert(cells(name, library).firstMatch.waitForExistence(timeout: 5), "no \(name)") }
        XCTAssertEqual(cells("IMG_", library).count, names.count, "the grid doesn't show just \(names)")
    }

    @MainActor private func clickSidebar(_ title: String, _ library: Journey) {
        let row = library.element("suite.sidebar").descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@ OR value == %@", title, title)).firstMatch
        XCTAssert(row.waitForExistence(timeout: 10), "the sidebar has no \(title) row")
        row.click()
    }
}
