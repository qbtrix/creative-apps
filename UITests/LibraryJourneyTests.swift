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

    @MainActor func testImportRateAndFilter() throws {
        throw XCTSkip("journey arrives with its line:library issue")
    }
}
