// FlareJourneyTests+Draw.swift: J3's slice for draw-key-save DK-9, every drawing tool chosen by a click on its
// palette button (the letters are FlareJourneyTests' `testKeys`; #1863) and driven by the mouse. On `-FlareFixture
// empty` (one 550 × 400 scene, no layers) it chooses Rectangle and drags a rectangle (Rectangle 1), Ellipse and
// Shift-drags a square box (Ellipse 1), Pen and clicks three corners then the first (Path 1, closed), clicks two points
// and the palette's Finish Path (Path 2, open; #1862), then Rectangle and presses Escape in the middle of a drag (no
// layer), and clicks Edit > Undo: Path 2 goes and the menu reads "Redo Add Path". Clicking Select selects it again.
// Escape mid-drag needs the button held while the key goes down, which XCUITest's drags can't do, so that drag is
// posted as CGEvents. Those need the runner's post-event (Accessibility) access, so the step first fails by name
// without it, then proves the posted drag reaches the stage (a plain posted drag draws Rectangle 2, which the
// toolbar's Undo takes away) before the Escape one adds nothing (#1850). One shot per step, `flare-draw-<step>`.
// Before the first shot it checks the stage's chrome: the palette clear of the vertical ruler and the status bar's
// zoom, size and Preview data pills.
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

        // 1. Rectangle, drag a rectangle.
        choose("Rectangle", flare)
        point(0.1, 0.1, on: stage).press(forDuration: 0.1, thenDragTo: point(0.3, 0.3, on: stage))
        expectLayers(["Rectangle 1"], flare)
        flare.shot("draw-1-rectangle")

        // 2. Ellipse, Shift-drag a square box: a circle.
        choose("Ellipse", flare)
        let side = stage.frame.height * 0.2
        let start = point(0.5, 0.1, on: stage)
        XCUIElement.perform(withKeyModifiers: .shift) {
            start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: side, dy: side)))
        }
        expectLayers(["Rectangle 1", "Ellipse 1"], flare)
        flare.shot("draw-2-ellipse")

        // 3. Pen, three corners then the first: a closed path.
        choose("Pen", flare)
        for (x, y) in [(0.1, 0.6), (0.3, 0.6), (0.2, 0.85), (0.1, 0.6)] { point(x, y, on: stage).click() }
        expectLayers(["Rectangle 1", "Ellipse 1", "Path 1"], flare)
        flare.shot("draw-3-closed-path")

        // 4. Two clicks and the palette's Finish Path: an open path, with no key.
        for (x, y) in [(0.5, 0.6), (0.8, 0.8)] { point(x, y, on: stage).click() }
        let finish = flare.element("suite.tools").buttons["Finish Path"]
        XCTAssert(waitFor { finish.exists && finish.isEnabled }, "Finish Path isn't enabled after two pen clicks")
        finish.click()
        expectLayers(["Rectangle 1", "Ellipse 1", "Path 1", "Path 2"], flare)
        flare.shot("draw-4-open-path")

        // 5. Rectangle, Escape in the middle of a drag: no layer. First a plain posted drag must draw (Rectangle 2,
        // undone from the toolbar), so a drag the system blocks can't pass as a cancelled one.
        choose("Rectangle", flare)
        XCTAssert(
            CGPreflightPostEventAccess(), "the UI test runner can't post events (Accessibility): Escape mid-drag unproven")
        postedDrag(from: point(0.6, 0.2, on: stage), to: point(0.8, 0.4, on: stage), flare, escape: false)
        expectLayers(["Rectangle 1", "Ellipse 1", "Path 1", "Path 2", "Rectangle 2"], flare)
        let undoButton = flare.app.toolbars.firstMatch.buttons["flare.edit.undo"]
        XCTAssert(undoButton.waitForExistence(timeout: 5), "no Undo in the toolbar (flare.edit.undo)")
        undoButton.click()
        expectLayers(["Rectangle 1", "Ellipse 1", "Path 1", "Path 2"], flare)
        postedDrag(from: point(0.6, 0.2, on: stage), to: point(0.8, 0.4, on: stage), flare, escape: true)
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

        // 7. Select again from the palette.
        choose("Select", flare)
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

    /// Clicks the palette's `title` button (`suite.tools`); it reads selected.
    @MainActor private func choose(_ title: String, _ flare: Journey) {
        let button = flare.element("suite.tools").buttons[title]
        XCTAssert(button.waitForExistence(timeout: 5), "no \(title) in the palette (suite.tools)")
        button.click()
        XCTAssert(waitFor { button.isSelected }, "clicking \(title) didn't select it")
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

    /// Holds the button down from `start`, drags to `end`, presses Escape when `escape`, then lets go, as CGEvents.
    @MainActor private func postedDrag(
        from start: XCUICoordinate, to end: XCUICoordinate, _ flare: Journey, escape: Bool
    ) {
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
        if escape { flare.press(.escape, step: "draw-5-escape-mid-drag") }
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
