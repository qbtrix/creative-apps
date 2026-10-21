// LibraryJourneyTests+Collections.swift: J14, make a collection and edit it
// (packet docs/blueprints/library/features/filters-collections.md, Journey
// steps; slice FC-c), on the `shoot` fixture's fakes. Its own XCTestCase
// class. Written before its code (FC-8): FC-9 sets `waitsOn` to nil for
// steps 1-6; FC-10 sets `dropWaitsOn` to nil for step 7, the last step.
import XCTest

final class LibraryCollectionsJourneyTests: XCTestCase {
    private static let waitsOn: String? = "waits on FC-9"
    private static let dropWaitsOn: String? = "waits on FC-10"

    @MainActor func testMakeACollection() throws {
        if let reason = Self.waitsOn { throw XCTSkip(reason) }
        let library = Journey("Library", self, arguments: ["-LibraryFixture", "shoot"])
        XCTAssert(cell("IMG_0024", library).waitForExistence(timeout: 30), "no grid cell for IMG_0024")
        menu("View", "Sort By", "Name", in: library).click()

        // Step 1: none selected; New Collection is empty, selected, and one undo step.
        menu("Edit", "Deselect", in: library).click()
        library.press(character: "n", .command)
        expectRow("Untitled Collection", 0, library)
        library.shot("collection-empty")
        XCTAssert(library.app.staticTexts["No Photos in Untitled Collection"].waitForExistence(timeout: 5),
                  "no empty state for Untitled Collection")
        XCTAssert(library.app.buttons["Show All Photos"].exists, "the empty state has no Show All Photos")
        expectUndo("Undo New Collection", library, choose: true)
        XCTAssert(row("Untitled Collection", library).waitForNonExistence(timeout: 5), "undo left the new row")
        // Step 2: IMG_0001, Shift-click IMG_0003; New Collection holds the three.
        cell("IMG_0001", library).click()
        XCUIElement.perform(withKeyModifiers: .shift) { cell("IMG_0003", library).click() }
        library.press(character: "n", .command)
        expectRow("Untitled Collection", 3, library)
        XCTAssertEqual(cells(library).count, 3, "the new collection doesn't show three photos")
        // Step 3: rename it Keepers in place.
        row("Untitled Collection", library).doubleClick()
        library.app.typeText("Keepers\r")
        expectRow("Keepers", 3, library)
        expectUndo("Undo Rename Collection", library)
        // Step 4: All Photos; IMG_0010 into Keepers; then the item says why it can't.
        row("All Photos", library).click()
        cell("IMG_0010", library).click()
        menu("Photo", "Add to Collection", "Keepers", in: library).click()
        expectRow("Keepers", 4, library)
        expectUndo("Undo Add to Collection", library)
        let again = menu("Photo", "Add to Collection", "Keepers", in: library)
        XCTAssertFalse(again.isEnabled, "Add to Collection > Keepers is enabled with IMG_0010 in it")
        for _ in 0..<2 { library.press(.escape) }
        // Step 5: in Keepers, IMG_0002 out with ⌘⌫.
        row("Keepers", library).click()
        cell("IMG_0002", library).click()
        library.press(.delete, .command)
        expectRow("Keepers", 3, library)
        library.shot("collection-removed")
        expectRow("All Photos", 24, library)
        XCTAssertEqual(cells(library).count, 3, "Keepers doesn't show three photos")
        expectUndo("Undo Remove from Collection", library)
        // Step 6: File > Delete Collection keeps every photo; undo brings Keepers back.
        menu("File", "Delete Collection", in: library).click()
        XCTAssert(row("Keepers", library).waitForNonExistence(timeout: 5), "Keepers is still in the sidebar")
        expectRow("All Photos", 24, library)
        expectUndo("Undo Delete Collection", library, choose: true)
        expectRow("Keepers", 3, library)
        // Step 7: drag IMG_0020 and IMG_0021 from All Photos onto Keepers.
        if let reason = Self.dropWaitsOn { throw XCTSkip(reason) }
        row("All Photos", library).click()
        cell("IMG_0020", library).click()
        XCUIElement.perform(withKeyModifiers: .shift) { cell("IMG_0021", library).click() }
        cell("IMG_0021", library).press(forDuration: 0.5, thenDragTo: row("Keepers", library))
        library.shot("collection-dropped")
        expectRow("Keepers", 5, library)
        expectUndo("Undo Add to Collection", library, choose: true)
        expectRow("Keepers", 3, library)
        library.app.terminate()
    }

    /// The grid cell `library.grid.cell.<id>` whose id names `name`, and every grid cell.
    @MainActor private func cell(_ name: String, _ library: Journey) -> XCUIElement {
        cells(library).matching(NSPredicate(format: "identifier CONTAINS %@", name)).firstMatch
    }
    @MainActor private func cells(_ library: Journey) -> XCUIElementQuery {
        library.app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "library.grid.cell."))
    }
    /// The sidebar row titled `title`.
    @MainActor private func row(_ title: String, _ library: Journey) -> XCUIElement {
        let types = [XCUIElement.ElementType.tableRow, .outlineRow, .cell].map { NSNumber(value: $0.rawValue) }
        return library.element("suite.sidebar").descendants(matching: .any)
            .matching(NSPredicate(format: "elementType IN %@", types))
            .containing(NSPredicate(format: "label == %@ OR value == %@", title, title)).firstMatch
    }
    /// The sidebar row `title` exists and shows `count`.
    @MainActor private func expectRow(_ title: String, _ count: Int, _ library: Journey) {
        let found = row(title, library)
        XCTAssert(found.waitForExistence(timeout: 10), "the sidebar has no \(title) row")
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
    /// Opens Edit, checks its Undo item reads `title`, then chooses it or closes the menu.
    @MainActor private func expectUndo(_ title: String, _ library: Journey, choose: Bool = false) {
        let edit = library.app.menuBars.firstMatch.menuBarItems["Edit"]
        edit.click()
        let item = edit.menuItems.matching(NSPredicate(format: "title BEGINSWITH %@", "Undo")).firstMatch
        XCTAssert(item.waitForExistence(timeout: 3), "the Edit menu has no Undo")
        XCTAssertEqual(item.title, title, "Edit's Undo item")
        if choose { item.click() } else { library.press(.escape) }
    }
}
