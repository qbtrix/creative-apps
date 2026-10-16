// TimelineKeysTests.swift: TL-10's key rules. SuiteKeyEditing steps along one
// track and is nil past either end, rounds a drag's points to frames, and
// clamps a move as a group (keys 40 and 46 by +5 with last frame 47 move both
// by +1, where FakeKeyEditing moves only 46). TimelinePick gives Shift
// .extend, Command .toggle, a plain press .replace, and a right press picks
// only an unpicked key (B6). No SwiftUI. macOS only.
import SuiteUI
import Testing

private let tracks = ["ball": [24, 0, 36, 12], "shadow": [12, 36]]

@Test func nextKeyStaysOnItsTrackInFrameOrder() {
    let k = SuiteKeyEditing()
    #expect(k.nextKey(after: LaneKey(track: "ball", frame: 0), direction: 1, tracks: tracks) == LaneKey(track: "ball", frame: 12))
    #expect(k.nextKey(after: LaneKey(track: "ball", frame: 12), direction: 1, tracks: tracks) == LaneKey(track: "ball", frame: 24))
    #expect(k.nextKey(after: LaneKey(track: "ball", frame: 24), direction: -1, tracks: tracks) == LaneKey(track: "ball", frame: 12))
    #expect(k.nextKey(after: LaneKey(track: "shadow", frame: 12), direction: 1, tracks: tracks) == LaneKey(track: "shadow", frame: 36))
}

@Test func nextKeyIsNilPastEitherEnd() {
    let k = SuiteKeyEditing()
    #expect(k.nextKey(after: LaneKey(track: "ball", frame: 36), direction: 1, tracks: tracks) == nil)
    #expect(k.nextKey(after: LaneKey(track: "ball", frame: 0), direction: -1, tracks: tracks) == nil)
    #expect(k.nextKey(after: LaneKey(track: "shadow", frame: 36), direction: 1, tracks: tracks) == nil)
    #expect(k.nextKey(after: LaneKey(track: "none", frame: 0), direction: 1, tracks: tracks) == nil)
    #expect(k.nextKey(after: LaneKey(track: "ball", frame: 5), direction: 1, tracks: tracks) == nil)
    #expect(k.nextKey(after: LaneKey(track: "ball", frame: 12), direction: 0, tracks: tracks) == nil)
}

@Test func frameDeltaRoundsPointsToWholeFrames() {
    let k = SuiteKeyEditing()
    let scale = TimelineScale(lastFrame: 47, frameWidth: 10)
    #expect(k.frameDelta(points: 14, scale: scale) == 1)
    #expect(k.frameDelta(points: 15, scale: scale) == 2)
    #expect(k.frameDelta(points: -26, scale: scale) == -3)
    #expect(k.frameDelta(points: 52, scale: scale) == 5)
    #expect(k.frameDelta(points: 30, scale: TimelineScale(lastFrame: 47, frameWidth: 0)) == 0)
    #expect(k.frameDelta(points: .nan, scale: scale) == 0)
    #expect(k.frameDelta(points: .infinity, scale: scale) == 0)
}

@Test func movedClampsTheGroupAndKeepsItsSpacing() {
    let keys: Set = [LaneKey(track: "ball", frame: 40), LaneKey(track: "ball", frame: 46)]
    let live = SuiteKeyEditing().moved(keys, by: 5, lastFrame: 47)
    #expect(live == [LaneKey(track: "ball", frame: 40): 41, LaneKey(track: "ball", frame: 46): 47])
    // The Fake clamps each key on its own: 40 moves the full 5, 46 only 1.
    let fake = FakeKeyEditing().moved(keys, by: 5, lastFrame: 47)
    #expect(fake[LaneKey(track: "ball", frame: 40)] == 45)
}

@Test func movedStopsTheGroupAtFrameZeroAndAcrossTracks() {
    let keys: Set = [LaneKey(track: "ball", frame: 3), LaneKey(track: "shadow", frame: 10)]
    let moved = SuiteKeyEditing().moved(keys, by: -8, lastFrame: 47)
    #expect(moved == [LaneKey(track: "ball", frame: 3): 0, LaneKey(track: "shadow", frame: 10): 7])
    #expect(SuiteKeyEditing().moved(keys, by: 2, lastFrame: 47)[LaneKey(track: "shadow", frame: 10)] == 12)
    #expect(SuiteKeyEditing().moved([], by: 2, lastFrame: 47).isEmpty)
}

@Test func aPressOnAKeyPicksByItsModifiers() {
    #expect(TimelinePick.mode(pressWith: []) == .replace)
    #expect(TimelinePick.mode(pressWith: .shift) == .extend)
    #expect(TimelinePick.mode(pressWith: .command) == .toggle)
    #expect(TimelinePick.mode(pressWith: .option) == .replace)
}

@Test func aRightPressPicksOnlyAnUnpickedKey() {
    #expect(TimelinePick.mode(rightPressOnPicked: false) == .replace)
    #expect(TimelinePick.mode(rightPressOnPicked: true) == nil)
}
