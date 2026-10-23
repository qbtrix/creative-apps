// LibraryJourneyTests+Search.swift: MD-J4 (metadata-more), search by keyword and camera.
// Steps 1-6 on the `cameras` fixture. Written first (MD-19): skips until MD-22.
import Foundation
import XCTest

final class LibrarySearchJourneyTests: XCTestCase {
    private var library: Journey!  // set by step 1; a later step skips before it reads it
    private var skipped: [String] = []

    @MainActor func testSearchByKeywordAndCamera() throws {
        try step("1") { try self.focus() }
        try step("2") { try self.lens() }
        try step("3") { try self.isoAndKeyword() }
        try step("4") { try self.clear() }
        try step("5") { try self.fromDetail() }
        try step("6") { try self.hidesLoupe() }
        if !skipped.isEmpty { throw XCTSkip(skipped.joined(separator: "; ")) }
    }
    @MainActor private func step(_ name: String, _ body: () throws -> Void) throws {
        do { try body() } catch let skip as XCTSkip { skipped.append("step \(name): \(skip.message ?? "skipped")") }
    }
    @MainActor private func focus() throws {
        throw XCTSkip("waits on MD-22")
        library = Journey("Library", self, arguments: ["-LibraryFixture", "cameras"])
        XCTAssert(cell("IMG_0024").waitForExistence(timeout: 60), "no grid cell for IMG_0024")
        library.press(character: "f", .command)
        let field = library.element("library.search")
        XCTAssert(field.waitForExistence(timeout: 5), "no search field (library.search)")
        library.shot("search-focus")
        library.app.typeText("x")  // lands in the field only if it has focus
        XCTAssertEqual(text(field), "x", "Command-F didn't focus the field")
        library.press(.delete)
    }
    @MainActor private func lens() throws {
        throw XCTSkip("waits on MD-22")
        search("lens:50")
        XCTAssert(waitForCells(8), "lens:50 doesn't show 8 photos")
        XCTAssert(cell("IMG_0002").exists, "IMG_0002 (50mm F1.8) is hidden")
        XCTAssertFalse(cell("IMG_0001").exists, "IMG_0001 (24-70mm) still shows")
        XCTAssert(text(library.element("library.status")).contains("8 photos"), "the status doesn't read 8 photos")
        library.shot("search-lens")
    }
    @MainActor private func isoAndKeyword() throws {
        throw XCTSkip("waits on MD-22")
        search("iso:>1600 beach")
        XCTAssert(waitForCells(2), "iso:>1600 beach doesn't show 2 photos")
        XCTAssert(cell("IMG_0013").exists && cell("IMG_0014").exists, "IMG_0013 and IMG_0014 should show")
        library.shot("search-iso")
    }
    @MainActor private func clear() throws {
        throw XCTSkip("waits on MD-22")
        library.press(.escape)
        XCTAssert(waitForCells(24), "Escape didn't bring back all 24 photos")
    }
    @MainActor private func fromDetail() throws {
        throw XCTSkip("waits on MD-22")
        cell("IMG_0002").click()
        library.element("library.inspector.info").click()
        let lens = library.element("library.metadata.camera.lens")
        XCTAssert(lens.waitForExistence(timeout: 5), "no Lens row (library.metadata.camera.lens)")
        lens.click()
        XCTAssertEqual(text(library.element("library.search")), "lens:\"50mm F1.8\"")
        XCTAssert(waitForCells(8), "the Lens value's search doesn't show 8 photos")
        library.shot("search-from-detail")
    }
    @MainActor private func hidesLoupe() throws {
        throw XCTSkip("waits on MD-22")
        cell("IMG_0002").doubleClick()
        XCTAssert(library.element("library.loupe").waitForExistence(timeout: 10), "IMG_0002 didn't open in the loupe")
        search("lens:24")
        XCTAssert(cell("IMG_0001").waitForExistence(timeout: 5), "the window didn't go back to the grid")
        XCTAssertFalse(library.element("library.loupe").exists, "the loupe still shows a hidden photo")
        let selected = cells().matching(NSPredicate(format: "isSelected == true")).count
        XCTAssertEqual(selected, 0, "a photo is still selected")
        library.shot("search-hides-loupe")
    }
    /// Replaces the search field's text with `query`.
    @MainActor private func search(_ query: String) {
        library.element("library.search").click()
        library.press(character: "a", .command)
        library.app.typeText(query)
    }
    /// True once the grid shows exactly `count` cells (5 s at most).
    @MainActor private func waitForCells(_ count: Int) -> Bool {
        (0..<25).contains { _ in
            defer { Thread.sleep(forTimeInterval: 0.2) }
            return cells().count == count
        }
    }
    @MainActor private func cells() -> XCUIElementQuery {
        library.app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "library.grid.cell."))
    }
    @MainActor private func cell(_ name: String) -> XCUIElement {
        library.app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND identifier CONTAINS %@", "library.grid.cell.", name)).firstMatch
    }
    @MainActor private func text(_ item: XCUIElement) -> String {
        (item.value as? String).flatMap { $0.isEmpty ? nil : $0 } ?? item.label
    }
}
