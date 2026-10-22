// DesignJourneyTests+Shapes.swift (shape-tools DS-7): J-DS, drawing a star and an arrow with the Shape tool on
// live services, as a person does (docs/blueprints/design/features/shape-tools.md, Journey steps). On `empty` (New
// File: one page holding the Desktop frame, node-1) at 1024 × 768, so the first shape is node-2 and the next node-3.
// 1. Press U: the palette's Shape is picked and the inspector's Shape section (SuiteUI's ShapeToolOptions) shows
//    the kind chips on Star (`suite.shape.chip-star`) with its Points row (`suite.shape.points`).
// 2. Click Star, Shift-drag on the page: one "Draw Star" step, a star in Layers (`design.layer.node-2`), and the
//    canvas changes. The draw hands the palette back to Move.
// 3. Click the palette's Shape, pick Arrow (`suite.shape.chip-arrow`, its Head row `suite.shape.head`), drag: one
//    "Draw Arrow" step and an arrow in Layers (`design.layer.node-3`).
// 4. The top bar's Undo, once: the arrow's row goes, the star's stays, Undo names Draw Star, and the canvas changes.
// Shots: design-shape-options, -star, -arrow, -undone.
import XCTest

final class DesignShapeJourneyTests: XCTestCase {
    static let arguments = ["-DesignServices", "live", "-DesignFixture", "empty", "-SuiteWindowSize", "1024x768"]
    /// The star's and the arrow's rows in Layers: the first ids after `empty`'s Desktop frame.
    static let starRow = "design.layer.node-2", arrowRow = "design.layer.node-3"

    /// J-DS: U, a star, an arrow, one Undo.
    @MainActor func testDrawStarAndArrow() {
        let design = Journey("Design", self, arguments: Self.arguments)
        XCTAssert(design.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        XCTAssert(design.element("suite.canvas").waitForExistence(timeout: 10), "the empty fixture showed no page (suite.canvas)")
        let undo = design.element("design.bar.undo")
        let shapeTool = design.element("suite.tools").buttons["Shape"]

        // 1. U picks the Shape tool; its options lead the inspector, on Star.
        design.press(character: "u")
        XCTAssert(Self.waitUntil { shapeTool.exists && shapeTool.isSelected }, "U didn't pick the palette's Shape")
        let star = control(design, "suite.shape.chip-star")
        XCTAssert(star.waitForExistence(timeout: 5), "the Shape tool shows no Star chip in the inspector")
        XCTAssert(star.isSelected, "the Shape tool's options don't open on Star")
        XCTAssert(control(design, "suite.shape.points").exists, "Star shows no Points row (suite.shape.points)")
        design.shot("shape-options")

        // 2. Star, then a Shift-drag: one Draw Star step and its row in Layers.
        star.click()
        let blank = canvasPixels(design)
        XCUIElement.perform(withKeyModifiers: .shift) {
            design.drag(on: "suite.canvas", from: CGVector(dx: 0.2, dy: 0.25), to: CGVector(dx: 0.35, dy: 0.45))
        }
        XCTAssert(Self.waitForLabel(undo, "Undo Draw Star"), "the drag made no Draw Star step (Undo reads \(undo.label))")
        XCTAssert(layer(design, Self.starRow).waitForExistence(timeout: 5), "no star row in Layers (\(Self.starRow))")
        XCTAssert(canvasChanged(from: blank, design), "the star didn't show on the canvas")
        design.shot("shape-star")

        // 3. The palette's Shape again, Arrow, a drag: one Draw Arrow step and its row.
        XCTAssert(shapeTool.isEnabled, "the palette's Shape is disabled")
        shapeTool.click()
        let arrow = control(design, "suite.shape.chip-arrow")
        XCTAssert(arrow.waitForExistence(timeout: 5), "the Shape tool shows no Arrow chip")
        arrow.click()
        XCTAssert(Self.waitUntil { arrow.isSelected }, "clicking Arrow didn't pick it")
        XCTAssert(control(design, "suite.shape.head").waitForExistence(timeout: 5), "Arrow shows no Head row (suite.shape.head)")
        let withStar = canvasPixels(design)
        design.drag(on: "suite.canvas", from: CGVector(dx: 0.55, dy: 0.3), to: CGVector(dx: 0.75, dy: 0.5))
        XCTAssert(Self.waitForLabel(undo, "Undo Draw Arrow"), "the drag made no Draw Arrow step (Undo reads \(undo.label))")
        XCTAssert(layer(design, Self.arrowRow).waitForExistence(timeout: 5), "no arrow row in Layers (\(Self.arrowRow))")
        XCTAssert(canvasChanged(from: withStar, design), "the arrow didn't show on the canvas")
        design.shot("shape-arrow")

        // 4. One Undo takes the arrow alone.
        let withBoth = canvasPixels(design)
        undo.click()
        XCTAssert(Self.waitForLabel(undo, "Undo Draw Star"), "one Undo didn't stop at Draw Star (Undo reads \(undo.label))")
        XCTAssert(layer(design, Self.arrowRow).waitForNonExistence(timeout: 5), "Undo left the arrow's row in Layers")
        XCTAssert(layer(design, Self.starRow).exists, "Undo took the star's row too")
        XCTAssert(canvasChanged(from: withBoth, design), "Undo left the arrow on the canvas")
        design.shot("shape-undone")
    }

    // MARK: - Steps

    /// The inspector's control with the id `identifier`.
    @MainActor private func control(_ design: Journey, _ identifier: String) -> XCUIElement {
        design.element("suite.inspector").descendants(matching: .any)[identifier].firstMatch
    }

    /// The Layers row with the id `identifier`.
    @MainActor private func layer(_ design: Journey, _ identifier: String) -> XCUIElement {
        design.element("suite.sidebar").descendants(matching: .any)[identifier].firstMatch
    }

    @MainActor private func canvasPixels(_ design: Journey) -> Data {
        design.element("suite.canvas").screenshot().pngRepresentation
    }

    /// Whether the canvas stops matching `before` within five seconds.
    @MainActor private func canvasChanged(from before: Data, _ design: Journey) -> Bool {
        Self.waitUntil { self.canvasPixels(design) != before }
    }

    /// Whether `element`'s label reads `label` within `timeout` seconds.
    @MainActor private static func waitForLabel(_ element: XCUIElement, _ label: String, timeout: Double = 5) -> Bool {
        waitUntil(timeout: timeout) { element.exists && element.label == label }
    }

    /// Whether `condition` holds within `timeout` seconds.
    @MainActor private static func waitUntil(timeout: Double = 5, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.2)
        } while Date() < deadline
        return condition()
    }
}
