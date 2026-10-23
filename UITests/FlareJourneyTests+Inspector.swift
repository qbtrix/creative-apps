// FlareJourneyTests+Inspector.swift: J7 (inspector-timeline IT-4). On
// `-FlareSample bounce` it selects Ball, animates Rotation at 0, finds it
// Animated at 20, drags the bar there (keyed, a key at 20 on Ball's lane),
// steps it →, →, Shift-→ (+1, +1, +10), then Select All: X reads Mixed and
// its stopwatch Not animated. A stopwatch is found by label ("Animate
// Rotation"); its value is the key state. Shots are `flare-j7-<step>`.
// FJ-BK (brush-keys BK-12): with Auto-key on at 12, a click on Shadow, then 3:
// Opacity reads 30% and Shadow's lane has a key at 12. Shots `flare-bk-<step>`.
import XCTest

final class FlareInspectorJourneys: XCTestCase {
    private static let lastFrame = 47.0, sceneWidth = 550.0

    /// J7: animate, scrub, drag and step Rotation on Ball; Ball and Shadow read X as Mixed.
    @MainActor func testInspectorKeysTransform() {
        let flare = Journey("Flare", self, arguments: ["-FlareSample", "bounce"])
        XCTAssert(flare.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")

        // 1. Select Ball from its timeline track: the TRANSFORM rows show.
        let ball = flare.element("flare.timeline").buttons.matching(
            NSPredicate(format: "label == 'Ball'")).firstMatch
        XCTAssert(ball.waitForExistence(timeout: 10), "no Ball track in the timeline")
        ball.click()
        let animate = stopwatch("Rotation", flare)
        XCTAssert(animate.waitForExistence(timeout: 5), "selecting Ball showed no Animate Rotation button")
        flare.shot("j7-1-ball")

        // 2. At 0, the stopwatch animates Rotation: keyed at this frame.
        animate.click()
        expectState("Rotation", "Keyed at this frame", flare)
        flare.shot("j7-2-animated")

        // 3. At 20 Rotation is Animated, with no key here.
        scrub(to: 20, flare)
        expectState("Rotation", "Animated", flare)
        flare.shot("j7-3-frame-20")

        // 4. Drag the Rotation bar right: keyed at this frame, and a diamond at 20 on Ball's lane.
        flare.drag(on: "flare.inspector.rotation", from: CGVector(dx: 0.4, dy: 0.5), to: CGVector(dx: 0.6, dy: 0.5))
        expectState("Rotation", "Keyed at this frame", flare)
        XCTAssert(waitFor { self.keys("Ball", flare).contains(20) },
                  "Ball's lane reads \(keys("Ball", flare).sorted()), with no key at 20")
        flare.shot("j7-4-keyed-20")

        // 5. Focus the bar (a click opens its field; Return closes it and keeps the focus), then →, →, Shift-→.
        let bar = flare.element("flare.inspector.rotation")
        bar.click()
        guard let field = editField("Rotation", of: bar, flare) else {
            flare.attachTree(as: "j7-rotation-field-tree")
            return XCTFail("clicking the Rotation bar opened no field")
        }
        flare.press(.return)
        XCTAssert(waitFor { !field.exists }, "Return didn't close the Rotation field")
        guard let start = number(bar) else { return XCTFail("the Rotation bar reads no number: \(String(describing: bar.value))") }
        let presses: [(XCUIElement.KeyModifierFlags, Double)] = [([], 1), ([], 2), (.shift, 12)]
        for (modifiers, total) in presses {
            flare.press(.rightArrow, modifiers)
            let stepped = waitFor { self.number(bar) == start + total }
            if !stepped { flare.attachTree(as: "j7-arrow-keys-tree") }
            XCTAssert(stepped, "Rotation reads \(String(describing: number(bar))), not \(start + total)")
        }
        flare.shot("j7-5-stepped")

        // 6. Select All (Ball and Shadow): X differs, so it reads Mixed with no marker.
        flare.app.menuBars.menuBarItems["Edit"].click()
        let selectAll = flare.app.menuBars.menuItems["Select All"]
        XCTAssert(selectAll.waitForExistence(timeout: 5), "the Edit menu has no Select All")
        selectAll.click()
        let x = flare.element("flare.inspector.x")
        XCTAssert(waitFor { ((x.value as? String) ?? "").contains("Mixed") },
                  "X reads \(String(describing: x.value)) with Ball and Shadow selected, not Mixed")
        expectState("X", "Not animated", flare)
        flare.shot("j7-6-mixed")
    }

    /// FJ-BK: a digit sets the selected layer's opacity, keyed at the playhead while recording.
    @MainActor func testDigitsSetOpacity() {
        let flare = Journey("Flare", self, arguments: ["-FlareSample", "bounce"])
        XCTAssert(flare.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        let canvas = flare.element("suite.canvas")
        XCTAssert(canvas.waitForExistence(timeout: 10), "no stage (suite.canvas)")

        // 1. Auto-key on, frame 12.
        let autoKey = flare.app.toolbars.buttons["flare.timeline.toggleAutoKey"]
        XCTAssert(autoKey.waitForExistence(timeout: 5), "no Auto-key in the toolbar")
        autoKey.click()
        XCTAssert(flare.element("flare.recording").waitForExistence(timeout: 5), "no recording ring with Auto-key on")
        scrub(to: 12, flare)
        flare.shot("bk-1-recording-12")

        // 2. Select, then a click on Shadow (an ellipse about (275, 352), never animated): the stage has the keys.
        let select = flare.element("suite.tools").buttons["Select"]
        XCTAssert(select.waitForExistence(timeout: 5), "no Select in the palette")
        select.click()
        let scale = canvas.frame.width / Self.sceneWidth
        canvas.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 275 * scale, dy: 352 * scale)).click()
        let bar = flare.element("flare.inspector.opacity")
        XCTAssert(bar.waitForExistence(timeout: 5), "selecting Shadow showed no Opacity row")
        flare.shot("bk-2-shadow")

        // 3. 3: Opacity reads 30% and Shadow's lane has a key at 12.
        flare.press(character: "3")
        let set = waitFor { self.number(bar) == 30 }
        if !set { flare.attachTree(as: "bk-opacity-tree") }
        XCTAssert(set, "Opacity reads \(String(describing: bar.value)) after 3, not 30%")
        XCTAssert(waitFor { self.keys("Shadow", flare).contains(12) },
                  "Shadow's lane reads \(keys("Shadow", flare).sorted()), with no key at 12")
        flare.shot("bk-3-opacity-30")
    }

    /// The stopwatch of the TRANSFORM row titled `title`.
    @MainActor private func stopwatch(_ title: String, _ flare: Journey) -> XCUIElement {
        flare.element("suite.inspector").buttons.matching(NSPredicate(format: "label == %@", "Animate \(title)")).firstMatch
    }

    /// The typing field a click on `bar` opened, within five seconds: the text
    /// field inside the bar (ScrubField contains it while editing), or the
    /// inspector's text field labelled `title`; never another row's field, such
    /// as FILL's hex. Nil when neither shows.
    @MainActor private func editField(_ title: String, of bar: XCUIElement, _ flare: Journey) -> XCUIElement? {
        let inside = bar.textFields.firstMatch
        let labelled = flare.element("suite.inspector").textFields.matching(
            NSPredicate(format: "label == %@ OR placeholderValue == %@", title, title)).firstMatch
        guard waitFor({ inside.exists || labelled.exists }) else { return nil }
        return inside.exists ? inside : labelled
    }

    /// `title`'s stopwatch reads `state` within five seconds.
    @MainActor private func expectState(_ title: String, _ state: String, _ flare: Journey) {
        let button = stopwatch(title, flare)
        XCTAssert(waitFor { (button.value as? String) == state },
                  "Animate \(title) reads \(String(describing: button.value)), not \(state)")
    }

    /// A bar's value: a number, or the first number in its text ("12°", "−30°"); nil with neither.
    @MainActor private func number(_ bar: XCUIElement) -> Double? {
        if let number = bar.value as? NSNumber { return number.doubleValue }
        let text = ((bar.value as? String) ?? "").replacingOccurrences(of: "\u{2212}", with: "-")
        return text.range(of: #"-?[0-9]+(\.[0-9]+)?"#, options: .regularExpression).flatMap { Double(text[$0]) }
    }

    /// The frames of the "Key at frame N" children on the lane named `name`.
    @MainActor private func keys(_ name: String, _ flare: Journey) -> Set<Int> {
        let lanes = flare.element("flare.timeline").descendants(matching: .any).matching(
            NSPredicate(format: "label == %@ AND elementType != %d", name, XCUIElement.ElementType.button.rawValue))
        return Set(lanes.allElementsBoundByIndex.flatMap { lane in
            lane.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH 'Key at frame '"))
                .allElementsBoundByIndex.compactMap { Int($0.label.dropFirst("Key at frame ".count).prefix { $0.isNumber }) }
        })
    }

    /// Drags the playhead on the Frame Ruler from 0 to `target`.
    @MainActor private func scrub(to target: Int, _ flare: Journey) {
        let ruler = flare.app.descendants(matching: .any).matching(NSPredicate(format: "label == 'Frame Ruler'")).firstMatch
        XCTAssert(ruler.waitForExistence(timeout: 5), "no Frame Ruler in the timeline")
        let corner = ruler.coordinate(withNormalizedOffset: .zero), step = (ruler.frame.width - 24) / Self.lastFrame
        func x(_ frame: Int) -> CGVector { CGVector(dx: 8 + Double(frame) * step, dy: ruler.frame.height / 2) }
        corner.withOffset(x(0)).press(forDuration: 0.1, thenDragTo: corner.withOffset(x(target)))
        let readout = flare.element("flare.timeline.frame")
        XCTAssert(waitFor { Int(readout.label.prefix { $0.isNumber }) == target },
                  "the frame reads \(readout.label) after the scrub, not \(target)")
    }

    /// Polls `condition` for up to five seconds.
    @MainActor private func waitFor(_ condition: () -> Bool) -> Bool {
        for _ in 0..<25 where !condition() { Thread.sleep(forTimeInterval: 0.2) }
        return condition()
    }
}
