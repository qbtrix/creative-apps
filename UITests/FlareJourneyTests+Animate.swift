// FlareJourneyTests+Animate.swift: J6's slice for draw-key-save DK-14, drag
// to key, driven with the mouse. On `-FlareFixture bounce` (Ball keyed at 0,
// 12, 24, 36 and 47; Shadow a flat ellipse at (275, 352) with no keys) it
// turns Auto-key on from the toolbar and finds the recording ring's dot
// (`flare.recording`), drags the playhead to 30 on the Frame Ruler (as
// FlareTimelineJourneys does), chooses Select from the palette and drags Ball
// 100 scene points right: Ball's lane gains a key at 30. Edit > Undo takes
// away only that key. Then Auto-key off (the ring goes), Go to Start, and a
// drag of Shadow 50 points right: back at 30, a click where Shadow was hits
// nothing and a click 50 points right selects it, and Shadow's lane holds
// only the key at 0 the move wrote. SuiteWindow drops Auto-key's selected
// state (#1621), so the ring stands in for it. A lane's keys are its key
// children ("Key at frame 24, linear"), else its value ("5 keyframes at 0,
// 12, ..."). A scene point is the artboard's (`suite.canvas`) top-left corner
// plus the point at the artboard's fit scale. One shot per step,
// `flare-animate-<step>`.
import XCTest

final class FlareAnimateJourneys: XCTestCase {
    private static let lastFrame = 47.0, sceneWidth = 550.0
    private static let ballKeys: Set<Int> = [0, 12, 24, 36, 47]

    /// Auto-key on; at 30 drag Ball: a key at 30, one Undo removes it; Auto-key off; at 0 drag Shadow: no key at 30.
    @MainActor func testMoveAndKeyByDrag() {
        let flare = Journey("Flare", self, arguments: ["-FlareFixture", "bounce"])
        XCTAssert(flare.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        let canvas = flare.element("suite.canvas")
        XCTAssert(canvas.waitForExistence(timeout: 10), "no stage (suite.canvas)")
        XCTAssertEqual(keys("Ball", flare), Self.ballKeys, "Ball's lane doesn't read the fixture's keys")
        XCTAssertEqual(keys("Shadow", flare), [], "Shadow's lane has keys before any edit")
        flare.shot("animate-0-open")

        // 1. Auto-key on: the recording ring shows.
        let autoKey = flare.app.toolbars.buttons["flare.timeline.toggleAutoKey"]
        XCTAssert(autoKey.waitForExistence(timeout: 5), "no Auto-key in the toolbar")
        autoKey.click()
        let ring = flare.element("flare.recording")
        XCTAssert(ring.waitForExistence(timeout: 5), "no recording ring (flare.recording) with Auto-key on")
        flare.shot("animate-1-auto-key-on")

        // 2. Frame 30 on the ruler; Select from the palette.
        scrub(to: 30, flare)
        let select = flare.element("suite.tools").buttons["Select"]
        XCTAssert(select.waitForExistence(timeout: 5), "no Select in the palette")
        select.click()
        flare.shot("animate-2-frame-30")

        // 3. Drag Ball (at (322.5, 230) on frame 30) 100 points right: a key at 30 on Ball's lane.
        drag(from: (322.5, 230), by: 100, on: canvas)
        XCTAssert(waitFor { keys("Ball", flare) == Self.ballKeys.union([30]) },
                  "Ball's lane reads \(keys("Ball", flare).sorted()) after the drag, not a key added at 30")
        flare.shot("animate-3-keyed")

        // 4. Edit > Undo: only that key goes.
        flare.app.menuBars.menuBarItems["Edit"].click()
        let undo = flare.app.menuBars.menuItems.matching(NSPredicate(format: "title BEGINSWITH 'Undo'")).firstMatch
        XCTAssert(undo.waitForExistence(timeout: 5), "the Edit menu has no Undo")
        undo.click()
        XCTAssert(waitFor { keys("Ball", flare) == Self.ballKeys },
                  "Ball's lane reads \(keys("Ball", flare).sorted()) after one Undo")
        flare.shot("animate-4-undo")

        // 5. Auto-key off: the ring goes; Go to Start; drag Shadow 50 points right.
        autoKey.click()
        XCTAssert(ring.waitForNonExistence(timeout: 5), "the recording ring stayed with Auto-key off")
        flare.element("flare.timeline.goToStart").click()
        XCTAssert(waitFor { frame(flare) == 0 }, "Go to Start gave \(String(describing: frame(flare)))")
        drag(from: (275, 352), by: 50, on: canvas)
        XCTAssert(waitFor { keys("Shadow", flare) == [0] },
                  "Shadow's lane reads \(keys("Shadow", flare).sorted()) after a drag with Auto-key off")
        flare.shot("animate-5-shadow-moved")

        // 6. At 30 Shadow sits 50 points right too: its old center hits nothing, the new one selects it.
        scrub(to: 30, flare)
        let shadow = flare.element("flare.timeline").buttons.matching(
            NSPredicate(format: "label == 'Shadow'")).firstMatch
        XCTAssert(shadow.waitForExistence(timeout: 5), "no Shadow track in the timeline")
        point(270, 352, on: canvas).click()
        XCTAssert(waitFor { !shadow.isSelected }, "a click where Shadow was still hits Shadow at frame 30")
        point(325, 352, on: canvas).click()
        XCTAssert(waitFor { shadow.isSelected }, "a click 50 points right of Shadow's old place misses it at 30")
        XCTAssertFalse(keys("Shadow", flare).contains(30), "a drag with Auto-key off keyed Shadow at 30")
        flare.shot("animate-6-shadow-at-30")
    }

    /// The frames of the keys on the lane named `name`: its key children, else the frames its value lists.
    @MainActor private func keys(_ name: String, _ flare: Journey) -> Set<Int> {
        let lanes = flare.element("flare.timeline").descendants(matching: .any).matching(
            NSPredicate(format: "label == %@ AND elementType != %d", name, XCUIElement.ElementType.button.rawValue))
        var frames = Set<Int>()
        for lane in lanes.allElementsBoundByIndex {
            let children = lane.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH 'Key at frame '"))
            for key in children.allElementsBoundByIndex {
                if let frame = Int(key.label.dropFirst("Key at frame ".count).prefix { $0.isNumber }) { frames.insert(frame) }
            }
            guard frames.isEmpty, let value = lane.value as? String,
                  let listed = value.range(of: "keyframes at ") ?? value.range(of: "keyframe at ") else { continue }
            for part in value[listed.upperBound...].split(separator: ",") {
                if let frame = Int(part.trimmingCharacters(in: .whitespaces)) { frames.insert(frame) }
            }
        }
        return frames
    }

    /// Drags on the stage from the scene point `start` `dx` scene points right.
    @MainActor private func drag(from start: (Double, Double), by dx: Double, on canvas: XCUIElement) {
        point(start.0, start.1, on: canvas)
            .press(forDuration: 0.1, thenDragTo: point(start.0 + dx, start.1, on: canvas))
    }

    /// The screen point of the scene point (`x`, `y`): the artboard's corner plus the point at its fit scale.
    @MainActor private func point(_ x: Double, _ y: Double, on canvas: XCUIElement) -> XCUICoordinate {
        let scale = canvas.frame.width / Self.sceneWidth
        return canvas.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x * scale, dy: y * scale))
    }

    /// Drags the playhead on the Frame Ruler from 0 to `target`.
    @MainActor private func scrub(to target: Int, _ flare: Journey) {
        let ruler = flare.app.descendants(matching: .any).matching(NSPredicate(format: "label == 'Frame Ruler'")).firstMatch
        XCTAssert(ruler.waitForExistence(timeout: 5), "no Frame Ruler in the timeline")
        ruler.coordinate(withNormalizedOffset: .zero).withOffset(x(frame: 0, ruler))
            .press(forDuration: 0.1, thenDragTo: ruler.coordinate(withNormalizedOffset: .zero).withOffset(x(frame: target, ruler)))
        XCTAssert(waitFor { frame(flare) == target }, "the frame is \(String(describing: frame(flare))) after the scrub")
    }

    /// The frame the readout names ("30 / 48" is 30); nil when it names none.
    @MainActor private func frame(_ flare: Journey) -> Int? {
        let readout = flare.element("flare.timeline.frame")
        guard readout.exists else { return nil }
        return Int(readout.label.prefix { $0.isNumber })
    }

    /// The offset of `frame` from the ruler's top-left corner, at the ruler's middle.
    @MainActor private func x(frame: Int, _ ruler: XCUIElement) -> CGVector {
        let frameWidth = (ruler.frame.width - 24) / Self.lastFrame
        return CGVector(dx: 8 + Double(frame) * frameWidth, dy: ruler.frame.height / 2)
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
