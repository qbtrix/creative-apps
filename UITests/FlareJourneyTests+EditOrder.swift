// FlareJourneyTests+EditOrder.swift: stage-edit SE-5a's order journey on `-FlareSample bounce` (Background locked,
// Shadow, Ball; LAYERS lists Ball over Shadow). The first click on the empty stage at (450, 60) gives it the keyboard.
// ⌘A, Edit > Select All, selects Ball and Shadow and leaves the locked Background out (`flare.stage.selection` reads
// "2 selected"); ⇧⌘A, Deselect, clears it (no readout). Shadow picked in LAYERS, ⌘], Object > Bring Forward, lists
// it over Ball as one "Bring Forward" step, and ⌘[, Send Backward, puts it back. Escape in the middle of a marquee
// round Ball and Shadow leaves nothing selected. Escape mid-drag needs the button held while the key goes down, which
// XCUITest's drags can't do, so that marquee is posted as CGEvents, after a plain posted marquee proves they reach the
// stage (as J3's step 5, #1850). A scene point is the artboard's top-left corner plus the point at its fit scale.
import CoreGraphics
import XCTest

final class FlareEditOrderJourneys: XCTestCase {
    private static let sceneWidth = 550.0

    /// ⌘A selects every unlocked item, ⇧⌘A none; ⌘] and ⌘[ move Shadow up and back; Escape drops a marquee.
    @MainActor func testSelectAllOrderAndEscape() {
        let flare = Journey("Flare", self, arguments: ["-FlareSample", "bounce"])
        XCTAssert(flare.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        let canvas = flare.element("suite.canvas")
        XCTAssert(canvas.waitForExistence(timeout: 10), "no stage (suite.canvas)")
        let readout = flare.element("flare.stage.selection")
        point(450, 60, on: canvas).click()

        // 1. ⌘A: Ball and Shadow, not the locked Background.
        flare.press(character: "a", .command)
        XCTAssert(waitFor { readout.exists && readout.label.hasPrefix("2 selected") },
                  "⌘A didn't select Ball and Shadow alone: \(readout.exists ? readout.label : "no selection")")
        flare.shot("edit-order-1-select-all")

        // 2. ⇧⌘A: nothing selected, no readout.
        flare.press(character: "a", [.command, .shift])
        XCTAssert(readout.waitForNonExistence(timeout: 5), "⇧⌘A kept a selection: \(readout.label)")
        flare.shot("edit-order-2-deselect")

        // 3. Shadow, ⌘]: Shadow lists over Ball, one Bring Forward step.
        XCTAssert(above("Ball", "Shadow", flare), "LAYERS doesn't list Ball over Shadow on open")
        flare.pickSidebarRow("Shadow")
        flare.press(character: "]", .command)
        XCTAssert(waitFor { above("Shadow", "Ball", flare) }, "⌘] didn't list Shadow over Ball")
        expectUndo("Undo Bring Forward", flare)
        flare.shot("edit-order-3-forward")

        // 4. ⌘[: Shadow back under Ball.
        flare.press(character: "[", .command)
        XCTAssert(waitFor { above("Ball", "Shadow", flare) }, "⌘[ didn't put Shadow back under Ball")
        flare.shot("edit-order-4-backward")

        // 5. Escape mid-marquee from (40, 60) to (330, 370): nothing selected. A plain posted marquee selects both first.
        point(450, 60, on: canvas).click()
        XCTAssert(readout.waitForNonExistence(timeout: 5), "the empty click kept a selection: \(readout.label)")
        XCTAssert(
            CGPreflightPostEventAccess(), "the UI test runner can't post events (Accessibility): Escape mid-marquee unproven")
        postedDrag(from: point(40, 60, on: canvas), to: point(330, 370, on: canvas), flare, escape: false)
        XCTAssert(waitFor { readout.exists && readout.label.hasPrefix("2 selected") },
                  "the posted marquee didn't select Ball and Shadow")
        point(450, 60, on: canvas).click()
        XCTAssert(readout.waitForNonExistence(timeout: 5), "the empty click kept a selection: \(readout.label)")
        postedDrag(from: point(40, 60, on: canvas), to: point(330, 370, on: canvas), flare, escape: true)
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssertFalse(readout.exists, "Escape mid-marquee left a selection: \(readout.label)")
        flare.shot("edit-order-5-escape")
    }

    /// LAYERS lists `upper`'s row over `lower`'s.
    @MainActor private func above(_ upper: String, _ lower: String, _ flare: Journey) -> Bool {
        let top = flare.sidebarRow(upper), bottom = flare.sidebarRow(lower)
        guard top.waitForExistence(timeout: 5), bottom.waitForExistence(timeout: 5) else { return false }
        return top.frame.minY < bottom.frame.minY
    }

    /// The Edit menu's Undo item reads `title`, the step just made.
    @MainActor private func expectUndo(_ title: String, _ flare: Journey) {
        let menu = flare.app.menuBars.firstMatch.menuBarItems["Edit"]
        XCTAssert(menu.waitForExistence(timeout: 5), "no Edit menu")
        menu.click()
        XCTAssert(menu.menuItems[title].waitForExistence(timeout: 3), "the Edit menu has no \(title)")
        flare.press(.escape)
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
        if escape { flare.press(.escape, step: "edit-order-5-escape-mid-marquee") }
        post(.leftMouseUp, b)
    }

    @MainActor private func point(_ x: Double, _ y: Double, on canvas: XCUIElement) -> XCUICoordinate {
        let scale = canvas.frame.width / Self.sceneWidth
        return canvas.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x * scale, dy: y * scale))
    }

    /// Polls `condition` for up to five seconds.
    @MainActor private func waitFor(_ condition: () -> Bool) -> Bool {
        for _ in 0..<25 where !condition() { Thread.sleep(forTimeInterval: 0.2) }
        return condition()
    }
}
