// PhotoJourneyTests+Eyedropper.swift: PJ-E1, pick the sky's colour for the
// brush (eyedropper PE-2; docs/blueprints/photo/features/eyedropper.md,
// Journey steps; RJ-P22). On sunset.png (the 800 x 600 test photo: a sky
// gradient, the sun at (560, 220) with a 90 px radius), I picks the
// Eyedropper and its options show SuiteUI's size chips
// (`suite.sample.size.<n>`) on Point; a click on the sky changes the brush
// colour (`photo.tool.color`); 5 x 5 and a second click change it again; B,
// then Option-click on the sun, picks with the Brush still active. Live since
// PE-7, on the canvas click (PE-3), the live sampler (PE-5) and the adapter
// (PE-6). Clicks are aimed at image pixels through the image's frame on
// screen, `suite.canvas.artboard` (CanvasViewport's leaf element over the
// document at the current zoom), not `suite.canvas`, the scroll area around
// the image (#566). The packet's file is sunset.jpg; the journey writes the
// shared test photo as PNG.
import XCTest

final class PhotoEyedropperJourneyTests: XCTestCase {
    /// PJ-E1: I, a click on the sky, 5 x 5, then Option-click with the Brush.
    @MainActor func testPickSkyColor() throws {
        try pickSkyColor()
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
        let image = photo.element("suite.canvas.artboard")
        XCTAssert(image.waitForExistence(timeout: 5), "no image frame on the canvas (suite.canvas.artboard)")

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
        image.coordinate(withNormalizedOffset: Self.pixel(160, 120)).click()
        expectColorChange(well, from: before, "a click on the sky")
        photo.shot("eyedropper-sky")

        // 4. 5 x 5, then a click on the lower sky: the mean, a new colour.
        photo.app.buttons["suite.sample.size.5"].click()
        let sky = well.value as? String
        image.coordinate(withNormalizedOffset: Self.pixel(160, 420)).click()
        expectColorChange(well, from: sky, "a 5 x 5 click")

        // 5. B, then Option-click on the sun: the sun's colour, the Brush kept.
        photo.press(character: "b")
        let brushColor = well.value as? String
        let sun = image.coordinate(withNormalizedOffset: Self.pixel(560, 220))
        XCUIElement.perform(withKeyModifiers: .option) { sun.click() }
        expectColorChange(well, from: brushColor, "an Option-click with the Brush")
        XCTAssert(photo.element("suite.tools").buttons["Brush"].isSelected, "Option-click left the Brush")
        photo.shot("eyedropper-option-brush")
    }

    /// Image pixel (`x`, `y`) of the 800 x 600 test photo as a normalized offset of `suite.canvas.artboard`.
    private static func pixel(_ x: CGFloat, _ y: CGFloat) -> CGVector {
        CGVector(dx: x / 800, dy: y / 600)
    }

    @MainActor private func expectColorChange(_ well: XCUIElement, from old: String?, _ what: String) {
        let changed = NSPredicate { element, _ in ((element as? XCUIElement)?.value as? String) != old }
        let wait = XCTNSPredicateExpectation(predicate: changed, object: well)
        XCTAssertEqual(XCTWaiter.wait(for: [wait], timeout: 5), .completed, "\(what) didn't change the brush colour")
    }
}
