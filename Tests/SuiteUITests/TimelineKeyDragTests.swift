// TimelineKeyDragTests.swift: TL-14's key drag on a lane (timeline packet,
// acceptance row TL-14). A press on an unpicked key picks it before anything
// moves; a drag moves every picked key by whole frame steps, snapped to the
// playhead and clamped as a group; Escape sends back what was sent; a drag
// ends once. macOS only.
import Foundation
@testable import SuiteUI
import Testing

@MainActor @Suite struct TimelineKeyDragTests {
    private static let mapping = FrameMapping(duration: 120, frameWidth: 10)
    private static let track = TimelineTrack(
        id: "a", name: "A",
        keys: [10, 40, 60].map { TimelineKey(frame: $0, shape: .linear) },
        pickedFrames: [40, 60])

    /// Every call a press and its drag made, in order.
    @MainActor private final class Log {
        var calls: [String] = []
        var actions: TimelineLaneActions<String> {
            TimelineLaneActions(
                onSelectKeyframe: { self.calls.append("select \($0) \($1)") },
                onSelectTrack: { self.calls.append("track \($0)") },
                onPickKeyframe: { self.calls.append("pick \($0) \($1.map(String.init) ?? "nil") \($2.rawValue)") },
                onMoveKeyframes: { self.calls.append("move \($0)") },
                onEndKeyDrag: { self.calls.append("end") })
        }
    }

    private func begin(_ frame: Int, playhead: Int = 0, log: Log) -> TimelineKeyDrag? {
        TimelineLanePress.begin(
            .key(frame), modifiers: [], on: Self.track, playhead: playhead, mapping: Self.mapping, actions: log.actions)
    }

    @Test func pressingAnUnpickedKeyPicksItBeforeItMoves() throws {
        let log = Log()
        var drag = try #require(begin(10, log: log))
        #expect(log.calls == ["pick a 10 replace", "select a 10"])
        #expect(drag.group == [10], "the old pick must not move with a newly picked key")
        _ = drag.move(dx: 30, actions: log.actions)
        #expect(log.calls == ["pick a 10 replace", "select a 10", "move 3"])
    }

    @Test func twoPickedKeysMoveTogether() throws {
        let log = Log()
        var drag = try #require(begin(40, log: log))
        #expect(log.calls.isEmpty, "a picked key's press waits: the pick must survive the drag")
        #expect(drag.group == [40, 60])
        // 100 pt is 10 frames, but the group's last key stops at 120: 60 frames at most.
        _ = drag.move(dx: 100, actions: log.actions)
        _ = drag.move(dx: 104, actions: log.actions)
        _ = drag.move(dx: 2_000, actions: log.actions)
        #expect(log.calls == ["move 10", "move 50"])
        #expect(drag.frame == 100)
        _ = drag.release(actions: log.actions)
        #expect(log.calls.last == "end")
    }

    @Test func aDragSnapsToThePlayhead() {
        let log = Log()
        // 2 pt a frame: the playhead's 8 pt pull reaches 4 frames.
        var drag = TimelineKeyDrag(
            grabbing: 40, picked: [40], replacing: false, playhead: 50,
            mapping: FrameMapping(duration: 120, frameWidth: 2))
        #expect(drag.total(dx: 10) == 5, "frame 45 is 10 pt from the playhead: no snap")
        _ = drag.move(dx: 14, actions: log.actions)  // frame 47, 6 pt away: snaps to 50
        #expect(drag.frame == 50)
        _ = drag.move(dx: 16, actions: log.actions)  // frame 48 snaps to 50 too: nothing sent
        #expect(log.calls == ["move 10"])
    }

    @Test func escapeSendsTheNegativeOfWhatWasSent() throws {
        let log = Log()
        var drag = try #require(begin(40, log: log))
        _ = drag.move(dx: 30, actions: log.actions)
        _ = drag.move(dx: 50, actions: log.actions)
        drag.cancel(actions: log.actions)
        #expect(log.calls == ["move 3", "move 2", "move -5", "end"])
        let movedAfterCancel = drag.move(dx: 80, actions: log.actions)
        #expect(!movedAfterCancel, "a cancelled drag sends nothing more")
        let releasedAfterCancel = drag.release(actions: log.actions)
        #expect(!releasedAfterCancel)
        #expect(log.calls == ["move 3", "move 2", "move -5", "end"])
    }

    @Test func oneEndPerDrag() throws {
        let log = Log()
        var drag = try #require(begin(40, log: log))
        _ = drag.move(dx: 30, actions: log.actions)
        _ = drag.move(dx: 0, actions: log.actions)
        let firstRelease = drag.release(actions: log.actions)
        #expect(!firstRelease)
        let secondRelease = drag.release(actions: log.actions)
        #expect(!secondRelease)
        drag.cancel(actions: log.actions)
        #expect(log.calls == ["move 3", "move -3", "end"])
    }

    @Test func aClickOnAPickedKeyPicksItOnRelease() throws {
        let log = Log()
        var drag = try #require(begin(40, log: log))
        let pickedClick = drag.release(actions: log.actions)
        #expect(pickedClick, "a picked key's waiting pick runs on a still release")
        var fresh = try #require(begin(10, log: log))
        let freshClick = fresh.release(actions: log.actions)
        #expect(!freshClick, "an unpicked key was picked at the press, not twice")
        #expect(!log.calls.contains("end"))
    }

    @Test func theBedStartsNoDrag() {
        let log = Log()
        let drag = TimelineLanePress.begin(
            .bed, modifiers: [], on: Self.track, playhead: 0, mapping: Self.mapping, actions: log.actions)
        #expect(drag == nil)
        #expect(log.calls.isEmpty, "the bed acts on release")
    }
}
