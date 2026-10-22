// FlareJourneyTests+FillKeys.swift: FJ-TK (timeline-keys, packet
// docs/blueprints/suiteui/features/timeline-keys.md). On `-FlareSample bounce`
// with Ball selected, the FILL colour, STROKE colour and STROKE width rows each
// carry a keyframe stopwatch (`flare.inspector.key.fill`, `.key.stroke`,
// `.key.stroke-width`) that reads Not animated on Ball's static paint (TK-3).
// The whole journey (draw a rectangle, fill it blue, key the fill at 0, orange
// at 30, the mid colour at 15) waits on TK-7's paint keys, so it is skipped.
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

    /// FJ-TK: key a rectangle's fill blue at 0 and orange at 30; at 15 it reads the mid colour.
    @MainActor func testKeyFillColour() throws {
        throw XCTSkip("waits on TK-7: Flare's fill and stroke keys")
    }
}
