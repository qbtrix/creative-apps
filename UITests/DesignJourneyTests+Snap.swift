// DesignJourneyTests+Snap.swift: SN-c, snap to layers and the smart guides
// (packet docs/blueprints/design/features/snapping.md, Journey steps item 1).
// On `-DesignFixture cards` at the window's fitted zoom, every step uses the
// mouse on visible controls: Layers rows, the tool box, the top bar's Undo
// and the View menu, never a shortcut (lesson 152). XCUITest can't see guides
// drawn in a canvas, so the canvas publishes the last drag's guide summary as
// the label of `design.canvas.guides` ("x 300, gap x 100", or "none"), read by
// its label since XCUITest reads a SwiftUI value as empty (#262).
// Screen positions come from the `design.canvas.selection` element's frame
// after a click on each layer's row, so each drag stops 2 screen points short
// of its target, inside the window's snap reach of 8 screen points. A file
// opens with its rows collapsed, so Desktop's row is opened first, after each
// launch (#2456), and a row is clicked off its name (#2496).
// Written before its code (lead.md, contract rule 13): SN-6 writes it skipped
// by name; SN-7 draws the guides; SN-8 adds View > Snap to Layers and lifts
// the skip (the item enabled right after Fit Page, the checkmark, the
// relaunch, the toggle); SN-10 sets `snapIsLive`: the drags and guide reads
// run on the live snap routes.
import XCTest

final class DesignSnapJourneyTests: XCTestCase {
    static let arguments = ["-DesignFixture", "cards", "-SuiteWindowSize", "1024x768"]
    /// True since SN-10: the drags and the guide reads run on the live snap routes.
    static let snapIsLive = true
    static let snapItem = "Snap to Layers"
    /// The Layers rows of `cards` (DesignFixtures.cards): A, B, C and Pair.
    static let rowA = "design.layer.node-2", rowB = "design.layer.node-3"
    static let rowC = "design.layer.node-4", rowPair = "design.layer.node-6", rowDesktop = "design.layer.node-1"
    static let guides = "design.canvas.guides", selection = "design.canvas.selection"
    static let undo = "design.bar.undo"

    /// The screen frames of the layers the drags aim at, read at the start.
    struct Frames { var a: CGRect, b: CGRect, c: CGRect, pair: CGRect }

    /// SN-c: moves, resizes, several moves, equal spacing and draws snap; the setting turns it off and is remembered.
    @MainActor func testSnapAndSmartGuides() throws {
        walkSnapAndSmartGuides()
    }

    /// The journey itself, steps 1 to 9.
    @MainActor private func walkSnapAndSmartGuides() {
        var design = open()

        // 1. A clean start: Snap to Layers on; note B's, C's, Pair's and A's frames.
        let item = viewItem(design)
        XCTAssert(item.isEnabled, "View > \(Self.snapItem) is disabled")
        expectAfterFitPage(design)
        if isChecked(item) { closeView(design) } else { item.click() }
        design.expandDesignLayer(Self.rowDesktop)
        let frames = Frames(a: frame(design, Self.rowA), b: frame(design, Self.rowB),
                            c: frame(design, Self.rowC), pair: frame(design, Self.rowPair))
        design.shot("snap-start")

        if Self.snapIsLive {
            // 2. Move: A's right edge 2 pt short of B's left edge lands X 200, guide x 300.
            moveAToB(design, frames)
            expectStep(design, "Undo Move", after: "the snapped move")
            expectField(design, "X position", "the snapped move") { $0 == 200 }
            expectGuides(design, contain: "x 300", after: "the snapped move")
            design.shot("snap-move")
            clickUndo(design)

            // 3. Resize: A's bottom-right handle 2 pt short of B's left edge lands W 200, guide x 300.
            _ = frame(design, Self.rowA)
            drag(design, from: CGPoint(x: frames.a.maxX, y: frames.a.maxY),
                 to: CGPoint(x: frames.b.minX - 2, y: frames.a.maxY))
            expectStep(design, "Undo Resize", after: "the snapped resize")
            expectField(design, "Width", "the snapped resize") { $0 == 200 }
            expectGuides(design, contain: "x 300", after: "the snapped resize")
            design.shot("snap-resize")
            clickUndo(design)

            // 4. Several: a marquee over A and B, then the box's bottom 2 pt short of Pair's bottom: guide y 500.
            drag(design, from: CGPoint(x: frames.a.minX - 10, y: frames.a.minY - 10),
                 to: CGPoint(x: frames.b.maxX + 10, y: frames.b.maxY + 10))
            drag(design, from: CGPoint(x: frames.a.midX, y: frames.a.midY),
                 to: CGPoint(x: frames.a.midX, y: frames.a.midY + frames.pair.maxY - 2 - frames.b.maxY))
            expectStep(design, "Undo Move", after: "the snapped several move")
            expectGuides(design, contain: "y 500", after: "the snapped several move")
            design.shot("snap-several")
            clickUndo(design)

            // 5. Equal spacing: C left to 2 pt short of a gap to B equal to A's: X 600, "spacing x 100".
            _ = frame(design, Self.rowC)
            let target = frames.b.maxX + (frames.b.minX - frames.a.maxX) + 2
            drag(design, from: CGPoint(x: frames.c.midX, y: frames.c.midY),
                 to: CGPoint(x: frames.c.midX + target - frames.c.minX, y: frames.c.midY))
            expectStep(design, "Undo Move", after: "the spacing move")
            expectField(design, "X position", "the spacing move") { $0 == 600 }
            expectGuides(design, contain: "spacing x 100", after: "the spacing move")
            design.shot("snap-spacing")
            clickUndo(design)

            // 6. Draw: Rectangle from 2 pt right of B's top-right to 2 pt left of C's bottom-left: (500, 140, 200, 80).
            tool(design, "Rectangle").click()
            drag(design, from: CGPoint(x: frames.b.maxX + 2, y: frames.b.minY),
                 to: CGPoint(x: frames.c.minX - 2, y: frames.c.maxY))
            expectStep(design, "Undo Add Rectangle", after: "the snapped draw")
            for (name, value) in [("X position", 500.0), ("Y position", 140), ("Width", 200), ("Height", 80)] {
                expectField(design, name, "the snapped draw") { $0 == value }
            }
            design.shot("snap-draw")
            clickUndo(design)
            tool(design, "Move").click()
        }

        // 7. Off: View > Snap to Layers; step 2's drag lands short of 200 with no guides.
        viewItem(design).click()
        if Self.snapIsLive {
            moveAToB(design, frames)
            expectField(design, "X position", "the move with snapping off") { $0 < 200 }
            expectGuides(design, equal: "none", after: "the move with snapping off")
            design.shot("snap-off")
            clickUndo(design)
        }

        // 8. Remembered: relaunch; Snap to Layers is unchecked and step 2's drag doesn't snap.
        design = open()
        let off = viewItem(design)
        XCTAssertFalse(isChecked(off), "Snap to Layers is checked after a relaunch with it turned off")
        design.shot("snap-remembered", screen: true)
        closeView(design)
        if Self.snapIsLive {
            moveAToB(design, frames)
            expectField(design, "X position", "the move after the relaunch") { $0 < 200 }
            clickUndo(design)
        }

        // 9. On again: View > Snap to Layers; step 2's drag lands X 200. The setting stays on.
        viewItem(design).click()
        if Self.snapIsLive {
            moveAToB(design, frames)
            expectField(design, "X position", "the move with snapping on again") { $0 == 200 }
            design.shot("snap-on-again")
            clickUndo(design)
        }
    }

    /// Step 2's drag: click A's row, then drag A by its middle until its right edge is 2 pt short of B's left edge.
    @MainActor private func moveAToB(_ design: Journey, _ frames: Frames) {
        design.expandDesignLayer(Self.rowDesktop)
        design.clickDesignLayer(Self.rowA)
        let start = CGPoint(x: frames.a.midX, y: frames.a.midY)
        drag(design, from: start, to: CGPoint(x: start.x + frames.b.minX - 2 - frames.a.maxX, y: start.y))
    }

    /// Launches `cards` and waits for its canvas.
    @MainActor private func open() -> Journey {
        let design = Journey("Design", self, arguments: Self.arguments)
        XCTAssert(design.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        XCTAssert(design.element("suite.canvas").waitForExistence(timeout: 10), "cards showed no page (suite.canvas)")
        return design
    }

    /// Clicks the Layers row `identifier` and returns the selection mark's screen frame.
    @MainActor private func frame(_ design: Journey, _ identifier: String) -> CGRect {
        design.clickDesignLayer(identifier)
        let mark = design.element(Self.selection)
        XCTAssert(mark.waitForExistence(timeout: 5), "clicking \(identifier) selected nothing (\(Self.selection))")
        return mark.frame
    }

    /// The tool box's button `title`.
    @MainActor private func tool(_ design: Journey, _ title: String) -> XCUIElement {
        let button = design.element("suite.tools").buttons[title]
        XCTAssert(button.waitForExistence(timeout: 5), "no \(title) in the tool box (suite.tools)")
        return button
    }

    /// Opens the View menu and returns its Snap to Layers item.
    @MainActor private func viewItem(_ design: Journey) -> XCUIElement {
        design.app.menuBars.firstMatch.menuBarItems["View"].click()
        let item = design.app.menuBars.firstMatch.menuItems[Self.snapItem].firstMatch
        XCTAssert(item.waitForExistence(timeout: 5), "no View > \(Self.snapItem)")
        return item
    }

    /// With View open: Snap to Layers is the item right after Fit Page (SN-8).
    @MainActor private func expectAfterFitPage(_ design: Journey) {
        let titles = design.app.menuBars.firstMatch.menuBarItems["View"].menuItems.allElementsBoundByIndex.map(\.title)
        let fit = titles.firstIndex(of: "Fit Page"), snap = titles.firstIndex(of: Self.snapItem)
        XCTAssert(fit != nil && snap == fit.map { $0 + 1 }, "View lists \(titles), not \(Self.snapItem) right after Fit Page")
    }

    /// Clicks View again, which closes its open menu.
    @MainActor private func closeView(_ design: Journey) {
        design.app.menuBars.firstMatch.menuBarItems["View"].click()
    }

    /// Whether a menu item shows its checkmark: its value reads 1 (Unverified API).
    @MainActor private func isChecked(_ item: XCUIElement) -> Bool {
        if let number = item.value as? NSNumber { return number.boolValue }
        let text = item.value as? String ?? ""
        return text == "1" || text == "✓"
    }

    /// Clicks the top bar's Undo.
    @MainActor private func clickUndo(_ design: Journey) {
        let undo = design.element(Self.undo)
        XCTAssert(undo.waitForExistence(timeout: 5), "no Undo in the top bar (\(Self.undo))")
        undo.click()
    }

    /// Presses the screen point `start` and drags to the screen point `end`.
    @MainActor private func drag(_ design: Journey, from start: CGPoint, to end: CGPoint) {
        let window = design.app.windows.firstMatch
        window.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: start.x - window.frame.minX, dy: start.y - window.frame.minY))
            .press(forDuration: 0.1, thenDragTo: window.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: end.x - window.frame.minX, dy: end.y - window.frame.minY)))
    }

    /// The top bar's Undo reads `title`.
    @MainActor private func expectStep(_ design: Journey, _ title: String, after step: String) {
        let undo = design.element(Self.undo)
        XCTAssert(Self.poll { undo.exists && undo.label == title }, "\(step) made no step \(title) (Undo reads \(undo.label))")
    }

    /// The guides summary contains `part`.
    @MainActor private func expectGuides(_ design: Journey, contain part: String, after step: String) {
        let mark = design.element(Self.guides)
        XCTAssert(Self.poll { Self.words(mark).contains(part) },
                  "after \(step) \(Self.guides) reads \(Self.words(mark)), without \(part)")
    }

    /// The guides summary is exactly `expected`.
    @MainActor private func expectGuides(_ design: Journey, equal expected: String, after step: String) {
        let mark = design.element(Self.guides)
        XCTAssert(Self.poll { Self.words(mark) == expected },
                  "after \(step) \(Self.guides) reads \(Self.words(mark)), not \(expected)")
    }

    /// The guides probe's summary: its label (#262), else its value; empty when it's missing.
    @MainActor private static func words(_ mark: XCUIElement) -> String {
        guard mark.exists else { return "" }
        return mark.label.isEmpty ? mark.value as? String ?? "" : mark.label
    }

    /// The inspector's field `name` (its spoken value, "200 points") passes `condition` within five seconds.
    @MainActor private func expectField(_ design: Journey, _ name: String, _ step: String, _ condition: (Double) -> Bool) {
        let field = design.element("suite.inspector").descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", name)).firstMatch
        let read = { () -> Double? in
            guard field.exists, let spoken = field.value as? String, let word = spoken.split(separator: " ").first else { return nil }
            return Double(word.filter { $0.isNumber || $0 == "." || $0 == "-" })
        }
        XCTAssert(Self.poll { read().map(condition) == true }, "after \(step) the inspector's \(name) reads \(String(describing: read()))")
    }

    /// Polls `condition` for up to five seconds.
    @MainActor private static func poll(_ condition: () -> Bool) -> Bool {
        for _ in 0..<25 {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return condition()
    }
}
