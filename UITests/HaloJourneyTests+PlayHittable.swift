// HaloJourneyTests+PlayHittable.swift: Play/Pause stays clickable while it
// plays (#4586). H-J12 clicked `halo.transport.play` to start playback, and
// the second click, to pause, found it at {{inf, inf}, {0, 0}}: the status
// timecode grew as the playhead ran ("frame 9" to "frame 10"), the row's
// ViewThatFits swapped shape, and the transport was rebuilt under the click.
// The timecode pill is now sized to its widest line (statusTimecodeWidest),
// so the row keeps one shape. On `-HaloSample three-layers` (72 frames at
// 24 fps, Loop on) at H-J4's 1000 by 640 window it clicks Play, waits past
// frame 10, then samples the button five times over a second: each time it is
// hittable at the frame it had before Play. A second click then pauses it,
// read from the button's value or, when that reads empty (#262), from the
// artboard's frame holding still. Shots `halo-play-hittable-<step>`.
import XCTest

final class HaloPlayHittableJourneyTests: XCTestCase {
    /// Play/Pause keeps its frame and stays hittable while playing, and a click pauses it.
    @MainActor func testPlayStaysHittableWhilePlaying() {
        let halo = Journey("Halo", self, arguments: ["-HaloSample", "three-layers", "-HaloWindowSize", "1000x640"])
        XCTAssert(halo.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        let play = halo.element("halo.transport.play")
        XCTAssert(play.waitForExistence(timeout: 10), "no Play button (halo.transport.play)")
        let rest = play.frame

        play.click()
        Thread.sleep(forTimeInterval: 1)
        XCTAssertNotEqual(artboardFrame(halo), 0, "Play didn't move the playhead off frame 0")
        halo.shot("play-hittable-playing")
        for sample in 0..<5 {
            XCTAssert(play.isHittable, "halo.transport.play isn't hittable while playing (sample \(sample)): \(play.frame)")
            XCTAssertEqual(play.frame, rest, "halo.transport.play moved while playing (sample \(sample))")
            Thread.sleep(forTimeInterval: 0.2)
        }

        play.click()
        expectPaused(play, halo)
        halo.shot("play-hittable-paused")
    }

    /// The button reads "Paused", or, when its value reads empty (#262), the
    /// artboard's frame holds over 0.3 s.
    @MainActor private func expectPaused(_ play: XCUIElement, _ halo: Journey) {
        for _ in 0..<25 {
            let read = (play.value as? String) ?? ""
            if read == "Paused" { return }
            if !read.isEmpty, read != "Playing" { break }
            if read.isEmpty {
                let before = artboardFrame(halo)
                Thread.sleep(forTimeInterval: 0.3)
                XCTAssertEqual(artboardFrame(halo), before, "the second click on Play/Pause didn't pause playback")
                return
            }
            Thread.sleep(forTimeInterval: 0.2)
        }
        XCTFail("halo.transport.play reads \((play.value as? String) ?? ""), not Paused")
    }

    /// The frame the artboard's summary label names ("Frame 30: …"); nil when it names none.
    @MainActor private func artboardFrame(_ halo: Journey) -> Int? {
        let summary = halo.element("halo.viewer.summary")
        guard summary.waitForExistence(timeout: 5) else { return nil }
        let label = summary.label
        guard label.hasPrefix("Frame ") else { return nil }
        return Int(label.dropFirst("Frame ".count).prefix { $0.isNumber })
    }
}
