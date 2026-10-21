// LibraryJourneyTests+FileFlow.swift: LFJ1 (packet
// docs/blueprints/library/features/file-flow.md, Journey steps; LF-6 written,
// LF-7 turned on live). On the `samples` fixture, File shows the suite's one
// Open Recent ▸ and an Open In ▸ that is off with its reason. The drop steps
// (a folder of three JPEGs imports as one undoable step, a dropped Intro.halo
// opens in Halo, a thumbnail dragged onto Photo is placed as a layer) need the
// live drop (file-flow SF-8) and a drop source; LF-7 adds them here.
import XCTest

final class LibraryFileFlowJourneyTests: XCTestCase {
    @MainActor func testDropToImportAndDragOut() throws {
        try XCTSkipIf(true, "waits on LF-7")
        // Step 1: launch Library with the sample catalog.
        let library = Journey("Library", self, arguments: ["-LibraryFixture", "samples"])
        XCTAssert(library.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")

        // File has exactly one Open Recent ▸ (the suite's) and an Open In ▸ that is off.
        let file = library.app.menuBars.firstMatch.menuBarItems["File"]
        file.click()
        let recent = file.menuItems["Open Recent"]
        XCTAssert(recent.waitForExistence(timeout: 5), "File has no Open Recent")
        XCTAssertEqual(file.menuItems.matching(NSPredicate(format: "title == %@", "Open Recent")).count, 1,
                       "File shows more than one Open Recent")
        let openIn = file.menuItems["Open In"]
        XCTAssert(openIn.waitForExistence(timeout: 5), "File has no Open In")
        XCTAssertFalse(openIn.isEnabled, "Open In is on with no document handed to it")
        recent.hover()
        library.shot("open-recent", screen: true)
        library.press(.escape)
        library.press(.escape)
    }
}
