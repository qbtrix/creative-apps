// LibraryJourneyTests+Large.swift: LJ-LG, Library at 10,000 photos (packet
// docs/blueprints/library/features/large-catalog.md, Journey steps), on the
// `-LibraryLargeFixture 10000` fakes, whose photo ids are their names
// (IMG_00001 ... IMG_10000), so cells are `library.grid.cell.IMG_00001`.
// Written with the window budgets before the grid and loupe fixes: it skips
// "LG-grid" until LG-5 and LG-6 drop the skip and the steps judge the budgets
// (first paint 1.5 s, scroll p95 16 ms, loupe step p95 50 ms).
import Foundation
import XCTest

final class LibraryLargeCatalogJourneyTests: XCTestCase {
    static let large = ["-LibraryLargeFixture", "10000"]

    /// LJ-LG: launch on 10,000 photos, the grid paints within 1.5 s, scroll
    /// 120 rows, select all, shift-click a range, open the loupe and step 20 times.
    @MainActor func testTenThousandPhotos() throws {
        throw XCTSkip("LG-grid: the grid and loupe budgets on 10,000 photos wait on LG-5 and LG-6")
        let started = ProcessInfo.processInfo.systemUptime
        let library = Journey("Library", self, arguments: Self.large)
        let first = cell("IMG_00001", library)
        XCTAssert(first.waitForExistence(timeout: 10), "no grid cell for IMG_00001")
        let paintMs = (ProcessInfo.processInfo.systemUptime - started) * 1000
        XCTAssertLessThanOrEqual(paintMs, 1_500, "the first grid paint took \(Int(paintMs)) ms, over 1.5 s")
        library.shot("large-grid")

        // Scroll 120 rows down and back, a row at a time.
        let grid = library.app.scrollViews.firstMatch
        XCTAssert(grid.exists, "no scrolling grid")
        let row = max(first.frame.height, 1)
        for _ in 0..<120 { grid.scroll(byDeltaX: 0, deltaY: -row) }
        XCTAssertFalse(first.isHittable, "120 rows down, the first photo is still on screen")
        library.shot("large-scrolled")
        for _ in 0..<120 { grid.scroll(byDeltaX: 0, deltaY: row) }
        XCTAssert(first.waitForExistence(timeout: 5) && first.isHittable, "back at the top, no IMG_00001")

        // Select all, then a range by shift-click.
        library.press(character: "a", .command, step: "large-select-all")
        first.click()
        let tenth = cell("IMG_00010", library)
        XCTAssert(tenth.waitForExistence(timeout: 5), "no grid cell for IMG_00010")
        XCUIElement.perform(withKeyModifiers: .shift) { tenth.click() }
        library.shot("large-range")

        // Open the loupe on IMG_00001 and step 20 photos.
        first.doubleClick()
        let position = library.element("library.loupe.position")
        XCTAssert(position.waitForExistence(timeout: 5), "the loupe didn't open")
        for _ in 0..<20 { library.press(.rightArrow) }
        let readout = (position.value as? String) ?? position.label
        XCTAssert(readout.contains("IMG_00021") && readout.contains("21 of 10"),
                  "after 20 steps the loupe reads \(readout)")
        library.shot("large-loupe")
        library.app.terminate()
    }

    /// The grid cell for the photo whose id is `id`.
    @MainActor private func cell(_ id: String, _ library: Journey) -> XCUIElement {
        library.app.descendants(matching: .any)["library.grid.cell.\(id)"].firstMatch
    }
}
