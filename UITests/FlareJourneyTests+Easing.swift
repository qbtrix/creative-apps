// FlareJourneyTests+Easing.swift: J12 (IT-8, #378), the easing journey through
// TIMING's Span picker, Easing button and popover on Keyed Ball: TIMING reads
// "Ease Out", then "Custom"; the numbers are read from where the curve draws
// the handles (XCUITest gets no value from the rows); each edit is one ⌘Z.
import XCTest

extension FlareJourneyTests {
    @MainActor func testEasingPresetAndCurve() {
        let flare = Journey("Flare", self, arguments: ["-SuiteWindowSize", "1024x768"])
        flare.openSample("Keyed Ball")
        let span = flare.element("flare.inspector.span")
        XCTAssert(span.waitForExistence(timeout: 10), "TIMING has no Span picker")
        expectEasingGeometry(flare)
        span.click()
        let item = flare.app.menuItems["x frames 0 → 24"]
        XCTAssert(item.waitForExistence(timeout: 5), "Span doesn't list x frames 0 → 24")
        item.click()
        expectTiming(reads: "Linear", flare)
        flare.shot("easing-span")
        // 1. The Easing button opens the popover; Ease Out lands on the span.
        showPopover(flare)
        expectPresetsFit(flare)
        flare.app.popovers.firstMatch.buttons["Ease Out"].click()
        flare.shot("easing-preset")
        XCTAssertEqual(activePreset(flare), "Ease Out", "Ease Out isn't the active preset")
        expectTiming(reads: "Ease Out", flare)
        expectHandle(1, at: CGPoint(x: 0, y: 0), flare, "Ease Out's handle 1 isn't at (0, 0)")
        expectHandle(2, at: CGPoint(x: 0.58, y: 1), flare, "Ease Out's handle 2 isn't at (0.58, 1)")
        // 2. A drag of handle 1 makes the curve Custom and leaves handle 2.
        let well = flare.element("flare.easing")
        let frame = well.frame
        func at(_ x: CGFloat, _ y: CGFloat) -> XCUICoordinate {
            well.coordinate(withNormalizedOffset: .zero).withOffset(
                CGVector(dx: 12 + x * (frame.width - 24), dy: 12 + (1.25 - y) / 1.5 * (frame.height - 24)))
        }
        at(0, 0).press(forDuration: 0.2, thenDragTo: at(0.25, 0.45))
        flare.shot("easing-drag")
        XCTAssertNil(activePreset(flare), "a preset is still active after the drag")
        expectTiming(reads: "Custom", flare)
        expectHandle(1, at: CGPoint(x: 0.25, y: 0.45), flare, "handle 1 didn't follow the drag", accuracy: 0.03)
        expectHandle(2, at: CGPoint(x: 0.58, y: 1), flare, "the drag moved handle 2")
        let dragged = handle(1, flare)
        // 3. Click X1, Escape its typing field; each Right press adds 0.01.
        flare.element("flare.easing.row.x1").click()
        flare.press(.escape)
        for _ in 0..<5 { flare.app.typeKey(.rightArrow, modifierFlags: []) }
        flare.shot("easing-nudge")
        expectHandle(1, at: CGPoint(x: dragged.x + 0.05, y: dragged.y), flare, "five Right presses didn't add 0.05 to x")
        // 4. Five nudges, the drag and the preset are seven ⌘Z, each named for the edit.
        flare.app.menuBars.menuBarItems["Edit"].click()
        XCTAssert(
            flare.app.menuBars.menuItems["Undo Set Keyframe Easing"].waitForExistence(timeout: 5),
            "Edit > Undo isn't named Undo Set Keyframe Easing")
        flare.shot("easing-undo-menu", screen: true)
        flare.press(.escape)
        for _ in 1...5 { flare.press(character: "z", .command) }
        showPopover(flare)
        expectHandle(1, at: dragged, flare, "five ⌘Z didn't undo the five nudges", accuracy: 0.03)
        flare.press(character: "z", .command)
        expectTiming(reads: "Ease Out", flare)
        expectHandle(1, at: CGPoint(x: 0, y: 0), flare, "⌘Z didn't undo the drag")
        flare.press(character: "z", .command, step: "easing-undo")
        expectTiming(reads: "Linear", flare)
    }

    /// Opens the easing popover from TIMING's Easing button, unless it is open.
    @MainActor private func showPopover(_ flare: Journey) {
        guard !flare.app.popovers.firstMatch.exists else { return }
        flare.element("flare.inspector.easing").click()
        XCTAssert(flare.app.popovers.firstMatch.waitForExistence(timeout: 5), "the Easing button opened no popover")
    }

    @MainActor private func expectTiming(reads title: String, _ flare: Journey) {
        let button = flare.element("flare.inspector.easing")
        let reads = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", title), object: button)
        XCTAssertEqual(XCTWaiter.wait(for: [reads], timeout: 5), .completed, "TIMING reads \(button.label), not \(title)")
    }
}
