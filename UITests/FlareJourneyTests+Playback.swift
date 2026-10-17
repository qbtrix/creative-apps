// FlareJourneyTests+Playback.swift: J10's slice for draw-key-save DK-11, the
// transport above the timeline driven with the mouse. On `-FlareFixture
// bounce` (48 frames at 24 fps, Loop on) it drags the playhead to 30 on the
// Frame Ruler (as FlareTimelineJourneys does), clicks Play, and after 1 s the
// frame readout no longer reads 30 and Play reads "Playing". ToolbarGroup
// takes no accessibility value per action yet (#1675), and XCUITest can read SwiftUI
// values empty (#262), so an empty value falls back to Play's selected state,
// which the transport sets while playing. Then it clicks Pause (the same
// button): the frame f holds; Next Frame twice gives (f + 2) mod 48 (Loop
// wraps); Go to Start gives 0. The frame is read from `flare.timeline.frame`'s
// label ("f / 48"). The two step buttons share one intent, so they carry
// `flare.timeline.step.back` and `.forward`. One shot per step,
// `flare-playback-<step>`.
//
// J10 in full (inspector-timeline IT-9), `testPlayLoopAndStep` on `-FlareSample
// bounce` (live): scrub to 30, click Play; after 1 s Play reads Playing and the
// actual-fps pill (`flare.status.actualFPS`) shows beside the fps pill. Space
// pauses (its own shortcut step): f ≠ 30 holds. Next Frame twice gives
// (f + 2) mod 48. Loop off, Go to End, Previous Frame (46), Play: playback
// stops on 47 and Play no longer reads selected. Shots `flare-j10-<step>`.
// The TransportCapsule half of IT-9 waits on SuiteUI #340.
import XCTest

final class FlarePlaybackJourneys: XCTestCase {
    private static let lastFrame = 47.0, frames = 48

    /// Scrub to 30, play, pause, step forward twice, go to start.
    @MainActor func testPlayAndStep() {
        let flare = Journey("Flare", self, arguments: ["-FlareFixture", "bounce"])
        XCTAssert(flare.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        let play = flare.element("flare.timeline.togglePlay")
        XCTAssert(play.waitForExistence(timeout: 10), "no Play button (flare.timeline.togglePlay)")
        XCTAssertEqual(play.label, "Play/Pause", "Play isn't titled by its intent")
        flare.shot("playback-0-open")

        // 1. Drag the playhead from frame 0 to 30 on the ruler.
        let ruler = flare.app.descendants(matching: .any).matching(NSPredicate(format: "label == 'Frame Ruler'")).firstMatch
        XCTAssert(ruler.waitForExistence(timeout: 5), "no Frame Ruler in the timeline")
        ruler.coordinate(withNormalizedOffset: .zero).withOffset(x(frame: 0, ruler))
            .press(forDuration: 0.1, thenDragTo: ruler.coordinate(withNormalizedOffset: .zero).withOffset(x(frame: 30, ruler)))
        XCTAssert(waitFor { frame(flare) == 30 }, "the frame is \(String(describing: frame(flare))) after the scrub")
        flare.shot("playback-1-scrub")

        // 2. Play: after 1 s the playhead has moved and Play reads Playing.
        play.click()
        Thread.sleep(forTimeInterval: 1)
        XCTAssert(waitFor { frame(flare) != 30 }, "the frame stayed 30 after Play")
        let value = play.value as? String ?? ""
        if value.isEmpty {
            XCTAssert(play.isSelected, "Play reads no value and isn't selected while playing")
        } else {
            XCTAssertEqual(value, "Playing", "Play doesn't read Playing while playing")
        }
        flare.shot("playback-2-playing")

        // 3. Pause: the frame holds.
        play.click()
        XCTAssert(waitFor { !play.isSelected }, "Play still reads selected after Pause")
        let paused = frame(flare) ?? -1
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssertEqual(frame(flare), paused, "the playhead moved after Pause")
        flare.shot("playback-3-paused")

        // 4. Next Frame twice: f + 2, wrapping with Loop on.
        let forward = flare.element("flare.timeline.step.forward")
        XCTAssert(forward.waitForExistence(timeout: 5), "no Next Frame button (flare.timeline.step.forward)")
        forward.click()
        forward.click()
        let stepped = (paused + 2) % Self.frames
        XCTAssert(waitFor { frame(flare) == stepped }, "Next Frame twice from \(paused) gave \(String(describing: frame(flare)))")
        flare.shot("playback-4-step-forward")

        // 5. Go to Start: frame 0.
        flare.element("flare.timeline.goToStart").click()
        XCTAssert(waitFor { frame(flare) == 0 }, "Go to Start gave \(String(describing: frame(flare)))")
        flare.shot("playback-5-go-to-start")
    }

    /// J10: play with the actual-fps pill, pause with Space, step, then play to the end with Loop off.
    @MainActor func testPlayLoopAndStep() {
        let flare = Journey("Flare", self, arguments: ["-FlareSample", "bounce"])
        XCTAssert(flare.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        let play = flare.element("flare.timeline.togglePlay")
        XCTAssert(play.waitForExistence(timeout: 10), "no Play button (flare.timeline.togglePlay)")
        XCTAssert(flare.element("flare.status.fps").waitForExistence(timeout: 5), "no fps pill (flare.status.fps)")
        XCTAssertFalse(flare.element("flare.status.actualFPS").exists, "the actual-fps pill shows while paused")
        scrub(flare, to: 30)
        flare.shot("j10-0-frame-30")

        play.click()
        Thread.sleep(forTimeInterval: 1)
        XCTAssert(waitFor { frame(flare) != 30 }, "the frame stayed 30 after Play")
        XCTAssert(waitFor { isPlaying(play) }, "Play doesn't read Playing while playing")
        XCTAssert(flare.element("flare.status.actualFPS").waitForExistence(timeout: 5), "no actual-fps pill while playing")
        flare.shot("j10-1-playing")

        flare.app.typeKey(" ", modifierFlags: [])
        XCTAssert(waitFor { !isPlaying(play) }, "Space didn't pause")
        let paused = frame(flare) ?? -1
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssertEqual(frame(flare), paused, "the playhead moved after the pause")
        XCTAssertNotEqual(paused, 30, "the pause landed back on 30")
        flare.shot("j10-2-paused")

        let forward = flare.element("flare.timeline.step.forward")
        forward.click()
        forward.click()
        let stepped = (paused + 2) % Self.frames
        XCTAssert(waitFor { frame(flare) == stepped }, "Next Frame twice from \(paused) gave \(String(describing: frame(flare)))")
        flare.shot("j10-3-stepped")

        flare.element("flare.timeline.setLoops").click()
        flare.element("flare.timeline.goToEnd").click()
        XCTAssert(waitFor { frame(flare) == Self.frames - 1 }, "Go to End gave \(String(describing: frame(flare)))")
        flare.element("flare.timeline.step.back").click()
        XCTAssert(waitFor { frame(flare) == Self.frames - 2 }, "Previous Frame from the end gave \(String(describing: frame(flare)))")
        play.click()
        XCTAssert(waitFor { frame(flare) == Self.frames - 1 && !isPlaying(play) }, "Loop off didn't stop on the last frame")
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssertEqual(frame(flare), Self.frames - 1, "the playhead left the last frame with Loop off")
        flare.shot("j10-4-stopped-at-end")
    }

    /// Whether Play reads Playing; an empty value (#262) falls back to its selected state.
    @MainActor private func isPlaying(_ play: XCUIElement) -> Bool {
        let value = play.value as? String ?? ""
        return value.isEmpty ? play.isSelected : value == "Playing"
    }

    /// Drags the playhead from frame 0 to `target` on the Frame Ruler.
    @MainActor private func scrub(_ flare: Journey, to target: Int) {
        let ruler = flare.app.descendants(matching: .any).matching(NSPredicate(format: "label == 'Frame Ruler'")).firstMatch
        XCTAssert(ruler.waitForExistence(timeout: 5), "no Frame Ruler in the timeline")
        let origin = ruler.coordinate(withNormalizedOffset: .zero)
        origin.withOffset(x(frame: 0, ruler)).press(forDuration: 0.1, thenDragTo: origin.withOffset(x(frame: target, ruler)))
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
