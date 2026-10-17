// FlareJourneyTests+Timeline.swift: J9's slice for draw-key-save DK-10, the
// timeline under the stage driven with the mouse. On `-FlareFixture bounce`
// (Ball, Shadow and Background, 48 frames at 24 fps) it drags the playhead on
// the Frame Ruler to 30, where the readouts read "30 / 48" and "01:06 / 02:00",
// then clicks Ball's name in the timeline, which selects Ball's row. A frame's
// x is the ruler's left edge plus the strip's 8 pt inset and the frame's share
// of the ruler's width (the last frame, 47, sits 24 pt before its right edge),
// as in HaloTimelineJourneyTests. One shot per step, `flare-timeline-<step>`.
import XCTest

final class FlareTimelineJourneys: XCTestCase {
    private static let lastFrame = 47.0

    /// Drag the playhead to 30: the readouts follow; click Ball's name: Ball's row is selected.
    @MainActor func testTimelineScrub() {
        let flare = Journey("Flare", self, arguments: ["-FlareFixture", "bounce"])
        XCTAssert(flare.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        let frame = flare.element("flare.timeline.frame")
        XCTAssert(frame.waitForExistence(timeout: 10), "no frame readout (flare.timeline.frame)")
        flare.shot("timeline-0-open")

        // 1. Drag the playhead from frame 0 to 30 on the ruler.
        let ruler = flare.app.descendants(matching: .any).matching(NSPredicate(format: "label == 'Frame Ruler'")).firstMatch
        XCTAssert(ruler.waitForExistence(timeout: 5), "no Frame Ruler in the timeline")
        ruler.coordinate(withNormalizedOffset: .zero).withOffset(x(frame: 0, ruler))
            .press(forDuration: 0.1, thenDragTo: ruler.coordinate(withNormalizedOffset: .zero).withOffset(x(frame: 30, ruler)))
        XCTAssert(waitFor { frame.label == "30 / 48" }, "the frame readout reads \(frame.label) after the scrub")
        let timecode = flare.element("flare.timeline.timecode")
        XCTAssertEqual(timecode.label, "01:06 / 02:00", "the timecode didn't follow the scrub")
        flare.shot("timeline-1-scrub")

        // 2. Click Ball's name in the timeline: its row is selected.
        let ball = flare.element("flare.timeline").buttons.matching(
            NSPredicate(format: "identifier == 'flare.timeline.track' AND label == 'Ball'")).firstMatch
        XCTAssert(ball.waitForExistence(timeout: 5), "no Ball track in the timeline")
        ball.click()
        XCTAssert(waitFor { ball.isSelected }, "clicking Ball's name didn't select Ball's row")
        flare.shot("timeline-2-select-ball")
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
