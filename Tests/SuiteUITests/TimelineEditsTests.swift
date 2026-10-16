// TimelineEditsTests.swift: TL-13's drag rules. SuiteTimelineEditing snaps a
// frame to the playhead when their ticks are within the radius (at 10 pt per
// frame and radius 8, a key 7 pt off snaps, 9 pt off doesn't, exactly 8 is a
// tie the playhead takes) and trims a span inside 0...lastFrame, never
// shorter than one frame, the other edge fixed, where FakeTimelineEditing
// never snaps and lets a trim collapse to one tick. TimelineDragSteps sends a
// running total only as the change since the last send: totals 1, 2, 0 send
// +1, +1, -2, and a repeat sends nothing. No SwiftUI. macOS only.
import SuiteUI
import Testing

private let scale = TimelineScale(lastFrame: 59, frameWidth: 10)

@Test func aFrameWithinTheRadiusSnapsToThePlayhead() {
    let e = SuiteTimelineEditing()
    // Ticks 0.7 frames apart are 7 pt apart: in. 0.9 frames are 9 pt: out.
    let fine = TimelineScale(lastFrame: 59, frameWidth: 7)
    #expect(e.snapped(29, playhead: 30, radius: 8, scale: fine) == 30)
    #expect(e.snapped(31, playhead: 30, radius: 8, scale: fine) == 30)
    let wide = TimelineScale(lastFrame: 59, frameWidth: 9)
    #expect(e.snapped(29, playhead: 30, radius: 8, scale: wide) == 29)
    #expect(e.snapped(31, playhead: 30, radius: 8, scale: wide) == 31)
    #expect(e.snapped(12, playhead: 30, radius: 8, scale: scale) == 12)
    // The Fake never snaps.
    #expect(FakeTimelineEditing().snapped(29, playhead: 30, radius: 8, scale: fine) == 29)
}

@Test func aTieOnTheRadiusGoesToThePlayhead() {
    let e = SuiteTimelineEditing()
    let tie = TimelineScale(lastFrame: 59, frameWidth: 8)
    #expect(e.snapped(29, playhead: 30, radius: 8, scale: tie) == 30)
    #expect(e.snapped(31, playhead: 30, radius: 8, scale: tie) == 30)
    #expect(e.snapped(28, playhead: 30, radius: 8, scale: tie) == 28)
}

@Test func aBrokenScaleOrRadiusNeverSnaps() {
    let e = SuiteTimelineEditing()
    #expect(e.snapped(29, playhead: 30, radius: 8, scale: TimelineScale(lastFrame: 59, frameWidth: 0)) == 29)
    #expect(e.snapped(29, playhead: 30, radius: 8, scale: TimelineScale(lastFrame: 59, frameWidth: .nan)) == 29)
    #expect(e.snapped(29, playhead: 30, radius: .nan, scale: scale) == 29)
    #expect(e.snapped(30, playhead: 30, radius: 0, scale: scale) == 30)
}

@Test func trimmedMovesOneEdgeAndKeepsTheOther() {
    let e = SuiteTimelineEditing()
    #expect(e.trimmed(20...50, edge: .end, to: 40, lastFrame: 59) == 20...40)
    #expect(e.trimmed(20...40, edge: .start, to: 25, lastFrame: 59) == 25...40)
    #expect(e.trimmed(20...50, edge: .start, to: 5, lastFrame: 59) == 5...50)
}

@Test func trimmedNeverGoesShorterThanOneFrame() {
    let e = SuiteTimelineEditing()
    #expect(e.trimmed(20...50, edge: .start, to: 50, lastFrame: 59) == 49...50)
    #expect(e.trimmed(20...50, edge: .start, to: 58, lastFrame: 59) == 49...50)
    #expect(e.trimmed(20...50, edge: .end, to: 20, lastFrame: 59) == 20...21)
    #expect(e.trimmed(20...50, edge: .end, to: 3, lastFrame: 59) == 20...21)
    // The Fake has no floor: the span collapses to one tick.
    #expect(FakeTimelineEditing().trimmed(20...50, edge: .start, to: 58, lastFrame: 59) == 58...58)
}

@Test func trimmedClampsToZeroThroughTheLastFrame() {
    let e = SuiteTimelineEditing()
    #expect(e.trimmed(20...50, edge: .start, to: -9, lastFrame: 59) == 0...50)
    #expect(e.trimmed(20...50, edge: .end, to: 400, lastFrame: 59) == 20...59)
    #expect(e.trimmed(0...0, edge: .start, to: 3, lastFrame: 59) == 0...0)
    #expect(e.trimmed(59...59, edge: .end, to: 70, lastFrame: 59) == 59...59)
    #expect(e.trimmed(20...50, edge: .end, to: 10, lastFrame: -4) == 0...0)
}

@Test func theStepRuleSendsOnlyEachChange() {
    var steps = TimelineDragSteps()
    #expect(steps.step(toTotal: 1) == 1)
    #expect(steps.step(toTotal: 2) == 1)
    #expect(steps.step(toTotal: 0) == -2)
    #expect(steps.lastSent == 0)
}

@Test func theStepRuleSendsNothingForARepeat() {
    var steps = TimelineDragSteps()
    #expect(steps.step(toTotal: 0) == nil)
    #expect(steps.step(toTotal: 3) == 3)
    #expect(steps.step(toTotal: 3) == nil)
    #expect(steps.step(toTotal: 3) == nil)
    #expect(steps.lastSent == 3)
    #expect(steps.step(toTotal: 5) == 2)
}
