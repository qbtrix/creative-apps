// DesignJourneyTests+Place.swift: DJ-P1 of docs/blueprints/design/features/placed-images.md on `cards` at
// 1024 × 768, the numbered steps below. Select Desktop (a frame), and the inspector's Picture section's Place in
// Frame… photo-1200x800.jpg: the frame shows it cropped by cover, with no new layer; ⌥-drag inside it pans, one
// undo step; widen it and the picture still covers; the Image rows read the file; Reset Size gives 3:2; two undos;
// with "Place into selected frame" on, File > Place… with nothing selected still adds a rectangle `photo-1200x800`; Export SVG. PD-u writes it; it skips until PD-7
// turns it on, once PD-5 runs the place commands and the journey can answer the Place… panel.
import XCTest

final class DesignPlaceJourneyTests: XCTestCase {
    private static let wait = true
    static let arguments = ["-DesignFixture", "cards", "-SuiteWindowSize", "1024x768"]
    /// Desktop's row in Layers (DesignFixtures.cards), and the Picture section's Place in Frame… and its checkbox.
    static let desktopRow = "design.layer.node-1", place = "design.inspector.place", fill = "design.inspector.place-fill"

    @MainActor func testPlacePhotoInFrame() throws {
        if Self.wait { throw XCTSkip("waits on PD-7") }
        let design = Journey("Design", self, arguments: Self.arguments)
        XCTAssert(design.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        XCTAssert(design.element("suite.canvas").waitForExistence(timeout: 10), "the cards fixture showed no page")

        design.clickDesignLayer(Self.desktopRow) // 1. A frame selected: the Picture section offers Place in Frame….
        for id in [Self.place, Self.fill] where !design.element(id).exists { XCTFail("the Picture section shows no \(id)") }
        design.element(Self.place).click() // 2. Place in Frame… photo-1200x800.jpg: it fills the frame, no new layer.
        // PD-7 answers the Place… panel with photo-1200x800.jpg here.
        XCTAssert(design.element("suite.place.file").waitForExistence(timeout: 5), "the frame shows no picture")
        design.shot("image-in-frame")

        let canvas = design.element("suite.canvas") // 3. ⌥-drag inside the picture: it pans, one undo step.
        let middle = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        XCUIElement.perform(withKeyModifiers: .option) {
            middle.press(forDuration: 0.1, thenDragTo: middle.withOffset(CGVector(dx: 60, dy: 0)))
        }
        // 4. Drag the right edge to 600: the picture still covers; the File row reads
        //    "photo-1200x800.jpg · JPEG · 1200 × 800 px".
        design.element("suite.place.reset-size").click() // 5. Reset Size: 3:2. Two undos.
        design.element(Self.fill).click() // The checkbox on, then File > Place… unselected: a new rectangle, no refusal.
        design.shot("image-reset")
        // 6. Export SVG: the picture as a clipped <image> (PD-6).
    }
}
