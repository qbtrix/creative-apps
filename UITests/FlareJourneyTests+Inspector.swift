// FlareJourneyTests+Inspector.swift: J7 (inspector-timeline IT-4). On
// `-FlareSample bounce` it selects Ball, animates Rotation at 0, finds it
// Animated at 20, drags the bar there (keyed, a key at 20 on Ball's lane),
// steps it →, →, Shift-→ (+1, +1, +10), then Select All: X reads Mixed and
// its stopwatch Not animated. A stopwatch is found by label ("Animate
// Rotation"); its value is the key state. Shots are `flare-j7-<step>`.
import XCTest

final class FlareInspectorJourneys: XCTestCase {
    private static let lastFrame = 47.0

    /// J7: animate, scrub, drag and step Rotation on Ball; Ball and Shadow read X as Mixed.
    @MainActor func testInspectorKeysTransform() {
        let flare = Journey("Flare", self, arguments: ["-FlareSample", "bounce"])
        XCTAssert(flare.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")

        // 1. Select Ball from its timeline track: the TRANSFORM rows show.
        let ball = flare.element("flare.timeline").buttons.matching(
            NSPredicate(format: "identifier == 'flare.timeline.track' AND label == 'Ball'")).firstMatch
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
        let field = flare.element("suite.inspector").textFields.firstMatch
        XCTAssert(field.waitForExistence(timeout: 5), "clicking the Rotation bar opened no field")
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

    /// The stopwatch of the TRANSFORM row titled `title`.
    @MainActor private func stopwatch(_ title: String, _ flare: Journey) -> XCUIElement {
        flare.element("suite.inspector").buttons.matching(NSPredicate(format: "label == %@", "Animate \(title)")).firstMatch
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
