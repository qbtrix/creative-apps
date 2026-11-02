// FlareJourneyTests+Pen.swift (pen-paths FP-4, slice FP-u; packet docs/blueprints/flare/features/pen-paths.md,
// Journey steps 1 to 5): on `-FlareSample empty` the Pen draws a four-point path, the second point dragged, closed on
// the first (Path 1); Direct Select clicks it and its four anchors show (`suite.path.anchor-0-<i>`, PathEditOverlay's
// probes); dragging the smooth anchor 30 pt moves it and its handles and no other anchor, one "Undo Move Points";
// Option-dragging its out handle leaves the in handle (a corner now); a marquee over the last two anchors and Delete
// leave two. On live services since FP-9 (slice FP-z). One shot per step, `flare-pen-<step>`.
import XCTest

final class FlarePenJourneyTests: XCTestCase {
    /// The path's four points, fractions of the stage; the second is dragged to `pull`, so it is smooth.
    private static let corners = [(0.2, 0.2), (0.5, 0.2), (0.5, 0.6), (0.2, 0.6)]
    private static let pull = (0.6, 0.15)

    @MainActor func testPenThenDragAnchor() throws {
        let flare = Journey("Flare", self, arguments: ["-FlareSample", "empty"])
        XCTAssert(flare.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        let stage = flare.element("suite.canvas")
        XCTAssert(stage.waitForExistence(timeout: 10), "no stage (suite.canvas)")
        point(0.95, 0.95, on: stage).click()

        // 1. Pen: four points, the second press-dragged, then the first again: Path 1, closed.
        choose("Pen", flare)
        for (i, (x, y)) in Self.corners.enumerated() {
            if i == 1 {
                point(x, y, on: stage).press(forDuration: 0.1, thenDragTo: point(Self.pull.0, Self.pull.1, on: stage))
            } else {
                point(x, y, on: stage).click()
            }
        }
        point(Self.corners[0].0, Self.corners[0].1, on: stage).click()
        let sidebar = flare.element("suite.sidebar")
        XCTAssert(waitFor { self.shows("Path 1", in: sidebar) }, "closing on the first anchor added no Path 1")
        flare.shot("pen-1-path")

        // 2. Direct Select, click the path's edge: it is picked and its four anchors show.
        choose("Direct Select", flare)
        point(0.35, 0.6, on: stage).click()
        let anchors = (0..<4).map { flare.element("suite.path.anchor-0-\($0)") }
        XCTAssert(waitFor { anchors.allSatisfy { $0.exists } }, "Direct Select on Path 1 shows no four anchors")
        XCTAssertFalse(flare.element("suite.path.anchor-0-4").exists, "Path 1 shows a fifth anchor")
        flare.shot("pen-2-anchors")

        // 3. Drag the smooth anchor 30 pt right: it and its handles move, the other three don't; one Undo Move Points.
        let before = anchors.map { $0.frame }, handleIn = flare.element("suite.path.handle-0-1-in").frame
        let shift = 30 * stage.frame.width / 550
        drag(center(before[1]), by: CGVector(dx: shift, dy: 0), on: stage)
        XCTAssert(waitFor { abs(anchors[1].frame.midX - before[1].midX - shift) <= 2 }, "the smooth anchor didn't move 30 pt")
        for i in [0, 2, 3] { XCTAssertEqual(anchors[i].frame, before[i], "anchor \(i) moved with the smooth one") }
        XCTAssertEqual(flare.element("suite.path.handle-0-1-in").frame.midX - handleIn.midX, shift, accuracy: 2,
                       "the smooth anchor's in handle stayed behind")
        let edit = flare.app.menuBars.firstMatch.menuBarItems["Edit"]
        edit.click()
        XCTAssert(edit.menuItems["Undo Move Points"].waitForExistence(timeout: 3), "the anchor drag isn't one Undo Move Points")
        flare.press(.escape)
        flare.shot("pen-3-anchor-dragged")

        // 4. Option-drag its out handle: the in handle stays, so the anchor is a corner now.
        let out = flare.element("suite.path.handle-0-1-out"), keptIn = flare.element("suite.path.handle-0-1-in").frame
        XCTAssert(out.waitForExistence(timeout: 5), "the smooth anchor shows no out handle")
        XCUIElement.perform(withKeyModifiers: .option) { drag(center(out.frame), by: CGVector(dx: 0, dy: shift), on: stage) }
        XCTAssertEqual(flare.element("suite.path.handle-0-1-in").frame, keptIn, "Option-dragging the out handle moved the in handle")
        XCTAssert(waitFor { anchors[1].label.contains("corner") }, "the anchor isn't a corner: \(anchors[1].label)")
        flare.shot("pen-4-broken-handle")

        // 5. Marquee the last two anchors, Delete: the path keeps two.
        point(0.1, 0.5, on: stage).press(forDuration: 0.1, thenDragTo: point(0.58, 0.7, on: stage))
        flare.press(.delete)
        XCTAssert(waitFor { !flare.element("suite.path.anchor-0-2").exists }, "Delete left more than two anchors")
        XCTAssert(anchors[0].exists && anchors[1].exists, "Delete took an anchor outside the marquee")
        flare.shot("pen-5-deleted")
    }

    /// The point at (`x`, `y`), fractions of `element`'s size.
    @MainActor private func point(_ x: Double, _ y: Double, on element: XCUIElement) -> XCUICoordinate {
        element.coordinate(withNormalizedOffset: CGVector(dx: x, dy: y))
    }

    private func center(_ frame: CGRect) -> CGPoint { CGPoint(x: frame.midX, y: frame.midY) }

    /// Presses at `start` (screen points) and drags by `offset` on `canvas`.
    @MainActor private func drag(_ start: CGPoint, by offset: CGVector, on canvas: XCUIElement) {
        let origin = canvas.coordinate(withNormalizedOffset: .zero)
        let from = origin.withOffset(CGVector(dx: start.x - canvas.frame.minX, dy: start.y - canvas.frame.minY))
        from.press(forDuration: 0.1, thenDragTo: from.withOffset(offset))
    }

    /// Clicks the palette's `title` button (`suite.tools`); it reads selected.
    @MainActor private func choose(_ title: String, _ flare: Journey) {
        let button = flare.element("suite.tools").buttons[title]
        XCTAssert(button.waitForExistence(timeout: 5), "no \(title) in the palette (suite.tools)")
        button.click()
        XCTAssert(waitFor { button.isSelected }, "clicking \(title) didn't select it")
    }

    @MainActor private func shows(_ name: String, in sidebar: XCUIElement) -> Bool {
        sidebar.descendants(matching: .any).matching(NSPredicate(format: "label == %@ OR value == %@", name, name)).firstMatch.exists
    }

    @MainActor private func waitFor(_ condition: () -> Bool) -> Bool {
        for _ in 0..<25 where !condition() { Thread.sleep(forTimeInterval: 0.2) }
        return condition()
    }
}
