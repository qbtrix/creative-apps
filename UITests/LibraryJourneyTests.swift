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

    /// J10: every menu opens, and each app menu holds Library's items from
    /// blueprint 6.2 (by title prefix: titles change with the mode).
    @MainActor func testEveryMenuOpens() {
        let library = Journey("Library", self, arguments: ["-LibraryFixture", "samples"])
        library.openEachMenu()
        let bar = library.app.menuBars.firstMatch.menuBarItems
        // Index 0 is the Apple menu; index 1 is the app's own menu, whatever its name.
        XCTAssert(bar.element(boundBy: 1).waitForExistence(timeout: 5), "no app menu")
        expect(bar.element(boundBy: 1), holds: [["About"], ["Hide"], ["Quit"]], library)
        for (title, items) in Self.menus {
            let menu = bar[title]
            XCTAssert(menu.waitForExistence(timeout: 5), "no \(title) menu")
            expect(menu, holds: items, library)
        }
    }

    @MainActor func testLoupeStepsAndReturnsToTheGrid() {
        let library = Journey("Library", self, arguments: ["-LibraryFixture", "samples"])
        let view = library.app.menuBars.firstMatch.menuBarItems["View"]
        view.click()
        view.menuItems["Loupe"].click()
        XCTAssert(library.app.descendants(matching: .any)["library.loupe"].waitForExistence(timeout: 10), "no loupe")
        library.shot("loupe")
        library.app.typeKey(.rightArrow, modifierFlags: [])
        library.shot("loupe-next")
        library.app.typeKey(.escape, modifierFlags: [])
        library.shot("loupe-back-to-grid")
    }

    /// Selecting a photo swaps the collection card for its metadata inspector;
    /// a star rates it.
    @MainActor func testRateASelectedPhoto() {
        let library = Journey("Library", self, arguments: ["-LibraryFixture", "samples"])
        let photo = samplePhoto(in: library)
        XCTAssert(photo.waitForExistence(timeout: 10), "no sample photo in the grid")
        photo.click()
        library.shot("photo-inspector")
        library.click("4 Stars", in: .window, step: "photo-rated")
    }

    @MainActor func testImportRateAndRelaunch() throws {
        throw XCTSkip("journey arrives with #210 (import), #211 (rate) and #212 (relaunch)")
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
            ["Zoom to Fit"], ["Actual Size"], ["Sort By"],
        ]),
        ("Photo", [["Copy Settings"], ["Paste Settings"], ["Reset Develop"], ["Crop", "Done Cropping"], ["Reset Crop"]]),
        ("Metadata", [["Set Rating"], ["Set Flag"], ["Set Label"], ["Auto Advance"]]),
    ]

    /// Opens `menu` and checks each of `items` has a top-level item whose
    /// title starts with one of its prefixes; closes it again.
    @MainActor private func expect(_ menu: XCUIElement, holds items: [[String]], _ library: Journey) {
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
    }

    /// The grid's first sample photo. A cell's label leads with its badges
    /// ("2 stars, Purple, IMG_0034"), so match the file name anywhere in a
    /// grid button's label.
    @MainActor private func samplePhoto(in library: Journey) -> XCUIElement {
        library.app.splitGroups.descendants(matching: .button)
            .matching(NSPredicate(format: "label CONTAINS %@", "IMG_")).firstMatch
    }
}
