// FlareJourneyTests+FillKeys.swift: FJ-TK (timeline-keys, packet
// docs/blueprints/suiteui/features/timeline-keys.md). On `-FlareSample bounce`
// with Ball selected, the FILL colour, STROKE colour and STROKE width rows each
// carry a keyframe stopwatch (`flare.inspector.key.fill`, `.key.stroke`,
// `.key.stroke-width`) that reads Not animated on Ball's static paint (TK-3).
// FJ-TK (TK-8): fill Ball blue, key it at 0, press End and type orange (a
// keyed track keys the edit); the stopwatch reads keyed there and back at 0.
// The stage's mid colour at 15 waits on fix/flare-stage-matches-export.
// Shots are `flare-tk-<step>`.
import XCTest

final class FlareFillKeyJourneyTests: XCTestCase {
    static let ids = ["flare.inspector.key.fill", "flare.inspector.key.stroke", "flare.inspector.key.stroke-width"]

    /// TK-3: the three paint stopwatches exist and read Not animated on a static shape.
    @MainActor func testPaintStopwatchesReadNotAnimated() {
        let flare = Journey("Flare", self, arguments: ["-FlareSample", "bounce"])
        XCTAssert(flare.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        let ball = flare.element("flare.timeline").buttons.matching(
            NSPredicate(format: "label == 'Ball'")).firstMatch
        XCTAssert(ball.waitForExistence(timeout: 10), "no Ball track in the timeline")
        ball.click()
        for id in Self.ids {
            let stopwatch = flare.element(id)
            XCTAssert(stopwatch.waitForExistence(timeout: 5), "no \(id) beside Ball's paint rows")
            XCTAssertEqual(stopwatch.value as? String, "Not animated", "\(id) on Ball's static paint")
        }
        flare.shot("tk-1-paint-keys")
    }

    /// FJ-TK: key Ball's fill blue at 0 and orange at the end; the stopwatch reads keyed at both.
    @MainActor func testKeyFillColour() {
        let flare = Journey("Flare", self, arguments: ["-FlareSample", "bounce"])
        let ball = flare.element("flare.timeline").buttons.matching(NSPredicate(format: "label == 'Ball'")).firstMatch
        XCTAssert(ball.waitForExistence(timeout: 30), "no Ball track in the timeline")
        ball.click()
        let stopwatch = flare.element("flare.inspector.key.fill")
        fill("0000FF", ball, flare)
        XCTAssert(stopwatch.waitForExistence(timeout: 5) && stopwatch.isEnabled, "no fill stopwatch on Ball")
        stopwatch.click()
        flare.shot("tk-2-key-blue-at-0")
        let steps: [(XCUIKeyboardKey, String?, String)] = [
            (.end, "FF9500", "tk-3-orange-at-end"), (.home, nil, "tk-4-keyed-at-0")]
        for (key, hex, shot) in steps {
            flare.press(key)
            if let hex { fill(hex, ball, flare) }
            XCTAssert(Journey.waitUntil(5) { stopwatch.value as? String == "Keyed at this frame" },
                      "the fill stopwatch reads \(String(describing: stopwatch.value)) at \(shot)")
            flare.shot(shot)
        }
    }

    /// Types `hex` into FILL's hex field and presses Return, then clicks Ball so the field lets go of the keys.
    @MainActor private func fill(_ hex: String, _ ball: XCUIElement, _ flare: Journey) {
        let field = flare.element("flare.inspector.fill").textFields.firstMatch
        XCTAssert(field.waitForExistence(timeout: 5), "the FILL row has no hex field")
        field.click()
        flare.app.typeKey("a", modifierFlags: .command)
        flare.app.typeText(hex)
        flare.press(.return)
        XCTAssert(Journey.waitUntil(5) { ((field.value as? String) ?? "").uppercased().contains(hex) },
                  "the fill reads \(String(describing: field.value)), not \(hex)")
        ball.click()
    }
}
