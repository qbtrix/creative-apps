// LibraryJourneyTests+Smart.swift: J15, a smart collection from the filter
// (docs/blueprints/library/features/filters-collections.md), on `shoot`'s
// fakes. Written before its code (contract rule 13, FC-11): each step starts
// with `try pending()`, skipping with "waits on FC-12"; FC-12 drops the calls.
import XCTest

final class LibrarySmartJourneyTests: XCTestCase {
    static let fake = ["-LibraryFixture", "shoot"]
    static let smartName = "At least 4 stars"
    private var library: Journey?
    private var skipped: [String] = []

    /// J15: New Smart Collection from Filter, its count following a rating,
    /// the bar editing its rules as one undo step, and its empty state.
    @MainActor func testSmartCollectionFromFilter() throws {
        skipped = []
        try step("1") { try self.rateThree() }
        try step("2") { try self.newSmartCollection() }
        try step("3") { try self.ratingChangesTheCount() }
        try step("4") { try self.editRules() }
        try step("5") { try self.undoEdit() }
        try step("6") { try self.emptyRules() }
        library?.app.terminate()
        if !skipped.isEmpty { throw XCTSkip(skipped.joined(separator: "; ")) }
    }

    /// Runs `body`; a skip it throws is noted with `name` and the walk goes on.
    @MainActor private func step(_ name: String, _ body: () throws -> Void) throws {
        do { try body() } catch let skip as XCTSkip {
            skipped.append("step \(name): \(skip.message ?? "skipped")")
        }
    }

    /// The task that enables the steps; FC-12 removes every call.
    private func pending() throws { throw XCTSkip("waits on FC-12") }

    /// The journey launched in step 1, or a skip when it never launched.
    @MainActor private func launched() throws -> Journey {
        guard let library else { throw XCTSkip("step 1 didn't launch") }
        return library
    }

    /// Step 1: by name, IMG_0001 in the loupe, 5, 4 and 2 down the shoot, Escape.
    @MainActor private func rateThree() throws {
        try pending()
        let library = Journey("Library", self, arguments: Self.fake)
        self.library = library
        sortByName(library)
        let first = cell("IMG_0001", library)
        XCTAssert(first.waitForExistence(timeout: 10), "no grid cell for IMG_0001")
        first.doubleClick()
        XCTAssert(library.element("library.loupe").waitForExistence(timeout: 10), "double-click didn't open the loupe")
        for stars in ["5", "4", "2"] { library.press(character: stars) }
        library.press(.escape)
        XCTAssert(cell("IMG_0024", library).waitForExistence(timeout: 10), "Escape didn't return to the grid")
    }

    /// Step 2: Rating > At Least 4 Stars, then File > New Smart Collection from Filter.
    @MainActor private func newSmartCollection() throws {
        try pending()
        let library = try launched()
        chooseRating("At Least 4 Stars", library)
        library.press(character: "n", [.command, .option])
        library.shot("smart-new")
        expectSidebarCount(Self.smartName, 2, library)
        let bar = library.element("library.filter")
        XCTAssert(bar.waitForExistence(timeout: 5), "no filter bar (library.filter)")
        let value = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "At least 4 stars; 2 of 24"), object: bar)
        XCTAssertEqual(XCTWaiter().wait(for: [value], timeout: 5), .completed, "the bar reads \(bar.value ?? "")")
        XCTAssert(bar.staticTexts["Rules of \(Self.smartName)"].exists, "the bar has no caption Rules of \(Self.smartName)")
        expectUndo("Undo New Smart Collection", library)
    }

    /// Step 3: All Photos, Clear Filter, IMG_0003 at 5 stars: the smart row counts 3.
    @MainActor private func ratingChangesTheCount() throws {
        try pending()
        let library = try launched()
        sidebarRow("All Photos", library).click()
        viewMenu("Filter", "Clear Filter", library)
        let third = cell("IMG_0003", library)
        XCTAssert(third.waitForExistence(timeout: 10), "no grid cell for IMG_0003 after Clear Filter")
        third.click()
        library.press(character: "5")
        expectSidebarCount(Self.smartName, 3, library)
    }

    /// Step 4: the smart row, Rating > Exactly 5 Stars: IMG_0001 and IMG_0003, one Edit Rules step.
    @MainActor private func editRules() throws {
        try pending()
        let library = try launched()
        sidebarRow(Self.smartName, library).click()
        XCTAssert(cell("IMG_0002", library).waitForExistence(timeout: 10), "the smart collection doesn't show IMG_0002")
        chooseRating("Exactly 5 Stars", library)
        XCTAssert(cell("IMG_0002", library).waitForNonExistence(timeout: 5), "Exactly 5 Stars still shows IMG_0002")
        XCTAssert(cell("IMG_0001", library).exists && cell("IMG_0003", library).exists, "5-star photos missing")
        expectSidebarCount(Self.smartName, 2, library)
        expectUndo("Undo Edit Rules", library)
    }

    /// Step 5: Undo: the rules go back and three cells show again.
    @MainActor private func undoEdit() throws {
        try pending()
        let library = try launched()
        library.press(character: "z", .command)
        XCTAssert(cell("IMG_0002", library).waitForExistence(timeout: 10), "Undo didn't bring IMG_0002 back")
        expectSidebarCount(Self.smartName, 3, library)
    }

    /// Step 6: Rating > Exactly 1 Star: the smart empty state with Show All Photos.
    @MainActor private func emptyRules() throws {
        try pending()
        let library = try launched()
        chooseRating("Exactly 1 Star", library)
        let message = "Photos that match this collection's rules appear here. Change the rules in the filter bar."
        XCTAssert(library.app.staticTexts["No Photos in \(Self.smartName)"].waitForExistence(timeout: 10),
                  "no empty state titled No Photos in \(Self.smartName)")
        XCTAssert(library.app.staticTexts[message].exists, "the empty state doesn't explain the rules")
        XCTAssert(library.app.buttons["Show All Photos"].exists, "the empty state has no Show All Photos")
        library.shot("smart-empty")
    }

    /// The bar's rating menu (`library.filter.rating`), choosing `title`.
    @MainActor private func chooseRating(_ title: String, _ library: Journey) {
        let rating = library.element("library.filter.rating")
        XCTAssert(rating.waitForExistence(timeout: 5), "no rating menu (library.filter.rating)")
        rating.click()
        let item = library.app.menuItems[title]
        XCTAssert(item.waitForExistence(timeout: 3), "the rating menu has no \(title)")
        item.click()
    }

    /// Opens Edit, checks its Undo reads `title`, and closes the menu.
    @MainActor private func expectUndo(_ title: String, _ library: Journey) {
        let edit = library.app.menuBars.firstMatch.menuBarItems["Edit"]
        edit.click()
        let item = edit.menuItems.matching(NSPredicate(format: "title BEGINSWITH %@", "Undo")).firstMatch
        XCTAssert(item.waitForExistence(timeout: 3), "the Edit menu has no Undo")
        XCTAssertEqual(item.title, title, "Edit's Undo item")
        library.press(.escape)
    }

    /// The sidebar row titled `title`.
    @MainActor private func sidebarRow(_ title: String, _ library: Journey) -> XCUIElement {
        let rowTypes = [XCUIElement.ElementType.tableRow, .outlineRow, .cell].map { NSNumber(value: $0.rawValue) }
        let row = library.element("suite.sidebar").descendants(matching: .any)
            .matching(NSPredicate(format: "elementType IN %@", rowTypes))
            .containing(NSPredicate(format: "label == %@ OR value == %@", title, title)).firstMatch
        XCTAssert(row.waitForExistence(timeout: 10), "the sidebar has no \(title) row")
        return row
    }

    /// The sidebar row `title` shows the badge `count`.
    @MainActor private func expectSidebarCount(_ title: String, _ count: Int, _ library: Journey) {
        let badge = sidebarRow(title, library).descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@ OR value == %@", "\(count)", "\(count)")).firstMatch
        XCTAssert(badge.waitForExistence(timeout: 10), "\(title) doesn't count \(count)")
    }

    /// Waits for the window and IMG_0024's cell, then View > Sort By > Name.
    @MainActor private func sortByName(_ library: Journey) {
        XCTAssert(library.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        XCTAssert(cell("IMG_0024", library).waitForExistence(timeout: 60), "no grid cell for IMG_0024")
        viewMenu("Sort By", "Name", library)
    }

    /// View > `submenu` > `item`.
    @MainActor private func viewMenu(_ submenu: String, _ item: String, _ library: Journey) {
        let view = library.app.menuBars.firstMatch.menuBarItems["View"]
        view.click()
        let sub = view.menuItems[submenu]
        XCTAssert(sub.waitForExistence(timeout: 3), "the View menu has no \(submenu)")
        sub.hover()
        let choice = sub.menuItems[item]
        XCTAssert(choice.waitForExistence(timeout: 3), "View > \(submenu) has no \(item)")
        choice.click()
    }

    /// The grid cell `library.grid.cell.<id>` whose photo id names `name`.
    @MainActor private func cell(_ name: String, _ library: Journey) -> XCUIElement {
        library.app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND identifier CONTAINS %@", "library.grid.cell.", name)).firstMatch
    }
}
