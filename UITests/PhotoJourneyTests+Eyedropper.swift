// PhotoJourneyTests+Eyedropper.swift: PJ-E1, pick the sky's colour for the
// brush (eyedropper PE-2; docs/blueprints/photo/features/eyedropper.md,
// Journey steps; RJ-P22). On sunset.png (the 800 x 600 test photo: a sky
// gradient, the sun at (560, 220)), I picks the Eyedropper and its options
// show SuiteUI's size chips (`suite.sample.size.<n>`) on Point; a click on
// the sky changes the brush colour (`photo.tool.color`); 5 x 5 and a second
// click change it again; B, then Option-click on the sun, picks with the
// Brush still active. Written now and skipped: the canvas click arrives in
// PE-3 and the live sampler in PE-5, and PE-7 turns it on (replacing the
// skip with a call to `pickSkyColor`), aiming the clicks from the image's
// frame on screen rather than `suite.canvas` (#566). The packet's file is
// sunset.jpg; the journey writes the shared test photo as PNG.
import XCTest

final class PhotoEyedropperJourneyTests: XCTestCase {
    /// PJ-E1: I, a click on the sky, 5 x 5, then Option-click with the Brush.
    @MainActor func testPickSkyColor() throws {
        throw XCTSkip("waits on PE-7")
    }

    @MainActor private func pickSkyColor() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "photo-eyedropper-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appending(path: "sunset.png")
        try writeTestPhoto(to: file)
        let photo = Journey("Photo", self, arguments: photoArguments(open: file))
        XCTAssert(photo.window(named: "sunset.png").waitForExistence(timeout: 30), "sunset.png didn't open")
        let canvas = photo.element("suite.canvas")
        XCTAssert(canvas.waitForExistence(timeout: 5), "no canvas (suite.canvas)")
        canvas.click()

        // 1. I picks the Eyedropper: enabled, selected, its chips on Point.
        photo.press(character: "i")
        let tool = photo.element("suite.tools").buttons["Eyedropper"]
        XCTAssert(tool.waitForExistence(timeout: 5) && tool.isEnabled, "no enabled Eyedropper on the palette")
        XCTAssert(tool.isSelected, "I didn't pick the Eyedropper")
        let point = photo.app.buttons["suite.sample.size.1"]
        XCTAssert(point.waitForExistence(timeout: 5), "no Point chip (suite.sample.size.1)")
        XCTAssert(point.isSelected, "the size chips aren't on Point")
        photo.shot("eyedropper-options")

        // 2 and 3. A click on the sky makes the brush colour the sky's.
        let well = photo.element("photo.tool.color")
        let before = well.value as? String
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.2)).click()
        expectColorChange(well, from: before, "a click on the sky")
        photo.shot("eyedropper-sky")

        // 4. 5 x 5, then a click on the lower sky: the mean, a new colour.
        photo.app.buttons["suite.sample.size.5"].click()
        let sky = well.value as? String
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.7)).click()
        expectColorChange(well, from: sky, "a 5 x 5 click")

        // 5. B, then Option-click on the sun: the sun's colour, the Brush kept.
        photo.press(character: "b")
        let brushColor = well.value as? String
        let sun = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.37))
        XCUIElement.perform(withKeyModifiers: .option) { sun.click() }
        expectColorChange(well, from: brushColor, "an Option-click with the Brush")
        XCTAssert(photo.element("suite.tools").buttons["Brush"].isSelected, "Option-click left the Brush")
        photo.shot("eyedropper-option-brush")
    }

    @MainActor private func expectColorChange(_ well: XCUIElement, from old: String?, _ what: String) {
        let changed = NSPredicate { element, _ in ((element as? XCUIElement)?.value as? String) != old }
        let wait = XCTNSPredicateExpectation(predicate: changed, object: well)
        XCTAssertEqual(XCTWaiter.wait(for: [wait], timeout: 5), .completed, "\(what) didn't change the brush colour")
    }
}
