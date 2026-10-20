// SuiteJourneyTests+Shapes.swift: the gallery's `shape-tools` page, the packet's Journey
// steps 1 to 5 (numbered below). SH-2 writes it; it skips until SH-4 turns it on.
import XCTest

extension SuiteJourneyTests {
    private static let shapesWait = true

    @MainActor func testShapeToolsDrawStarAndArrow() throws {
        if Self.shapesWait { throw XCTSkip("waits on SH-4") }
        let gallery = Journey("Library", self, name: "suiteui", arguments: ["-SuiteGallery", "index"])
        XCTAssert(gallery.element("suite.gallery.index").waitForExistence(timeout: 30), "no gallery index")
        gallery.element("suite.gallery.index.shape-tools").click() // 1. Six kind chips over an empty canvas.
        XCTAssert(gallery.element("suite.gallery.shape-tools").waitForExistence(timeout: 10), "no suite.gallery.shape-tools")
        for kind in ["rectangle", "ellipse", "polygon", "star", "line", "arrow"] where !gallery.element("suite.shape.chip-\(kind)").exists { XCTFail("no suite.shape.chip-\(kind)") }
        gallery.shot("shape-tools-open")
        gallery.element("suite.shape.chip-star").click() // 2. Star: Points 5, Inner ratio 50%; a drag logs one shape.draw.
        XCTAssertEqual(gallery.element("suite.shape.points").value as? String, "5", "Star's Points isn't 5")
        XCTAssertEqual(gallery.element("suite.shape.inner-ratio").value as? String, "50%", "Inner ratio isn't 50%")
        let canvas = gallery.element("suite.gallery.shape-canvas")
        shapeDrag(canvas, CGVector(dx: 0.2, dy: 0.2), CGVector(dx: 0.5, dy: 0.6))
        expectShapeLog(gallery, "shape.draw star", "the star drag logged no shape.draw star")
        gallery.shot("shape-tools-star")
        gallery.element("suite.shape.points").doubleClick(); gallery.element("suite.shape.points").typeText("8\r") // 3. Then Shift: a square.
        XCUIElement.perform(withKeyModifiers: .shift) { shapeDrag(canvas, CGVector(dx: 0.55, dy: 0.2), CGVector(dx: 0.9, dy: 0.5)) }
        expectShapeLog(gallery, "points 8, square", "the Shift-drag drew no square eight-point star")
        gallery.element("suite.shape.chip-arrow").click() // 4. Shift near 40°: it snaps to 45°.
        XCUIElement.perform(withKeyModifiers: .shift) { shapeDrag(canvas, CGVector(dx: 0.1, dy: 0.9), CGVector(dx: 0.4, dy: 0.65)) }
        expectShapeLog(gallery, "arrow 45°", "the Shift arrow didn't snap to 45°")
        gallery.shot("shape-tools-arrow")
        gallery.element("suite.shape.chip-polygon").click() // 5. Sides 2: the row clamps to 3 and names the range.
        let sides = gallery.element("suite.shape.sides")
        sides.doubleClick(); sides.typeText("2\r")
        XCTAssertEqual(sides.value as? String, "3", "Sides didn't clamp to 3")
        XCTAssert(gallery.app.staticTexts["A polygon needs 3 to 64 sides."].waitForExistence(timeout: 5), "no Sides help")
        gallery.shot("shape-tools-help")
    }

    @MainActor private func shapeDrag(_ canvas: XCUIElement, _ from: CGVector, _ to: CGVector) {
        canvas.coordinate(withNormalizedOffset: from).press(forDuration: 0.2, thenDragTo: canvas.coordinate(withNormalizedOffset: to))
    }
    /// Waits up to five seconds for the page's log to contain `text`.
    @MainActor private func expectShapeLog(_ gallery: Journey, _ text: String, _ message: String) {
        let log = gallery.element("suite.gallery.log")
        let wait = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value CONTAINS %@", text), object: log)
        XCTAssertEqual(XCTWaiter().wait(for: [wait], timeout: 5), .completed, "\(message); the log reads \(log.value ?? "nothing")")
    }
}
