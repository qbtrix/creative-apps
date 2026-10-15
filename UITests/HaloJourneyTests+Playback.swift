// HaloJourneyTests+Playback.swift: H-J4, play, pause, loop and step
// (viewer-playback VP-12, #37; docs/blueprints/halo/features/viewer-playback.md,
// Journey steps). On `-HaloSample three-layers` (72 frames at 24 fps, so the
// last frame is 71, "00:00:02:23"; live clock) it clicks Badge's lane, which
// focuses the timeline so HaloViewer takes Space and ← (as H-J3 does), then:
// Space; 1 s; Space; ← twice; Animation > Go to End; click Loop; Animation >
// Go to Start; Space; 4 s. `halo.transport.play` reads the Model's playLabel
// ("Playing" or "Paused") and `halo.transport.loop` its loopLabel, which
// starts "On" (HaloPlaybackState's `loops` defaults to true). The paused
// frame f is read from the artboard's value ("Frame f: …") and must lie in
// 2…71, so two steps back never meet the clamp; the status timecode (matched
// by prefix) then reads f − 2. With Loop off a play from 0 runs 3 s and stops
// on the last frame, so after 4 s the button reads Paused at 00:00:02:23.
// Before the last Space the lane is clicked again, so a Loop button that took
// focus can't take the key. One shot per step, `halo-playback-<step>`; the
// playing shot is taken in the play-once pass, so its audit can't stretch the
// 1 s wait.
import XCTest

final class HaloPlaybackJourneyTests: XCTestCase {
    /// The fixture's frame rate and last frame.
    private static let fps = 24, lastFrame = 71

    /// H-J4: the transport plays, pauses, steps, jumps and plays once with Loop off.
    @MainActor func testPlayPauseLoopAndStep() {
        let halo = Journey("Halo", self, arguments: ["-HaloSample", "three-layers", "-HaloWindowSize", "1000x640"])
        XCTAssert(halo.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        XCTAssert(
            halo.element("halo.transport.play").waitForExistence(timeout: 10),
            "no Play button (halo.transport.play) in the status bar")
        expectValue("Paused", of: "halo.transport.play", halo)
        expectValue("On", of: "halo.transport.loop", halo)
        focusTimeline(halo)

        // 1. Space plays; 1 s later Space pauses.
        halo.press(.space)
        expectValue("Playing", of: "halo.transport.play", halo)
        Thread.sleep(forTimeInterval: 1)
        halo.press(.space)
        expectValue("Paused", of: "halo.transport.play", halo)
        guard let paused = artboardFrame(halo) else {
            return XCTFail("the artboard names no frame: \(String(describing: halo.element("halo.viewer").value))")
        }
        XCTAssert(
            (2...Self.lastFrame).contains(paused),
            "playing 1 s from 0 paused on frame \(paused), outside 2…\(Self.lastFrame)")
        halo.shot("playback-paused")

        // 2. ← twice: two frames back, still paused.
        halo.press(.leftArrow)
        halo.press(.leftArrow)
        expectTimecode(Self.timecode(paused - 2), halo)
        expectValue("Paused", of: "halo.transport.play", halo)
        halo.shot("playback-stepped-back")

        // 3. Animation > Go to End: the last frame.
        choose(["Animation", "Go to End"], halo)
        expectTimecode("00:00:02:23", halo)
        halo.shot("playback-end")

        // 4. Click Loop: it reads Off.
        let loop = halo.element("halo.transport.loop")
        XCTAssert(loop.waitForExistence(timeout: 5), "no Loop button (halo.transport.loop)")
        loop.click()
        expectValue("Off", of: "halo.transport.loop", halo)
        halo.shot("playback-loop-off")

        // 5. Animation > Go to Start, then Space: one pass, stopped on the last frame.
        choose(["Animation", "Go to Start"], halo)
        expectTimecode("00:00:00:00", halo)
        focusTimeline(halo)
        halo.press(.space)
        expectValue("Playing", of: "halo.transport.play", halo)
        // Shot here, not in the 1 s pass: a shot's audit takes time, and a
        // looping pass could wrap past the last frame before the pause.
        halo.shot("playback-playing")
        Thread.sleep(forTimeInterval: 4)
        expectTimecode("00:00:02:23", halo)
        expectValue("Paused", of: "halo.transport.play", halo)
        expectValue("Off", of: "halo.transport.loop", halo)
        halo.shot("playback-stopped")
    }

    // MARK: - Helpers

    /// `frame` as the status bar's timecode, hours:minutes:seconds:frames at 24 fps.
    private static func timecode(_ frame: Int) -> String {
        let seconds = frame / fps
        let parts = [seconds / 3600, seconds / 60 % 60, seconds % 60, frame % fps]
        return parts.map { $0 < 10 ? "0\($0)" : "\($0)" }.joined(separator: ":")
    }

    /// Clicks Badge's lane: it selects Badge and focuses the timeline, so
    /// HaloViewer's keys (Space, ←) reach the Model.
    @MainActor private func focusTimeline(_ halo: Journey) {
        let lane = halo.app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier == 'halo.timeline.track' AND label == 'Badge'")).firstMatch
        XCTAssert(lane.waitForExistence(timeout: 10), "no Badge lane in the timeline")
        lane.click()
    }

    /// The frame the artboard's value names ("Frame 30: …"); nil when it names none.
    @MainActor private func artboardFrame(_ halo: Journey) -> Int? {
        guard let value = halo.element("halo.viewer").value as? String, value.hasPrefix("Frame ") else { return nil }
        return Int(value.dropFirst("Frame ".count).prefix { $0.isNumber })
    }

    /// The element `identifier`'s accessibility value is `value`, within five seconds.
    @MainActor private func expectValue(_ value: String, of identifier: String, _ halo: Journey) {
        let match = halo.app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier == %@ AND value == %@", identifier, value)).firstMatch
        XCTAssert(
            match.waitForExistence(timeout: 5),
            "\(identifier) reads \(String(describing: halo.element(identifier).value)), not \(value)")
    }

    /// The status row's timecode pill (statusTimecode: the playhead's
    /// timecode, then the length and rate) starts with `timecode`, within
    /// five seconds. A plain Text may read as a static text whose value holds
    /// the string, so only static texts are matched by value.
    @MainActor private func expectTimecode(_ timecode: String, _ halo: Journey) {
        let staticText = NSNumber(value: XCUIElement.ElementType.staticText.rawValue)
        let predicate = NSPredicate(
            format: "label BEGINSWITH %@ OR (elementType == %@ AND value BEGINSWITH %@)", timecode, staticText, timecode)
        let pill = halo.app.windows.firstMatch.descendants(matching: .any).matching(predicate).firstMatch
        XCTAssert(pill.waitForExistence(timeout: 5), "the status timecode doesn't read \(timecode)")
    }

    /// Opens the menu bar item `path[0]`, hovers each submenu on the way and
    /// clicks the last item, which must be enabled.
    @MainActor private func choose(_ path: [String], _ halo: Journey) {
        var item = halo.app.menuBars.firstMatch.menuBarItems[path.first ?? ""]
        XCTAssert(item.waitForExistence(timeout: 5), "no \(path.first ?? "") menu")
        item.click()
        for (depth, title) in path.dropFirst().enumerated() {
            if depth > 0 { item.hover() }
            item = item.menus.firstMatch.children(matching: .menuItem)[title]
            XCTAssert(item.waitForExistence(timeout: 3), "no \(path.joined(separator: " > "))")
        }
        XCTAssert(item.isEnabled, "\(path.joined(separator: " > ")) is disabled")
        item.click()
        _ = halo.app.menus.firstMatch.waitForNonExistence(timeout: 2)
    }
}
