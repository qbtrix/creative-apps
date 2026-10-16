// LibraryJourneyTests.swift: Library driven like a person would, with a
// whole-window screenshot after every step (see Journey.swift). Each test is
// one journey; grow them as Library's features land, and replace the skipped
// test with the real journey when its issue is built.
import XCTest

final class LibraryJourneyTests: XCTestCase {
    @MainActor func testLaunchShowsWindowShell() {
        Journey("Library", self).expectWindowShell()
    }

    /// File > Load Sample Photos fills an empty catalog's grid.
    @MainActor func testLoadSamplePhotos() {
        let library = Journey("Library", self, arguments: ["-LibraryFixture", "empty"])
        XCTAssert(library.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        let file = library.app.menuBars.firstMatch.menuBarItems["File"]
        file.click()
        file.menuItems["Load Sample Photos"].click()
        XCTAssert(samplePhoto(in: library).waitForExistence(timeout: 10), "no sample photo in the grid")
        library.shot("sample-photos")
    }

    /// J10: every menu opens, and each app menu holds exactly Library's items
    /// from blueprint 6.2 (by title prefix: titles change with the mode) plus
    /// the system's own; the app menu has no Settings (none in v1).
    @MainActor func testEveryMenuOpens() {
        let library = Journey("Library", self, arguments: ["-LibraryFixture", "samples"])
        library.openEachMenu()
        let bar = library.app.menuBars.firstMatch.menuBarItems
        // Index 0 is the Apple menu; index 1 is the app's own menu, whatever its name.
        XCTAssert(bar.element(boundBy: 1).waitForExistence(timeout: 5), "no app menu")
        let appTitles = expect(bar.element(boundBy: 1), holds: [["About"], ["Hide"], ["Quit"]], exactly: false, library)
        XCTAssertFalse(
            appTitles.contains { $0.hasPrefix("Settings") || $0.hasPrefix("Preferences") },
            "the app menu has a Settings item: \(appTitles)")
        for (title, items) in Self.menus {
            let menu = bar[title]
            XCTAssert(menu.waitForExistence(timeout: 5), "no \(title) menu")
            expect(menu, holds: items, exactly: true, library)
        }
    }

    /// Metadata's Set Rating, Set Flag and Set Label need a selection, and
    /// View > Sort By needs photos: each is disabled until it can act.
    @MainActor func testMetadataAndSortWaitForPhotos() {
        let empty = Journey("Library", self, arguments: ["-LibraryFixture", "empty"])
        XCTAssert(empty.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        expectSortBy(enabled: false, empty)
        expectCulling(enabled: false, empty)
        empty.app.terminate()

        let library = Journey("Library", self, arguments: ["-LibraryFixture", "samples"])
        let photo = samplePhoto(in: library)
        XCTAssert(photo.waitForExistence(timeout: 10), "no sample photo in the grid")
        expectSortBy(enabled: true, library)
        let edit = library.app.menuBars.firstMatch.menuBarItems["Edit"]
        edit.click()
        let deselect = edit.menuItems["Deselect"]
        if deselect.waitForExistence(timeout: 3), deselect.isEnabled { deselect.click() } else { library.press(.escape) }
        expectCulling(enabled: false, library)
        photo.click()
        expectCulling(enabled: true, library)
    }

    @MainActor func testLoupeStepsAndReturnsToTheGrid() {
        let library = Journey("Library", self, arguments: ["-LibraryFixture", "samples"])
        let view = library.app.menuBars.firstMatch.menuBarItems["View"]
        view.click()
        view.menuItems["Loupe"].click()
        let loupe = library.app.descendants(matching: .any)["library.loupe"]
        XCTAssert(loupe.waitForExistence(timeout: 10), "no loupe")
        let position = library.element("library.loupe.position")
        XCTAssert(position.waitForExistence(timeout: 5), "no loupe position (library.loupe.position)")
        let start = Self.text(of: position)
        XCTAssert(start.contains(" of "), "the loupe position reads \(start), not \"<name>  ·  n of m\"")
        library.shot("loupe")
        // The loupe's keys act while it has focus; a menu click may leave focus
        // elsewhere, so click the photo first, as a person would.
        let photo = library.element("library.loupe.photo")
        if photo.waitForExistence(timeout: 3) { photo.click() } else { loupe.click() }
        library.app.typeKey(.rightArrow, modifierFlags: [])
        var now = start
        for _ in 0..<25 where now == start {
            Thread.sleep(forTimeInterval: 0.2)
            now = Self.text(of: position)
        }
        XCTAssert(now != start, "Right didn't step the loupe from \(start)")
        let name = Self.photoName(in: now)
        library.shot("loupe-next")
        library.app.typeKey(.escape, modifierFlags: [])
        XCTAssert(loupe.waitForNonExistence(timeout: 5), "Escape left it still in the loupe")
        let cell = gridCell(named: name, in: library)
        XCTAssert(cell.waitForExistence(timeout: 5), "no grid cell for \(name) after Escape")
        XCTAssert(cell.isSelected, "the grid came back without \(name), the loupe's photo, selected")
        library.shot("loupe-back-to-grid")
        // Someone who doesn't know Escape clicks the loupe's Grid button instead.
        view.click()
        view.menuItems["Loupe"].click()
        XCTAssert(loupe.waitForExistence(timeout: 10), "View > Loupe didn't reopen the loupe")
        let gridButton = library.element("library.loupe.grid")
        XCTAssert(gridButton.waitForExistence(timeout: 5), "the loupe shows no Grid button (library.loupe.grid)")
        gridButton.click()
        XCTAssert(loupe.waitForNonExistence(timeout: 5), "the Grid button left it still in the loupe")
        XCTAssert(gridCell(named: name, in: library).waitForExistence(timeout: 5), "no grid after the Grid button")
        library.shot("loupe-grid-button")
    }

    /// Selecting a photo swaps the collection card for its metadata inspector;
    /// a star rates it.
    @MainActor func testRateASelectedPhoto() {
        let library = Journey("Library", self, arguments: ["-LibraryFixture", "samples"])
        let photo = samplePhoto(in: library)
        XCTAssert(photo.waitForExistence(timeout: 10), "no sample photo in the grid")
        let name = Self.photoName(in: photo.label)
        photo.click()
        library.shot("photo-inspector")
        library.click("4 Stars", in: .window, step: "photo-rated")
        let rated = library.app.splitGroups.descendants(matching: .button).matching(NSPredicate(
            format: "label CONTAINS %@ AND label CONTAINS %@", name, "4 stars")).firstMatch
        XCTAssert(rated.waitForExistence(timeout: 5), "no 4 stars on \(name)'s grid cell")
    }

    // MARK: - Menus

    /// Library's items in each menu (blueprint 6.2), top level, each by the
    /// title prefixes it may show: Undo and Redo carry a step name, Zoom In
    /// and Zoom Out read Larger and Smaller Thumbnails in the grid, and Crop
    /// reads Done Cropping while cropping. Close is the system's.
    private static let menus: [(String, [[String]])] = [
        ("File", [["Import Folder…"], ["Load Sample Photos"], ["Export…"]]),
        ("Edit", [["Undo"], ["Redo"], ["Select All"], ["Deselect"]]),
        ("View", [
            ["Grid"], ["Loupe"], ["Zoom In", "Larger Thumbnails"], ["Zoom Out", "Smaller Thumbnails"],
            ["Zoom to Fit"], ["Actual Size"], ["Sort By"], ["Show Inspector", "Hide Inspector"],
        ]),
        ("Photo", [["Copy Settings"], ["Paste Settings"], ["Reset Develop"], ["Crop", "Done Cropping"], ["Reset Crop"]]),
        ("Metadata", [["Set Rating"], ["Set Flag"], ["Set Label"], ["Auto Advance"]]),
    ]

    /// Items macOS adds to File, Edit and View on its own; `expect` lets
    /// them sit beside Library's.
    private static let systemItems: Set<String> = [
        "Close", "Close All", "Close Window", "Page Setup…", "Print…",
        "Find", "Spelling and Grammar", "Substitutions", "Transformations", "Speech",
        "Start Dictation…", "Start Dictation", "Emoji & Symbols", "AutoFill", "Writing Tools",
        "Show Toolbar", "Hide Toolbar", "Customize Toolbar…", "Show Sidebar", "Hide Sidebar",
        "Enter Full Screen", "Exit Full Screen", "Show Tab Bar", "Hide Tab Bar", "Show All Tabs",
    ]

    /// Opens `menu` and checks each of `items` has a top-level item whose
    /// title starts with one of its prefixes and, `exactly`, that every other
    /// item is the system's; closes it again. Returns the titles it read.
    @discardableResult
    @MainActor private func expect(
        _ menu: XCUIElement, holds items: [[String]], exactly: Bool, _ library: Journey
    ) -> [String] {
        let name = menu.title
        menu.click()
        let children = menu.menus.firstMatch.children(matching: .menuItem)
        _ = children.firstMatch.waitForExistence(timeout: 3)
        let titles = children.allElementsBoundByIndex.map(\.title).filter { !$0.isEmpty }
        library.press(.escape)
        for prefixes in items {
            XCTAssert(
                titles.contains { title in prefixes.contains { title.hasPrefix($0) } },
                "the \(name) menu has no \(prefixes.joined(separator: " or ")): \(titles)")
        }
        if exactly {
            let extra = titles.filter { title in
                !Self.systemItems.contains(title) && !items.contains { $0.contains { title.hasPrefix($0) } }
            }
            XCTAssert(extra.isEmpty, "the \(name) menu has items outside blueprint 6.2: \(extra)")
        }
        return titles
    }

    /// Opens View > Sort By and checks each sort item's enabled state (a
    /// submenu's parent item may stay enabled while all its items are off);
    /// closes the menu again.
    @MainActor private func expectSortBy(enabled: Bool, _ library: Journey) {
        let view = library.app.menuBars.firstMatch.menuBarItems["View"]
        view.click()
        let sort = view.menuItems["Sort By"]
        XCTAssert(sort.waitForExistence(timeout: 3), "the View menu has no Sort By")
        if enabled { XCTAssert(sort.isEnabled, "View > Sort By is disabled with photos") }
        if sort.isEnabled {
            sort.hover()
            let items = sort.menus.firstMatch.children(matching: .menuItem)
            XCTAssert(items.firstMatch.waitForExistence(timeout: 3), "View > Sort By has no items")
            for item in items.allElementsBoundByIndex where !item.title.isEmpty {
                XCTAssertEqual(item.isEnabled, enabled, "View > Sort By > \(item.title) enabled")
            }
            library.press(.escape)
        }
        library.press(.escape)
        _ = library.app.menus.firstMatch.waitForNonExistence(timeout: 2)
    }

    /// Opens each of Metadata's Set Rating, Set Flag and Set Label and checks
    /// one item in each is `enabled`; closes the menu again.
    @MainActor private func expectCulling(enabled: Bool, _ library: Journey) {
        for (submenu, item) in [("Set Rating", "3 Stars"), ("Set Flag", "Pick"), ("Set Label", "Red")] {
            let metadata = library.app.menuBars.firstMatch.menuBarItems["Metadata"]
            metadata.click()
            let parent = metadata.menuItems[submenu]
            XCTAssert(parent.waitForExistence(timeout: 3), "the Metadata menu has no \(submenu)")
            parent.hover()
            let child = parent.menuItems[item]
            XCTAssert(child.waitForExistence(timeout: 3), "Metadata > \(submenu) has no \(item)")
            XCTAssertEqual(child.isEnabled, enabled, "Metadata > \(submenu) > \(item) enabled")
            library.press(.escape)
            library.press(.escape)
            _ = library.app.menus.firstMatch.waitForNonExistence(timeout: 2)
        }
    }

    /// What a plain SwiftUI Text reads: XCUITest gives it an empty label and
    /// its string as the value, so the label only when the value is empty.
    @MainActor private static func text(of element: XCUIElement) -> String {
        let value = (element.value as? String) ?? ""
        return value.isEmpty ? element.label : value
    }

    /// "IMG_0034" from a cell or loupe label that names it; "" when none does.
    private static func photoName(in label: String) -> String {
        label.range(of: "IMG_[0-9]+", options: .regularExpression).map { String(label[$0]) } ?? ""
    }

    /// The grid cell whose label names `name`.
    @MainActor private func gridCell(named name: String, in library: Journey) -> XCUIElement {
        library.app.splitGroups.descendants(matching: .button)
            .matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch
    }

    /// The grid's first sample photo. A cell's label leads with its badges
    /// ("2 stars, Purple, IMG_0034"), so match the file name anywhere in a
    /// grid button's label.
    @MainActor private func samplePhoto(in library: Journey) -> XCUIElement {
        library.app.splitGroups.descendants(matching: .button)
            .matching(NSPredicate(format: "label CONTAINS %@", "IMG_")).firstMatch
    }
}
