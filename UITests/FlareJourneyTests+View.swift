// FlareJourneyTests+View.swift: J14 (stage-edit SE-2) on `-FlareSample bounce`. The zoom reads off the hidden
// `flare.stage.zoom` ("Fit", "200%"; the pill's words don't reach XCUITest, #1452); each guide is
// `flare.stage.guide.<i>` with its readout ("y 300") as the label. Ruler numbers are drawn, not elements, so the pan
// is read off the artboard (`suite.canvas`) moving under the rulers. Positions land within a point of the target:
// a drag is placed in screen points at the fit's scale and guides snap to whole scene points.
import XCTest

final class FlareViewJourneys: XCTestCase {
    private static let sceneHeight = 400.0

    @MainActor func testZoomPanAndGuides() {
        let flare = Journey("Flare", self, arguments: ["-FlareSample", "bounce"])
        XCTAssert(flare.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        let canvas = flare.element("suite.canvas"), zoom = flare.element("flare.stage.zoom")
        let corner = flare.element("suite.canvas.rulerUnit"), guide = flare.element("flare.stage.guide.0")
        XCTAssert(canvas.waitForExistence(timeout: 10) && zoom.waitForExistence(timeout: 5), "no stage or zoom readout")
        XCTAssertEqual(zoom.label, "Fit", "the stage didn't open fitted")

        // 1. ⌘+ twice from the fit: 200%. A click on the empty stage first gives it the keyboard.
        at(canvas.frame.maxX - 20, canvas.frame.minY + 20, flare).click()
        flare.press(character: "+", .command)
        flare.press(character: "+", .command, step: "view-1-zoom")
        XCTAssert(waitFor { zoom.label == "200%" }, "⌘+ twice from the fit reads \(zoom.label), not 200%")

        // 2. Space-drag 100 pt left: the artboard (and the rulers' origin with it) moves left, the zoom stays.
        let before = canvas.frame.minX, pane = flare.element("flare.stagePane").frame
        holdingSpace {
            at(pane.midX, pane.midY - 40, flare).press(forDuration: 0.1, thenDragTo: at(pane.midX - 100, pane.midY - 40, flare))
        }
        XCTAssert(waitFor { abs(canvas.frame.minX - (before - 100)) < 12 }, "Space-drag moved the artboard from x \(before) to \(canvas.frame.minX)")
        XCTAssertEqual(zoom.label, "200%", "Space-drag changed the zoom")
        flare.shot("view-2-pan")

        // 3. ⌘0: back to the fit.
        flare.press(character: "0", .command, step: "view-3-fit")
        XCTAssert(waitFor { zoom.label == "Fit" }, "⌘0 left the zoom at \(zoom.label)")

        // 4. Drag from the top ruler down to scene y 300: guide 0 reads "y 300".
        let scale = canvas.frame.height / Self.sceneHeight
        at(canvas.frame.midX, corner.frame.midY, flare)
            .press(forDuration: 0.1, thenDragTo: at(canvas.frame.midX, canvas.frame.minY + 300 * scale, flare))
        XCTAssert(guide.waitForExistence(timeout: 5), "the drag out of the top ruler placed no guide")
        let first = position(guide)
        XCTAssert(first.map { abs($0 - 300) <= 1 } == true, "the guide reads \(guide.label), not y 300")
        flare.shot("view-4-guide")

        // 5. Drag the guide 20 scene points down: "y 320", one Move Guide step.
        let line = guide.frame.midY
        at(canvas.frame.minX + 30, line, flare).press(forDuration: 0.1, thenDragTo: at(canvas.frame.minX + 30, line + 20 * scale, flare))
        XCTAssert(waitFor { position(guide).map { abs($0 - 320) <= 1 } == true }, "the moved guide reads \(guide.label), not y 320")
        XCTAssert(flare.app.menuBars.menuItems["Undo Move Guide"].waitForExistence(timeout: 5), "the guide drag made no one Move Guide step")
        flare.shot("view-5-moved")

        // 6. Drag it back onto the top ruler: gone.
        let moved = guide.frame.midY
        at(canvas.frame.minX + 30, moved, flare).press(forDuration: 0.1, thenDragTo: at(canvas.frame.minX + 30, corner.frame.midY, flare))
        XCTAssert(guide.waitForNonExistence(timeout: 5), "the guide dropped on the ruler stayed: \(guide.label)")
        flare.shot("view-6-removed")

        // 7. ⌘R hides the rulers (their unit corner goes with them).
        flare.press(character: "r", .command, step: "view-7-norulers")
        XCTAssert(corner.waitForNonExistence(timeout: 5), "⌘R left the rulers showing")
    }

    /// "y 300" as 300; nil for any other label.
    @MainActor private func position(_ guide: XCUIElement) -> Double? {
        guard guide.exists else { return nil }
        let parts = guide.label.split(separator: " ")
        return parts.count == 2 && (parts[0] == "y" || parts[0] == "x") ? Double(parts[1]) : nil
    }

    /// The screen point (x, y) as a coordinate in the window.
    @MainActor private func at(_ x: Double, _ y: Double, _ flare: Journey) -> XCUICoordinate {
        let window = flare.app.windows.firstMatch
        return window.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x - window.frame.minX, dy: y - window.frame.minY))
    }

    /// Runs `body` with Space held down, posted as CGEvents (virtual key 49).
    @MainActor private func holdingSpace(_ body: () -> Void) {
        CGEvent(keyboardEventSource: nil, virtualKey: 49, keyDown: true)?.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.2)
        body()
        CGEvent(keyboardEventSource: nil, virtualKey: 49, keyDown: false)?.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.2)
    }

    @MainActor private func waitFor(_ condition: () -> Bool) -> Bool {
        for _ in 0..<25 where !condition() { Thread.sleep(forTimeInterval: 0.2) }
        return condition()
    }
}
