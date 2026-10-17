// FlareJourneyTests+Draw.swift: J3's slice for draw-key-save DK-9, every drawing tool driven by its key and the
// mouse. On `-FlareFixture empty` (one 550 × 400 scene, no layers) it presses R and drags a rectangle (Rectangle 1),
// E and Shift-drags a square box (Ellipse 1), P and clicks three corners then the first (Path 1, closed), clicks two
// points and presses Return (Path 2, open), then R and presses Escape in the middle of a drag (no layer), and clicks
// Edit > Undo: Path 2 goes and the menu reads "Redo Add Path". V selects Select again. Each tool letter must select
// its palette button. Escape mid-drag needs the button held while the key goes down, which XCUITest's drags can't
// do, so that drag is posted as CGEvents. One shot per step, `flare-draw-<step>`. Before the first shot it checks the
// stage's chrome: the palette clear of the vertical ruler and the status bar's zoom, size and Preview data pills.
import CoreGraphics
import XCTest

final class FlareDrawJourneys: XCTestCase {
    /// R, E, P draw a rectangle, an ellipse and two paths; Escape mid-drag adds nothing; Undo removes only Path 2.
    @MainActor func testDrawShapesWithEachTool() {
        let flare = Journey("Flare", self, arguments: ["-FlareFixture", "empty"])
        XCTAssert(flare.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        let stage = flare.element("suite.canvas")
        XCTAssert(stage.waitForExistence(timeout: 10), "no stage (suite.canvas)")
        // A click with Select on the empty stage only gives it the keyboard.
        point(0.95, 0.95, on: stage).click()
        expectStageChrome(flare)
        flare.shot("draw-0-open")

        // 1. R, drag a rectangle.
        choose("r", "Rectangle", flare)
        point(0.1, 0.1, on: stage).press(forDuration: 0.1, thenDragTo: point(0.3, 0.3, on: stage))
        expectLayers(["Rectangle 1"], flare)
        flare.shot("draw-1-rectangle")

        // 2. E, Shift-drag a square box: a circle.
        choose("e", "Ellipse", flare)
        let side = stage.frame.height * 0.2
        let start = point(0.5, 0.1, on: stage)
        XCUIElement.perform(withKeyModifiers: .shift) {
            start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: side, dy: side)))
        }
        expectLayers(["Rectangle 1", "Ellipse 1"], flare)
        flare.shot("draw-2-ellipse")

        // 3. P, three corners then the first: a closed path.
        choose("p", "Pen", flare)
        for (x, y) in [(0.1, 0.6), (0.3, 0.6), (0.2, 0.85), (0.1, 0.6)] { point(x, y, on: stage).click() }
        expectLayers(["Rectangle 1", "Ellipse 1", "Path 1"], flare)
        flare.shot("draw-3-closed-path")

        // 4. Two clicks and Return: an open path.
        for (x, y) in [(0.5, 0.6), (0.8, 0.8)] { point(x, y, on: stage).click() }
        flare.press(.return)
        expectLayers(["Rectangle 1", "Ellipse 1", "Path 1", "Path 2"], flare)
        flare.shot("draw-4-open-path")

        // 5. R, Escape in the middle of a drag: no layer.
        choose("r", "Rectangle", flare)
        dragWithEscape(from: point(0.6, 0.2, on: stage), to: point(0.8, 0.4, on: stage), flare)
        Thread.sleep(forTimeInterval: 0.5)
        expectLayers(["Rectangle 1", "Ellipse 1", "Path 1", "Path 2"], flare)
        flare.shot("draw-5-escape")

        // 6. Edit > Undo: only Path 2 goes, and Redo names it.
        let edit = flare.app.menuBars.firstMatch.menuBarItems["Edit"]
        XCTAssert(edit.waitForExistence(timeout: 5), "no Edit menu")
        edit.click()
        let undo = edit.menus.firstMatch.menuItems["Undo Add Path"]
        XCTAssert(undo.waitForExistence(timeout: 3), "the Edit menu has no Undo Add Path")
        undo.click()
        expectLayers(["Rectangle 1", "Ellipse 1", "Path 1"], flare)
        edit.click()
        let redo = edit.menus.firstMatch.menuItems["Redo Add Path"]
        XCTAssert(redo.waitForExistence(timeout: 3), "after Undo the Edit menu has no Redo Add Path")
        flare.shot("draw-6-undo", screen: true)
        flare.press(.escape)

        // 7. V: Select again.
        point(0.95, 0.95, on: stage).click()
        choose("v", "Select", flare)
        flare.shot("draw-7-select")
    }

    /// The stage's chrome on the 550 × 400 fixture: the palette starts right of the vertical ruler (#1857), and a
    /// status bar under the stage shows the zoom percent, "550 × 400 pt" and "Preview data", all in the window (#1854).
    @MainActor private func expectStageChrome(_ flare: Journey) {
        let pane = flare.element("flare.stagePane")
        XCTAssert(pane.waitForExistence(timeout: 5), "no stage pane (flare.stagePane)")
        let palette = flare.element("suite.tools")
        XCTAssert(palette.waitForExistence(timeout: 5), "no palette (suite.tools)")
        let rulerMaxX = pane.frame.minX + 20  // SuiteSize.ruler
        XCTAssertGreaterThanOrEqual(
            palette.frame.minX, rulerMaxX, "the palette \(palette.frame) covers the vertical ruler (ends at \(rulerMaxX))")
        let window = flare.app.windows.firstMatch.frame
        let zoom = pane.staticTexts.matching(NSPredicate(format: "label MATCHES 'Zoom [0-9]+%'")).firstMatch
        let size = pane.staticTexts["550 × 400 pt"]
        let preview = flare.element("flare.status.preview")
        for (pill, name) in [(zoom, "zoom percent"), (size, "550 × 400 pt"), (preview, "Preview data")] {
            XCTAssert(pill.waitForExistence(timeout: 5), "the stage's status bar shows no \(name) pill")
            XCTAssert(window.contains(pill.frame), "the \(name) pill \(pill.frame) is outside the window \(window)")
            XCTAssertGreaterThanOrEqual(pill.frame.minY, stage(flare).frame.maxY, "the \(name) pill isn't under the stage")
        }
    }

    @MainActor private func stage(_ flare: Journey) -> XCUIElement { flare.element("suite.canvas") }

    /// The point at (`x`, `y`), fractions of `element`'s size.
    @MainActor private func point(_ x: Double, _ y: Double, on element: XCUIElement) -> XCUICoordinate {
        element.coordinate(withNormalizedOffset: CGVector(dx: x, dy: y))
    }

    /// Types `key` on the stage; the palette's `title` button reads selected.
    @MainActor private func choose(_ key: String, _ title: String, _ flare: Journey) {
        flare.press(character: key)
        let button = flare.element("suite.tools").buttons[title]
        XCTAssert(button.waitForExistence(timeout: 5), "no \(title) in the palette (suite.tools)")
        XCTAssert(waitFor { button.isSelected }, "\(key.uppercased()) didn't select \(title)")
    }

    /// The sidebar names exactly the layers in `names` among the shapes this journey draws.
    @MainActor private func expectLayers(_ names: [String], _ flare: Journey) {
        let sidebar = flare.element("suite.sidebar")
        let drawn = ["Rectangle 1", "Rectangle 2", "Ellipse 1", "Path 1", "Path 2", "Path 3"]
        func shown(_ name: String) -> Bool {
            sidebar.descendants(matching: .any)
                .matching(NSPredicate(format: "label == %@ OR value == %@", name, name)).firstMatch.exists
        }
        XCTAssert(
            waitFor { drawn.allSatisfy { shown($0) == names.contains($0) } },
            "the sidebar shows \(drawn.filter(shown)), not \(names)")
    }

    /// Holds the button down from `start`, drags to `end`, presses Escape, then lets go, as CGEvents.
    @MainActor private func dragWithEscape(from start: XCUICoordinate, to end: XCUICoordinate, _ flare: Journey) {
        let a = start.screenPoint, b = end.screenPoint
        func post(_ type: CGEventType, _ at: CGPoint) {
            CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: at, mouseButton: .left)?
                .post(tap: .cghidEventTap)
            Thread.sleep(forTimeInterval: 0.05)
        }
        post(.leftMouseDown, a)
        for step in 1...10 {
            let t = Double(step) / 10
            post(.leftMouseDragged, CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t))
        }
        flare.press(.escape, step: "draw-5-escape-mid-drag")
        post(.leftMouseUp, b)
    }

    /// Polls `condition` for up to five seconds.
    @MainActor private func waitFor(_ condition: () -> Bool) -> Bool {
        for _ in 0..<25 {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return condition()
    }
}
