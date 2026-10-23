// DesignJourneyTests+Stroke.swift: the Journey steps of docs/blueprints/design/features/stroke-style.md (numbered
// below) on `cards` at 1024 × 768. Click A's row in Layers, then Add Stroke: a 1 pt black stroke, and SuiteUI's
// stroke editor (DK-2, no trim rows in Design) shows Width, Join, Cap and Dash; scrub Width to 2, pick the Round cap
// and Dashed, one step per gesture; Undo three times back to a plain 1 pt stroke; and an `old-strokes.design` saved
// before the feature keeps its colours and widths. The editor's rows are SS-3's `suite.stroke.*` ids. DK-2 writes it;
// it skips until DK-8 turns it on, once DK-6 runs the stroke commands and DK-5 adds the old file.
import XCTest

final class DesignStrokeJourneyTests: XCTestCase {
    private static let wait = true
    static let arguments = ["-DesignFixture", "cards", "-SuiteWindowSize", "1024x768"]
    /// Desktop's row (collapsed when the file opens) and A's inside it (DesignFixtures.cards).
    static let desktopRow = "design.layer.node-1", rowA = "design.layer.node-2"
    /// The editor's own Add Stroke, the section's only one (#3864).
    static let addStroke = "suite.stroke.add"

    /// The packet's dashed border: add, width, cap, dash, three undos, then an old file's strokes.
    @MainActor func testDashedBorder() throws {
        if Self.wait { throw XCTSkip("waits on DK-8") }
        let design = Journey("Design", self, arguments: Self.arguments)
        XCTAssert(design.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        XCTAssert(design.element("suite.canvas").waitForExistence(timeout: 10), "the cards fixture showed no page")

        design.expandDesignLayer(Self.desktopRow) // 1. A, then Add Stroke: Width, Join, Cap and Dash, no trim.
        design.clickDesignLayer(Self.rowA)
        let add = design.element(Self.addStroke)
        XCTAssert(add.waitForExistence(timeout: 5), "no Add Stroke (\(Self.addStroke))")
        add.click()
        for row in ["width", "join.round", "cap.round", "dash.dashed"] where !design.element("suite.stroke.\(row)").exists {
            XCTFail("the stroke editor shows no suite.stroke.\(row)")
        }
        XCTAssertFalse(design.element("suite.stroke.trim-start").exists, "Design's stroke editor shows trim rows")
        for twin in ["design.inspector.stroke-width", "design.inspector.stroke-remove"] {
            XCTAssertFalse(design.element(twin).exists, "\(twin) beside the editor's own row (#3864)")
        }
        design.shot("stroke-added")

        let width = design.element("suite.stroke.width") // 2. Width 2, Round cap, Dashed: one step each.
        let start = width.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 10, dy: 0)))
        design.element("suite.stroke.cap.round").click()
        design.element("suite.stroke.dash.dashed").click()
        design.shot("stroke-dashed")

        let undo = design.element("design.bar.undo") // 3. Three undos: a plain 1 pt stroke again.
        for _ in 0..<3 { undo.click() }
        XCTAssert(design.element("suite.stroke.dash.solid").exists, "three undos left a dash")
        design.shot("stroke-undone")
        // 4. `old-strokes.design` (DK-5's fixture) opens with its colours and widths; DK-8 adds the open step.
    }
}
