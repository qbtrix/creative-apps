// TimelineFakeTests.swift: the timeline Fakes (UC11 TimelineMapping, UC12
// KeyEditing, TimelineEditing) give the contracts' main.swift results and keep
// the gap each one has on purpose: a label every 10 frames and no ticks, each
// key clamped on its own, no snap, a trim that may invert to frame...frame.
// The live tests (TL-10, TL-13) rely on these gaps. No SwiftUI. macOS only.
import SuiteUI
import Testing

private let scale = TimelineScale(lastFrame: 47, frameWidth: 10)

@Test func fakeMappingGivesMainSwiftsFrameAndClampsIt() {
    let m = FakeTimelineMapping()
    #expect(m.frame(atX: 300, scale: scale) == 30)
    #expect(m.x(forFrame: 30, scale: scale) == 300)
    #expect(m.frame(atX: -50, scale: scale) == 0)
    #expect(m.frame(atX: 10_000, scale: scale) == 47)
    #expect(m.frame(atX: .nan, scale: scale) == 0)
    #expect(m.frame(atX: 300, scale: TimelineScale(lastFrame: 47, frameWidth: 0)) == 0)
}

@Test func fakeMappingFindsTheFirstKeyInTolerance() {
    let m = FakeTimelineMapping()
    #expect(m.keyframe(nearX: 126, in: [0, 12, 24], tolerance: 8, scale: scale) == 12)
    #expect(m.keyframe(nearX: 190, in: [0, 12, 24], tolerance: 8, scale: scale) == nil)
}

@Test func fakeMappingLabelsEveryTenFramesWithNoTicks() {
    let marks = FakeTimelineMapping().rulerMarks(visible: 125...470, minimumSpacing: 400, scale: scale)
    #expect(marks.ticks.isEmpty)
    #expect(marks.labels == [10, 20, 30, 40])
}

@Test func fakeKeyEditingStepsAlongOneTrack() {
    let k = FakeKeyEditing()
    let tracks = ["ball": [24, 0, 12], "shadow": [6]]
    #expect(k.nextKey(after: LaneKey(track: "ball", frame: 12), direction: 1, tracks: tracks) == LaneKey(track: "ball", frame: 24))
    #expect(k.nextKey(after: LaneKey(track: "ball", frame: 12), direction: -1, tracks: tracks) == LaneKey(track: "ball", frame: 0))
    #expect(k.nextKey(after: LaneKey(track: "ball", frame: 24), direction: 1, tracks: tracks) == nil)
    #expect(k.nextKey(after: LaneKey(track: "ball", frame: 0), direction: -1, tracks: tracks) == nil)
    #expect(k.nextKey(after: LaneKey(track: "none", frame: 0), direction: 1, tracks: tracks) == nil)
}

@Test func fakeKeyEditingRoundsADragToFrames() {
    let k = FakeKeyEditing()
    #expect(k.frameDelta(points: 14, scale: scale) == 1)
    #expect(k.frameDelta(points: 15, scale: scale) == 2)
    #expect(k.frameDelta(points: 15, scale: TimelineScale(lastFrame: 47, frameWidth: 0)) == 0)
    #expect(k.frameDelta(points: .infinity, scale: scale) == 0)
}

@Test func fakeKeyEditingClampsEachKeyOnItsOwn() {
    let a = LaneKey(track: "ball", frame: 40), b = LaneKey(track: "ball", frame: 46)
    let moved = FakeKeyEditing().moved([a, b], by: 5, lastFrame: 47)
    #expect(moved == [a: 45, b: 47])       // the live group clamp moves both by +1
    let back = FakeKeyEditing().moved([LaneKey(track: "ball", frame: 2)], by: -5, lastFrame: 47)
    #expect(back == [LaneKey(track: "ball", frame: 2): 0])
}

@Test func fakeEditingNeverSnaps() {
    let e = FakeTimelineEditing()
    #expect(e.snapped(29, playhead: 30, radius: 8, scale: scale) == 29)
    #expect(e.snapped(30, playhead: 30, radius: 8, scale: scale) == 30)
}

@Test func fakeEditingTrimsKeepingTheOtherEdge() {
    let e = FakeTimelineEditing()
    #expect(e.trimmed(20...50, edge: .end, to: 40, lastFrame: 59) == 20...40)
    #expect(e.trimmed(20...50, edge: .start, to: 25, lastFrame: 59) == 25...50)
    #expect(e.trimmed(20...50, edge: .end, to: 99, lastFrame: 59) == 20...59)
    #expect(e.trimmed(20...50, edge: .start, to: -5, lastFrame: 59) == 0...50)
}

@Test func fakeEditingTrimHasNoOneFrameFloor() {
    let e = FakeTimelineEditing()
    #expect(e.trimmed(20...50, edge: .end, to: 20, lastFrame: 59) == 20...20)
    #expect(e.trimmed(20...50, edge: .end, to: 10, lastFrame: 59) == 10...10)
    #expect(e.trimmed(20...50, edge: .start, to: 55, lastFrame: 59) == 55...55)
}

@Test func timelineValueEnumsKeepTheirRawValues() {
    #expect(TimeUnit.allCases == [.frames, .timecode])
    #expect(SpanEdge.start.rawValue == "start" && SpanEdge.end.rawValue == "end")
    #expect([PickMode.replace, .extend, .toggle].map(\.rawValue) == ["replace", "extend", "toggle"])
}
