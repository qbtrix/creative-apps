// LibraryJourneyTests.swift: Library driven like a person would, with a
// whole-window screenshot after every step (see Journey.swift). Each test is
// one journey; grow them as Library's features land, and replace the skipped
// test with the real journey when its issue is built.
import XCTest

final class LibraryJourneyTests: XCTestCase {
    @MainActor func testLaunchShowsWindowShell() {
        Journey("Library", self).expectWindowShell()
    }

    @MainActor func testLoadSamplePhotos() {
        let library = Journey("Library", self)
        library.click("Load Sample Photos", step: "sample-photos")
    }

    @MainActor func testEveryMenuOpens() {
        let library = Journey("Library", self)
        library.click("Load Sample Photos")
        library.openEachMenu()
    }

    @MainActor func testLoupeStepsAndReturnsToTheGrid() {
        let library = Journey("Library", self)
        library.click("Load Sample Photos")
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
        let library = Journey("Library", self)
        library.click("Load Sample Photos")
        // A cell's label leads with its badges ("2 stars, Purple, IMG_0034"), so
        // match the file name anywhere in a grid button's label.
        let photo = library.app.splitGroups.descendants(matching: .button)
            .matching(NSPredicate(format: "label CONTAINS %@", "IMG_")).firstMatch
        XCTAssert(photo.waitForExistence(timeout: 10), "no sample photo in the grid")
        photo.click()
        library.shot("photo-inspector")
        library.click("4 Stars", in: .window, step: "photo-rated")
    }

    @MainActor func testImportRateAndRelaunch() throws {
        throw XCTSkip("journey arrives with #210 (import), #211 (rate) and #212 (relaunch)")
    }
}
