// HaloJourneyTests+Playback.swift: H-J4, play, pause, loop and step
// (viewer-playback VP-12, #37; docs/blueprints/halo/features/viewer-playback.md,
// Journey steps). On `-HaloSample three-layers` (72 frames at 24 fps, so the
// last frame is 71, "00:00:02:23"; live clock) it clicks Badge's lane, which
// focuses the timeline so HaloViewer takes Space and ← (as H-J3 does), then:
// Space; 1 s; Space; ← twice; Animation > Go to End; click Loop; Animation >
// Go to Start; Space; 4 s. `halo.transport.play` reads the Model's playLabel
// ("Playing" or "Paused") and `halo.transport.loop` its loopLabel, which
// starts "On" (HaloPlaybackState's `loops` defaults to true), each read as
// `value as? String`; their labels are fixed, so a value XCUITest reads empty
// (#262) falls back to the playhead moving or holding (expectPlay). The window
// is 1000 by 640, as every Halo journey but the layout one uses, so it fits
// CI's 1024 by 768 display. The paused
// frame f is read from the label of the artboard's `halo.viewer.summary`
// ("Frame f: …"; a label, since values read empty, #262) and must lie in
// 2…71, so two steps back never meet the clamp; the status timecode (matched
// by prefix) then reads f − 2. With Loop off a play from 0 runs 3 s and stops
// on the last frame, so after 4 s the button reads Paused at 00:00:02:23.
// Before the last Space the lane is clicked again, so a Loop button that took
// focus can't take the key. The play-once pass lasts 3 s, and XCUITest waits
// for the app to idle after a key (over 3 s while the display link runs), so
// the pass may be over before the button can be read: from Go to Start, the
// stop on 00:00:02:23 with Loop still Off proves that Space played it. One
// shot per step, `halo-playback-<step>`; the playing shot is taken in the
// first, looping, pass.
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
        expectPlay(false, halo)
        expectLoop("On", halo)
        focusTimeline(halo)

        // 1. Space plays; 1 s later Space pauses.
        halo.press(.space)
        expectPlay(true, halo)
        halo.shot("playback-playing")
        Thread.sleep(forTimeInterval: 1)
        halo.press(.space)
        expectPlay(false, halo)
        guard let paused = artboardFrame(halo) else {
            return XCTFail("the artboard names no frame: \(halo.element("halo.viewer.summary").label)")
        }
        XCTAssert(
            (2...Self.lastFrame).contains(paused),
            "playing 1 s from 0 paused on frame \(paused), outside 2…\(Self.lastFrame)")
        halo.shot("playback-paused")

        // 2. ← twice: two frames back, still paused.
        halo.press(.leftArrow)
        halo.press(.leftArrow)
        expectTimecode(Self.timecode(paused - 2), halo)
        expectPlay(false, halo)
        halo.shot("playback-stepped-back")

        // 3. Animation > Go to End: the last frame.
        choose(["Animation", "Go to End"], halo)
        expectTimecode("00:00:02:23", halo)
        halo.shot("playback-end")

        // 4. Click Loop: it reads Off.
        let loop = halo.element("halo.transport.loop")
        XCTAssert(loop.waitForExistence(timeout: 5), "no Loop button (halo.transport.loop)")
        loop.click()
        expectLoop("Off", halo)
        halo.shot("playback-loop-off")

        // 5. Animation > Go to Start, then Space: one pass, stopped on the
        // last frame. Not read as Playing: the 3 s pass can end before
        // XCUITest's idle wait after the key does, and the stop on the last
        // frame, from frame 0, is what proves the pass.
        choose(["Animation", "Go to Start"], halo)
        expectTimecode("00:00:00:00", halo)
        focusTimeline(halo)
        halo.press(.space)
        Thread.sleep(forTimeInterval: 4)
        expectTimecode("00:00:02:23", halo)
        expectPlay(false, halo)
        expectLoop("Off", halo)
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

    /// The frame the artboard's summary label names ("Frame 30: …"); nil when it names none.
    @MainActor private func artboardFrame(_ halo: Journey) -> Int? {
        let summary = halo.element("halo.viewer.summary")
        guard summary.waitForExistence(timeout: 5) else { return nil }
        let label = summary.label
        guard label.hasPrefix("Frame ") else { return nil }
        return Int(label.dropFirst("Frame ".count).prefix { $0.isNumber })
    }

    /// `halo.transport.play` reads "Playing" (or "Paused"), read as
    /// `value as? String`. Its label is the fixed "Play/Pause", so when
    /// XCUITest reads the value empty (#262) for 0.6 s the playhead stands in:
    /// the artboard's frame moves over 0.3 s while playing and holds while
    /// paused. A value that reads the other state still fails after 5 s.
    @MainActor private func expectPlay(_ playing: Bool, _ halo: Journey) {
        let want = playing ? "Playing" : "Paused"
        let button = halo.element("halo.transport.play")
        XCTAssert(button.waitForExistence(timeout: 5), "no Play button (halo.transport.play)")
        guard case .empty = poll(want, of: button) else { return }
        let before = artboardFrame(halo)
        Thread.sleep(forTimeInterval: 0.3)
        let after = artboardFrame(halo)
        XCTAssertNotNil(before, "halo.transport.play's value reads empty and the artboard names no frame")
        XCTAssertEqual(
            before != after, playing,
            "halo.transport.play's value reads empty and the playhead went \(String(describing: before)) → "
                + "\(String(describing: after)), which isn't \(want)")
    }

    /// `halo.transport.loop` reads `want` ("On" or "Off"), read as `value as?
    /// String`. Its label is the fixed "Loop", so a value XCUITest reads empty
    /// (#262) is noted, and the play-once stop on 00:00:02:23 at the end of the
    /// journey proves Off. A value that reads the other state fails after 5 s.
    @MainActor private func expectLoop(_ want: String, _ halo: Journey) {
        let button = halo.element("halo.transport.loop")
        XCTAssert(button.waitForExistence(timeout: 5), "no Loop button (halo.transport.loop)")
        if case .empty = poll(want, of: button) {
            XCTContext.runActivity(named: "halo.transport.loop's value reads empty; the playback stop proves Loop") { _ in }
        }
    }

    /// How a control's value compared with what a step wanted.
    private enum Reading { case matched, empty, mismatched }

    /// Polls `element`'s value for `want`: matched as soon as it reads it,
    /// empty once it has read nothing for 0.6 s, and a failed assert after
    /// 5 s of reading something else.
    @MainActor private func poll(_ want: String, of element: XCUIElement) -> Reading {
        for attempt in 0..<25 {
            let read = (element.value as? String) ?? ""
            if read == want { return .matched }
            if read.isEmpty, attempt >= 3 { return .empty }
            Thread.sleep(forTimeInterval: 0.2)
        }
        let read = (element.value as? String) ?? ""
        XCTFail("\(element.identifier) reads \(read), not \(want)")
        return .mismatched
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
        halo.menusClosed()
    }
}
