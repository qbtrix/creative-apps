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

    @MainActor func testEveryMenuOpens() {
        let library = Journey("Library", self, arguments: ["-LibraryFixture", "samples"])
        library.openEachMenu()
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

    /// The grid's first sample photo. A cell's label leads with its badges
    /// ("2 stars, Purple, IMG_0034"), so match the file name anywhere in a
    /// grid button's label.
    @MainActor private func samplePhoto(in library: Journey) -> XCUIElement {
        library.app.splitGroups.descendants(matching: .button)
            .matching(NSPredicate(format: "label CONTAINS %@", "IMG_")).firstMatch
    }
}
