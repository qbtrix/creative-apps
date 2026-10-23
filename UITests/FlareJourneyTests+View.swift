// FlareJourneyTests+View.swift: J14 (stage-edit SE-2) on `-FlareSample bounce`. The zoom reads off the hidden
// `flare.stage.zoom` (#1452); guide i is `flare.stage.guide.<i>`, labelled "y 300". Ruler numbers aren't elements, so
// the pan is read off the artboard (`suite.canvas`). Guides land within a point: drags are placed in screen points.
import XCTest

final class FlareViewJourneys: XCTestCase {
    @MainActor func testZoomPanAndGuides() {
        let flare = Journey("Flare", self, arguments: ["-FlareSample", "bounce"])
        let canvas = flare.element("suite.canvas"), zoom = flare.element("flare.stage.zoom")
        let corner = flare.element("suite.canvas.rulerUnit"), guide = flare.element("flare.stage.guide.0")
        XCTAssert(canvas.waitForExistence(timeout: 30) && zoom.waitForExistence(timeout: 5), "no stage or zoom readout")
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
        flare.press(character: "0", .command, step: "view-3-fit")
        XCTAssert(waitFor { zoom.label == "Fit" }, "⌘0 left the zoom at \(zoom.label)")

        // 4. Drag from the top ruler down to scene y 300: guide 0 reads "y 300".
        let scale = canvas.frame.height / 400  // bounce is 400 points tall
        at(canvas.frame.midX, corner.frame.midY, flare)
            .press(forDuration: 0.1, thenDragTo: at(canvas.frame.midX, canvas.frame.minY + 300 * scale, flare))
        XCTAssert(guide.waitForExistence(timeout: 5), "the drag out of the top ruler placed no guide")
        XCTAssert(position(guide).map { abs($0 - 300) <= 1 } == true, "the guide reads \(guide.label), not y 300")
        flare.shot("view-4-guide")

        // 5. Drag the guide 20 scene points down: "y 320", one Move Guide step.
        let line = guide.frame.midY, x = canvas.frame.minX + 30
        at(x, line, flare).press(forDuration: 0.1, thenDragTo: at(x, line + 20 * scale, flare))
        XCTAssert(waitFor { position(guide).map { abs($0 - 320) <= 1 } == true }, "the moved guide reads \(guide.label), not y 320")
        XCTAssert(flare.app.menuBars.menuItems["Undo Move Guide"].waitForExistence(timeout: 5), "the guide drag made no one Move Guide step")
        flare.shot("view-5-moved")

        at(x, guide.frame.midY, flare).press(forDuration: 0.1, thenDragTo: at(x, corner.frame.midY, flare))
        XCTAssert(guide.waitForNonExistence(timeout: 5), "the guide dropped on the ruler stayed: \(guide.label)")
        flare.shot("view-6-removed")

        flare.press(character: "r", .command, step: "view-7-norulers")
        XCTAssert(corner.waitForNonExistence(timeout: 5), "⌘R left the rulers showing")
    }

    @MainActor private func position(_ guide: XCUIElement) -> Double? {
        guide.exists && guide.label.hasPrefix("y ") ? Double(guide.label.dropFirst(2)) : nil
    }

    @MainActor private func at(_ x: Double, _ y: Double, _ flare: Journey) -> XCUICoordinate {
        let window = flare.app.windows.firstMatch
        return window.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x - window.frame.minX, dy: y - window.frame.minY))
    }

    @MainActor private func holdingSpace(_ body: () -> Void) {
        for down in [true, false] {
            if !down { body() }
            CGEvent(keyboardEventSource: nil, virtualKey: 49, keyDown: down)?.post(tap: .cghidEventTap)
            Thread.sleep(forTimeInterval: 0.2)
        }
    }

    @MainActor private func waitFor(_ condition: () -> Bool) -> Bool {
        for _ in 0..<25 where !condition() { Thread.sleep(forTimeInterval: 0.2) }
        return condition()
    }
}
