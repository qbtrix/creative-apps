// DesignJourneyTests+WholePoints.swift: drawing, moving and resizing land on
// whole points at any zoom (packet docs/blueprints/design/features/canvas-basics.md,
// Journey steps item 1, CB-a). On `cards` at 1024 × 768 it clicks the top bar's
// zoom-out three times, so a screen point is no longer a document point; picks
// Rectangle in the tool box and drags a box on Desktop's blank area: the
// inspector's X, Y, W and H each read a whole number and the bar's Undo reads
// "Undo Add Rectangle". It drags the rectangle by an odd distance (X and Y whole,
// "Undo Move") and its bottom-right handle by another (W and H whole, "Undo Resize").
// Every step uses the mouse on visible controls, never a shortcut. Written before
// its code (lead.md, contract rule 13): CB-1 wrote it skipped by name, and CB-2
// turned it on. Desktop fills the 1440 × 1024 page, and its children
// leave (800, 620)-(1100, 850) blank, so the draw starts there.
// The Frame rows are ScrubFields: XCUI reads each by its label ("X position") with
// the spoken value ("212 points") as its value; they carry no id of their own yet.
import XCTest

final class DesignWholePointsJourneyTests: XCTestCase {
    static let arguments = ["-DesignFixture", "cards", "-SuiteWindowSize", "1024x768"]

    /// CB-a: draw, move and resize at a zoom out, each ending on whole points.
    @MainActor func testDrawMoveResizeOnWholePoints() throws {
        drawMoveResize()
    }

    @MainActor private func drawMoveResize() {
        let design = Journey("Design", self, arguments: Self.arguments)
        XCTAssert(design.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        XCTAssert(design.element("suite.canvas").waitForExistence(timeout: 10), "cards showed no page")

        // Zoom out three times from the top bar, so screen points and document points differ.
        let zoomOut = design.element("design.bar.zoom-out")
        XCTAssert(zoomOut.waitForExistence(timeout: 5), "no zoom-out in the top bar (design.bar.zoom-out)")
        for _ in 0..<3 { zoomOut.click() }
        design.shot("whole-zoomed-out")

        // Draw a rectangle on Desktop's blank area.
        let rectangle = design.element("suite.tools").buttons["Rectangle"]
        XCTAssert(rectangle.waitForExistence(timeout: 5), "no Rectangle in the tool box (suite.tools)")
        rectangle.click()
        let (start, end) = (CGVector(dx: 0.56, dy: 0.61), CGVector(dx: 0.70, dy: 0.75))
        design.drag(on: "suite.canvas", from: start, to: end, step: "whole-drew")
        let undo = design.element("design.bar.undo")
        XCTAssert(Self.waitForLabel(undo, "Undo Add Rectangle"), "drawing made no Add Rectangle step (Undo reads \(undo.label))")
        expectWhole(design, ["X position", "Y position", "Width", "Height"], after: "drawing")

        // Move it by an odd distance, pressing its middle.
        let canvas = design.element("suite.canvas")
        let middle = canvas.coordinate(withNormalizedOffset: CGVector(dx: (start.dx + end.dx) / 2, dy: (start.dy + end.dy) / 2))
        let moveBy = CGVector(dx: 37, dy: 23)
        middle.press(forDuration: 0.1, thenDragTo: middle.withOffset(moveBy))
        design.shot("whole-moved")
        XCTAssert(Self.waitForLabel(undo, "Undo Move"), "the drag didn't move the rectangle (Undo reads \(undo.label))")
        expectWhole(design, ["X position", "Y position"], after: "moving")

        // Drag its bottom-right handle, which sits on the moved corner, by another odd distance.
        let handle = canvas.coordinate(withNormalizedOffset: end).withOffset(moveBy)
        handle.press(forDuration: 0.1, thenDragTo: handle.withOffset(CGVector(dx: 29, dy: 17)))
        design.shot("whole-resized")
        XCTAssert(Self.waitForLabel(undo, "Undo Resize"), "the handle drag didn't resize (Undo reads \(undo.label))")
        expectWhole(design, ["Width", "Height"], after: "resizing")
    }

    /// Each Frame row labelled in `labels` reads a whole number of points in the inspector.
    @MainActor private func expectWhole(_ design: Journey, _ labels: [String], after action: String) {
        let inspector = design.element("suite.inspector")
        for label in labels {
            let field = inspector.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
            XCTAssert(field.waitForExistence(timeout: 5), "no \(label) row in the inspector after \(action)")
            let value = field.value as? String ?? ""
            XCTAssert(Self.isWhole(value), "\(label) reads \"\(value)\" after \(action), not a whole number")
        }
    }

    /// Whether a spoken value ("212 points", "-4 points") starts with a whole number.
    private static func isWhole(_ spoken: String) -> Bool {
        guard let number = spoken.split(separator: " ").first, !number.contains(".") else { return false }
        return Int(number) != nil
    }

    /// Whether `element`'s label reads `label` within `timeout` seconds.
    @MainActor private static func waitForLabel(_ element: XCUIElement, _ label: String, timeout: Double = 5) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if element.exists && element.label == label { return true }
            Thread.sleep(forTimeInterval: 0.2)
        } while Date() < deadline
        return false
    }
}
