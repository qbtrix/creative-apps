// PhotoJourneyTests+Text.swift: PJ-TX, a title over a photo (text-layers
// TX-2; docs/blueprints/photo/features/text-layers.md, Journey steps; RJ-P02).
// On the shared test photo, T picks the Type tool, a click on the sky places
// a text box, SUMMER SALE typed and Esc leave one text layer above the photo;
// the inspector's style row then sets size and alignment. Written now and
// skipped: the Type tool arrives in TX-3, the inspector row in TX-4 and the
// layout in TX-5, and TX-7 turns it on (replacing the skip with a call to
// `titleOverPhoto`) and adds the save, reopen and DEALS edit of step 3. The
// packet's file is beach.png; the journey writes the shared test photo.
import XCTest

final class PhotoTextJourneyTests: XCTestCase {
    /// PJ-TX: T, a click on the sky, SUMMER SALE, Esc, then the style row.
    @MainActor func testTitleOverPhoto() throws {
        throw XCTSkip("waits on TX-7")
    }

    @MainActor private func titleOverPhoto() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "photo-text-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appending(path: "beach.png")
        try writeTestPhoto(to: file)
        let photo = Journey("Photo", self, arguments: photoArguments(open: file))
        XCTAssert(photo.window(named: "beach.png").waitForExistence(timeout: 30), "beach.png didn't open")
        let canvas = photo.element("suite.canvas")
        XCTAssert(canvas.waitForExistence(timeout: 5), "no canvas (suite.canvas)")
        canvas.click()

        // 1. T picks the Type tool; a click on the sky places a box; the words and Esc make one text layer.
        photo.press(character: "t")
        let tool = photo.element("suite.tools").buttons["Type"]
        XCTAssert(tool.waitForExistence(timeout: 5) && tool.isEnabled, "no enabled Type tool on the palette")
        XCTAssert(tool.isSelected, "T didn't pick the Type tool")
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.2)).click()
        photo.app.typeText("SUMMER SALE")
        photo.press(.escape)
        XCTAssert(photo.app.staticTexts["SUMMER SALE"].waitForExistence(timeout: 5), "no SUMMER SALE layer in the Layers panel")

        // 2. The inspector's style row: size 120 and Center redraw the layer; Undo steps back one at a time.
        let size = photo.element("suite.text.size")
        XCTAssert(size.waitForExistence(timeout: 5), "no text size field (suite.text.size)")
        let center = photo.element("suite.text.alignment.center")
        XCTAssert(center.waitForExistence(timeout: 5), "no Center button (suite.text.alignment.center)")
        center.click()
        photo.press(character: "z", .command)
        XCTAssertFalse(center.isSelected, "Undo didn't step the alignment back")
    }
}
