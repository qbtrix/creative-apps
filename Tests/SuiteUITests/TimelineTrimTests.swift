// TimelineTrimTests.swift: TL-15's clip-end trim on a lane (timeline packet,
// acceptance row TL-15). A press within 6 pt of a clip's start or end tick,
// and not on a key, trims that end; 7 pt is a bed press. The edge follows the
// pointer snapped to the playhead and kept by the trim rule, the host hears it
// only when the frame changes, and a drag ends once. macOS only.
import Foundation
@testable import SuiteUI
import Testing

@MainActor @Suite struct TimelineTrimTests {
    private static let mapping = FrameMapping(duration: 120, frameWidth: 10)
    private static let track = TimelineTrack(
        id: "a", name: "A", keys: [TimelineKey(frame: 30, shape: .linear)], spans: [20...50])

    /// Every call a press and its drag made, in order.
    @MainActor private final class Log {
        var calls: [String] = []
        var actions: TimelineLaneActions<String> {
            TimelineLaneActions(
                onSelectKeyframe: { self.calls.append("select \($0) \($1)") },
                onSelectTrack: { self.calls.append("track \($0)") },
                onPickKeyframe: { self.calls.append("pick \($0) \($1.map(String.init) ?? "nil") \($2.rawValue)") },
                onTrim: { self.calls.append("trim \($0) \($1.rawValue) \($2)") },
                onEndTrim: { self.calls.append("trim end") })
        }
    }

    private func target(_ x: CGFloat, track: TimelineTrack<String> = Self.track) -> TimelineLanePress.Target {
        TimelineLanePress.target(atX: timelineInset + x, on: track, mapping: Self.mapping)
    }

    @Test func aPressFivePointsInsideTheRightEndTrimsTheEndAndSevenIsTheBed() {
        #expect(target(500 - 5) == .clipEnd(TimelineClipEnd(span: 20...50, edge: .end)))
        #expect(target(500 + 5) == .clipEnd(TimelineClipEnd(span: 20...50, edge: .end)))
        #expect(target(500 - 7) == .bed)
        #expect(target(500 + 7) == .bed)
    }

    @Test func aPressNearTheLeftEndTrimsTheStart() {
        #expect(target(200 + 5) == .clipEnd(TimelineClipEnd(span: 20...50, edge: .start)))
        #expect(target(200 - 6) == .clipEnd(TimelineClipEnd(span: 20...50, edge: .start)))
        #expect(target(200 + 7) == .bed)
    }

    @Test func aKeyOnTheEndWinsOverTheTrim() {
        let keyed = TimelineTrack(
            id: "a", name: "A", keys: [TimelineKey(frame: 50, shape: .eased)], spans: [20...50])
        #expect(target(500 - 5, track: keyed) == .key(50))
    }

    @Test func aDragTrimsTheEndOnFrameStepsAndEndsOnce() throws {
        let log = Log()
        var trim = try #require(
            TimelineLanePress.beginTrim(target(500), playhead: 0, mapping: Self.mapping))
        let still = trim.move(dx: 2, id: "a", actions: log.actions)
        #expect(!still, "2 pt is no frame step: nothing is sent")
        _ = trim.move(dx: -100, id: "a", actions: log.actions)
        _ = trim.move(dx: -101, id: "a", actions: log.actions)
        #expect(log.calls == ["trim a end 40"])
        let firstRelease = trim.release(actions: log.actions)
        let secondRelease = trim.release(actions: log.actions)
        #expect(!firstRelease)
        #expect(!secondRelease)
        let afterRelease = trim.move(dx: -200, id: "a", actions: log.actions)
        #expect(!afterRelease)
        #expect(log.calls == ["trim a end 40", "trim end"])
    }

    /// #1796: a release whose sample moved past the last change trims to it, then ends.
    @Test func theReleaseSampleTrimsBeforeTheEnd() throws {
        let log = Log()
        var trim = try #require(
            TimelineLanePress.beginTrim(target(500), playhead: 0, mapping: Self.mapping))
        let click = trim.release(atDX: -100, id: "a", actions: log.actions)
        #expect(!click)
        #expect(log.calls == ["trim a end 40", "trim end"])
    }

    @Test func theStartTrimsTooAndStopsAFrameShortOfTheEnd() throws {
        let log = Log()
        var trim = try #require(
            TimelineLanePress.beginTrim(target(200), playhead: 0, mapping: Self.mapping))
        _ = trim.move(dx: 50, id: "a", actions: log.actions)
        _ = trim.move(dx: 2_000, id: "a", actions: log.actions)
        #expect(log.calls == ["trim a start 25", "trim a start 49"])
    }

    @Test func theTrimmedEndSnapsToThePlayhead() throws {
        let log = Log()
        // 2 pt a frame: the end at 50 sits at 100 pt, the playhead at 45 at 90 pt.
        let narrow = FrameMapping(duration: 120, frameWidth: 2)
        var trim = TimelineTrimDrag(TimelineClipEnd(span: 20...50, edge: .end), playhead: 45, mapping: narrow)
        let farFrame = trim.edgeFrame(dx: 0)
        #expect(farFrame == 50, "frame 50 is 10 pt from the playhead's tick, past its 8 pt pull: no snap")
        _ = trim.move(dx: -8, id: "a", actions: log.actions)  // frame 46, 2 pt away: snaps to 45
        #expect(log.calls == ["trim a end 45"])
        #expect(trim.frame == 45)
    }

    @Test func aStillPressOnAClipEndIsABedClick() throws {
        let log = Log()
        let pressed = target(500)
        var trim = try #require(TimelineLanePress.beginTrim(pressed, playhead: 0, mapping: Self.mapping))
        let click = trim.release(actions: log.actions)
        #expect(click)
        TimelineLanePress.press(pressed, modifiers: [], on: Self.track, actions: log.actions)
        #expect(log.calls == ["track a", "pick a nil replace"])
    }

    @Test func aKeyOrTheBedStartsNoTrim() {
        #expect(TimelineLanePress.beginTrim(.bed, playhead: 0, mapping: Self.mapping) == nil)
        #expect(TimelineLanePress.beginTrim(.key(30), playhead: 0, mapping: Self.mapping) == nil)
    }
}
