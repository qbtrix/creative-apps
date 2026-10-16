// TimelineLanePickTests.swift: TL-11's pointer picking on a lane (timeline
// packet, acceptance row TL-11). A press on a key picks it with the mode its
// modifiers give (Shift extends, Command toggles, else it replaces), and a
// plain press also selects the key; a right press picks an unpicked key and
// leaves a picked one alone (B6); a press on the bed selects the track and
// clears the pick (B5). macOS only.
import Foundation
@testable import SuiteUI
import Testing

@MainActor @Suite struct TimelineLanePickTests {
    private static let mapping = FrameMapping(duration: 120, frameWidth: 10)
    private static let track = TimelineTrack(
        id: "a", name: "A",
        keys: [TimelineKey(frame: 10, shape: .linear), TimelineKey(frame: 40, shape: .linear)],
        pickedFrames: [40])

    /// Every call a press made, in order.
    @MainActor private final class Log {
        var calls: [String] = []
        var actions: TimelineLaneActions<String> {
            TimelineLaneActions(
                onSelectKeyframe: { self.calls.append("select \($0) \($1)") },
                onSelectTrack: { self.calls.append("track \($0)") },
                onPickKeyframe: { self.calls.append("pick \($0) \($1.map(String.init) ?? "nil") \($2.rawValue)") })
        }
    }

    @Test func aPressClassifiesAsKeyOrBed() {
        #expect(TimelineLanePress.target(atX: timelineInset + 103, on: Self.track, mapping: Self.mapping) == .key(10))
        #expect(TimelineLanePress.target(atX: timelineInset + 250, on: Self.track, mapping: Self.mapping) == .bed)
    }

    @Test func aPlainPressOnAKeyReplacesThePickAndSelectsTheKey() {
        let log = Log()
        TimelineLanePress.press(.key(10), modifiers: [], on: Self.track, actions: log.actions)
        #expect(log.calls == ["pick a 10 replace", "select a 10"])
    }

    @Test func aShiftPressExtendsAndACommandPressToggles() {
        let log = Log()
        TimelineLanePress.press(.key(10), modifiers: .shift, on: Self.track, actions: log.actions)
        TimelineLanePress.press(.key(40), modifiers: .command, on: Self.track, actions: log.actions)
        #expect(log.calls == ["pick a 10 extend", "pick a 40 toggle"])
    }

    @Test func aPressOnTheBedSelectsTheTrackAndClearsThePick() {
        let log = Log()
        TimelineLanePress.press(.bed, modifiers: .shift, on: Self.track, actions: log.actions)
        #expect(log.calls == ["track a", "pick a nil replace"])
    }

    @Test func aRightPressPicksAnUnpickedKeyAndLeavesAPickedOne() {
        let log = Log()
        TimelineLanePress.rightPress(.key(10), on: Self.track, actions: log.actions)
        #expect(log.calls == ["pick a 10 replace"])
        TimelineLanePress.rightPress(.key(40), on: Self.track, actions: log.actions)
        TimelineLanePress.rightPress(.bed, on: Self.track, actions: log.actions)
        #expect(log.calls == ["pick a 10 replace"])
    }
}
