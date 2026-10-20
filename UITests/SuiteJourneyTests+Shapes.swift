// SuiteJourneyTests+Shapes.swift: the gallery's `shape-tools` page (packet
// docs/blueprints/suiteui/features/shape-tools.md, Journey steps 1 to 5). From
// the index it opens the page, picks Star and drags a five-point star on the
// canvas, sets Points to 8 and Shift-drags a square one, picks Arrow and
// Shift-drags near 40° so it snaps to 45°, then types 2 in Polygon's Sides and
// reads the help. SH-2 writes it; it skips until SH-4 turns it on.
import XCTest

extension SuiteJourneyTests {
    /// True until SH-4 builds the options' rows and snapshots.
    private static let shapesWait = true

    /// SH-3 and SH-4: the kind chips switch the rows, drags draw, and an out-of-range count names its range.
    @MainActor func testShapeToolsDrawStarAndArrow() throws {
        if Self.shapesWait { throw XCTSkip("waits on SH-4") }
        let gallery = Journey("Library", self, name: "suiteui", arguments: ["-SuiteGallery", "index"])
        XCTAssert(gallery.element("suite.gallery.index").waitForExistence(timeout: 30), "no gallery index")

        // 1. Open the page: the six kind chips over an empty canvas.
        gallery.element("suite.gallery.index.shape-tools").click()
        XCTAssert(gallery.element("suite.gallery.shape-tools").waitForExistence(timeout: 10), "no root suite.gallery.shape-tools")
        for kind in ["rectangle", "ellipse", "polygon", "star", "line", "arrow"] {
            XCTAssert(gallery.element("suite.shape.chip-\(kind)").exists, "no \(kind) chip (suite.shape.chip-\(kind))")
        }
        gallery.shot("shape-tools-open")

        // 2. Pick Star: Points 5, Inner ratio 50%. A drag logs one shape.draw.
        gallery.element("suite.shape.chip-star").click()
        XCTAssertEqual(gallery.element("suite.shape.points").value as? String, "5", "Star's Points isn't 5")
        XCTAssertEqual(gallery.element("suite.shape.inner-ratio").value as? String, "50%", "Star's Inner ratio isn't 50%")
        let canvas = gallery.element("suite.gallery.shape-canvas")
        shapeDrag(canvas, from: CGVector(dx: 0.2, dy: 0.2), to: CGVector(dx: 0.5, dy: 0.6))
        expectShapeLog(gallery, "shape.draw star", "the star drag logged no shape.draw star")
        gallery.shot("shape-tools-star")

        // 3. Points 8, then a Shift-drag: an eight-point star in a square box.
        let points = gallery.element("suite.shape.points")
        points.doubleClick()
        points.typeText("8\r")
        XCUIElement.perform(withKeyModifiers: .shift) {
            shapeDrag(canvas, from: CGVector(dx: 0.55, dy: 0.2), to: CGVector(dx: 0.9, dy: 0.5))
        }
        expectShapeLog(gallery, "points 8, square", "the Shift-drag drew no square eight-point star")

        // 4. Arrow, Shift near 40°: it snaps to 45° and its head sits at the release.
        gallery.element("suite.shape.chip-arrow").click()
        XCUIElement.perform(withKeyModifiers: .shift) {
            shapeDrag(canvas, from: CGVector(dx: 0.1, dy: 0.9), to: CGVector(dx: 0.4, dy: 0.65))
        }
        expectShapeLog(gallery, "arrow 45°", "the Shift arrow didn't snap to 45°")
        gallery.shot("shape-tools-arrow")

        // 5. Polygon, Sides 2: the row clamps to 3 and names the range.
        gallery.element("suite.shape.chip-polygon").click()
        let sides = gallery.element("suite.shape.sides")
        sides.doubleClick()
        sides.typeText("2\r")
        XCTAssertEqual(sides.value as? String, "3", "Sides didn't clamp to 3")
        XCTAssert(gallery.app.staticTexts["A polygon needs 3 to 64 sides."].waitForExistence(timeout: 5), "no Sides help")
        gallery.shot("shape-tools-help")
    }

    /// Presses at `from` on `canvas` and drags to `to`, both normalized.
    @MainActor private func shapeDrag(_ canvas: XCUIElement, from: CGVector, to: CGVector) {
        canvas.coordinate(withNormalizedOffset: from).press(forDuration: 0.2, thenDragTo: canvas.coordinate(withNormalizedOffset: to))
    }

    /// Waits up to five seconds for the page's log to contain `text`.
    @MainActor private func expectShapeLog(_ gallery: Journey, _ text: String, _ message: String) {
        let log = gallery.element("suite.gallery.log")
        let wait = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value CONTAINS %@", text), object: log)
        XCTAssertEqual(XCTWaiter().wait(for: [wait], timeout: 5), .completed, "\(message); the log reads \(log.value ?? "nothing")")
    }
}
