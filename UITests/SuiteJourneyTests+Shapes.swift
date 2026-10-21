// SuiteJourneyTests+Shapes.swift: the gallery's `shape-tools` page, the packet's Journey
// steps 1 to 5 (numbered below), clicked through like a person would (SH-2 wrote it, SH-4
// turns it on). Rows are read by their spoken value ("50 percent"), and typed into by
// clicking the row and typing in the field it opens. Until SH-7 draws through shape.draw the
// page logs a drag as "drag <kind> W x H", so steps 2 to 4 check that line; SH-7 tightens
// them to the command's. Points 8 (step 3) and the clamp to 3 (step 5) read through SH-6's
// `applied`, and the square box through SH-5's `dragged`; until those land those checks fail.
import XCTest

extension SuiteJourneyTests {
    @MainActor func testShapeToolsDrawStarAndArrow() throws {
        let gallery = Journey("Library", self, name: "suiteui", arguments: ["-SuiteGallery", "index"])
        XCTAssert(gallery.element("suite.gallery.index").waitForExistence(timeout: 30), "no gallery index")
        gallery.element("suite.gallery.index.shape-tools").click() // 1. Six kind chips over an empty canvas.
        XCTAssert(gallery.element("suite.gallery.shape-tools").waitForExistence(timeout: 10), "no suite.gallery.shape-tools")
        for kind in ["rectangle", "ellipse", "polygon", "star", "line", "arrow"] where !gallery.element("suite.shape.chip-\(kind)").exists { XCTFail("no suite.shape.chip-\(kind)") }
        XCTAssert(gallery.element("suite.shape.corner-radius").exists, "Rectangle shows no Corner radius")
        gallery.shot("shape-tools-open")
        gallery.element("suite.shape.chip-star").click() // 2. Star: Points 5, Inner ratio 50%; a drag logs one line.
        XCTAssert(gallery.element("suite.shape.points").waitForExistence(timeout: 5), "Star shows no Points row")
        XCTAssert(shapeValue(gallery, "suite.shape.points", "5"), "Star's Points isn't 5")
        XCTAssert(shapeValue(gallery, "suite.shape.inner-ratio", "50 percent"), "Inner ratio isn't 50%")
        XCTAssertFalse(gallery.element("suite.shape.sides").exists, "Star shows Sides")
        let canvas = gallery.element("suite.gallery.shape-canvas")
        shapeDrag(canvas, CGVector(dx: 0.2, dy: 0.2), CGVector(dx: 0.5, dy: 0.6))
        expectShapeLog(gallery, "drag star", "the star drag logged no drag star")
        gallery.shot("shape-tools-star")
        typeShape(gallery, "suite.shape.points", "8") // 3. Points 8, then Shift: a square box.
        XCTAssert(shapeValue(gallery, "suite.shape.points", "8"), "typing 8 left Points at \(gallery.element("suite.shape.points").value ?? "nothing")")
        XCUIElement.perform(withKeyModifiers: .shift) { shapeDrag(canvas, CGVector(dx: 0.55, dy: 0.2), CGVector(dx: 0.9, dy: 0.5)) }
        let box = (canvas.value as? String ?? "").components(separatedBy: " x ")
        XCTAssert(box.count == 2 && box.first == box.last, "the Shift-drag's box isn't square: \(canvas.value ?? "nothing")")
        gallery.element("suite.shape.chip-arrow").click() // 4. Arrow: its Head row; a Shift drag near 40°.
        XCTAssert(gallery.element("suite.shape.head").waitForExistence(timeout: 5), "Arrow shows no Head row")
        XCUIElement.perform(withKeyModifiers: .shift) { shapeDrag(canvas, CGVector(dx: 0.1, dy: 0.9), CGVector(dx: 0.4, dy: 0.65)) }
        expectShapeLog(gallery, "drag arrow", "the arrow drag logged no drag arrow")
        gallery.shot("shape-tools-arrow")
        gallery.element("suite.shape.chip-polygon").click() // 5. Sides 2: the row clamps to 3 and names the range.
        XCTAssert(gallery.element("suite.shape.sides").waitForExistence(timeout: 5), "Polygon shows no Sides row")
        typeShape(gallery, "suite.shape.sides", "2")
        XCTAssert(shapeValue(gallery, "suite.shape.sides", "3"), "Sides didn't clamp to 3")
        let help = gallery.element("suite.shape.help")
        XCTAssert(help.waitForExistence(timeout: 5), "typing 2 in Sides showed no help (suite.shape.help)")
        XCTAssert(help.label.contains("3") && help.label.contains("64"), "the Sides help \(help.label) doesn't name 3 to 64")
        gallery.shot("shape-tools-help")
    }

    @MainActor private func shapeDrag(_ canvas: XCUIElement, _ from: CGVector, _ to: CGVector) {
        canvas.coordinate(withNormalizedOffset: from).press(forDuration: 0.2, thenDragTo: canvas.coordinate(withNormalizedOffset: to))
    }

    /// Clicks the row `id`, types `text` in the field it opens over what it shows, and presses Return.
    @MainActor private func typeShape(_ gallery: Journey, _ id: String, _ text: String) {
        let row = gallery.element(id)
        row.click()
        let inside = row.textFields.firstMatch
        let field = inside.waitForExistence(timeout: 2) ? inside : gallery.element("suite.gallery.shape-tools").textFields.firstMatch
        XCTAssert(field.waitForExistence(timeout: 5), "clicking \(id) opened no field to type in")
        field.typeKey("a", modifierFlags: .command)
        field.typeText(text + "\r")
    }

    /// Whether the row `id` reads `value` within five seconds.
    @MainActor private func shapeValue(_ gallery: Journey, _ id: String, _ value: String) -> Bool {
        let wait = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", value), object: gallery.element(id))
        return XCTWaiter().wait(for: [wait], timeout: 5) == .completed
    }

    /// Waits up to five seconds for the page's log to contain `text`.
    @MainActor private func expectShapeLog(_ gallery: Journey, _ text: String, _ message: String) {
        let log = gallery.element("suite.gallery.log")
        let wait = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value CONTAINS %@", text), object: log)
        XCTAssertEqual(XCTWaiter().wait(for: [wait], timeout: 5), .completed, "\(message); the log reads \(log.value ?? "nothing")")
    }
}
