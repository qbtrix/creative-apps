// HaloJourneyTests+Transform.swift: rotate and scale a layer with handles in
// the viewer (transform HT-2, docs/blueprints/halo/features/transform.md,
// Journey steps 1-4). On `-HaloFixture keyed` (Bounce, 1920 by 1080, 24 fps)
// it selects Ball: its box shows SuiteUI's eight handles and the knob
// (`suite.handles.*`, `suite.handles.turn`). Then a Shift-drag out of the
// bottom-right corner scales Ball in proportion (Scale X and Y read the same
// in the inspector), and at 1 s, with Rotation animated, a Shift-drag of the
// knob turns it in 15° steps and keys 1 s; Undo takes the turn back in one
// step. Skipped until HT-7 runs it on the live Model: the handles take no
// drags before HT-3 and the adapter writes nothing before HT-5. Shots:
// `halo-transform-*`.
import XCTest

extension HaloJourneyTests {
    /// Journey steps 1-4: handles on the selected layer, a proportional scale, a keyed turn, one undo.
    @MainActor func testRotateAndScaleInViewer() throws {
        throw XCTSkip("waits on HT-7")
        let halo = Journey("Halo", self, arguments: ["-HaloFixture", "keyed", "-HaloWindowSize", "1000x640"])
        XCTAssert(halo.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        XCTAssert(halo.element("halo.viewer").waitForExistence(timeout: 10), "no viewer (halo.viewer)")

        // 1. Select Ball: eight handles and the knob on its box.
        let ballRow = halo.element("halo.layer.row.comp-1-layer-2")
        XCTAssert(ballRow.waitForExistence(timeout: 10), "no Ball row in the layer list")
        ballRow.click()
        XCTAssert(halo.element("suite.handles").waitForExistence(timeout: 5), "no handles (suite.handles) on Ball")
        for name in ["topLeft", "top", "topRight", "right", "bottomRight", "bottom", "bottomLeft", "left"] {
            XCTAssert(halo.element("suite.handles.\(name)").exists, "Ball's box has no \(name) handle")
        }
        XCTAssert(halo.element("suite.handles.turn").exists, "Ball's box has no knob (suite.handles.turn)")
        halo.shot("transform-handles")

        // 2. Shift-drag the bottom-right corner out: Scale X and Y read the same.
        shiftDrag(halo.element("suite.handles.bottomRight"), by: CGVector(dx: 40, dy: 10))
        let scaleX = halo.element("halo.inspector.row.scaleX"), scaleY = halo.element("halo.inspector.row.scaleY")
        XCTAssert(scaleX.waitForExistence(timeout: 5), "no Scale X row")
        XCTAssertEqual(scaleX.value as? String, scaleY.value as? String, "Scale X and Y differ after a Shift-drag")
        halo.shot("transform-scaled")

        // 3. At 1 s with Rotation animated, Shift-drag the knob: a key at 1 s.
        halo.element("halo.inspector.key.rotation").click()
        for _ in 0..<24 { halo.press(.rightArrow) }
        shiftDrag(halo.element("suite.handles.turn"), by: CGVector(dx: 60, dy: 30))
        let knob = halo.element("suite.handles.turn")
        let turn = (knob.value as? String).flatMap { Double($0.prefix { $0.isNumber || $0 == "-" }) } ?? .nan
        XCTAssertEqual(turn.truncatingRemainder(dividingBy: 15), 0, accuracy: 0.01, "the turn isn't a 15° step: \(turn)")
        let key = halo.app.descendants(matching: .any).matching(
            NSPredicate(format: "label == %@", "Animate Rotation")).firstMatch
        XCTAssertEqual(key.value as? String, "Keyed at this frame", "the turn didn't key 1 s")
        halo.shot("transform-turned")

        // 4. Undo: the turn goes in one step.
        halo.press(character: "z", .command)
        XCTAssertEqual(knob.value as? String, "0 degrees", "Undo didn't take the turn back in one step")
        halo.shot("transform-undone")
    }

    /// Holds Shift and drags `handle` by `delta` points at a hand's pace.
    @MainActor private func shiftDrag(_ handle: XCUIElement, by delta: CGVector) {
        XCTAssert(handle.waitForExistence(timeout: 5), "no \(handle.identifier) to drag")
        let from = handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        XCUIElement.perform(withKeyModifiers: .shift) {
            from.click(forDuration: 0.1, thenDragTo: from.withOffset(delta), withVelocity: 100, thenHoldForDuration: 0.1)
        }
    }
}
