// EasingEditingContractTests.swift: FakeEasingEditing keeps the EasingEditing
// contract the easing editor's UI track builds on: presets, handle clamping,
// drag coalescing, exact undo and samples equal to FlareCore's curve. Runs on
// Linux and macOS.
import FlareCore
import FlareModel
import Testing

@Test func fakeStartsOnXZeroToTwentyFourWithEase() {
    let fake = FakeEasingEditing()
    #expect(fake.easingSegments.map(\.property) == ["opacity", "x", "x", "y"])
    #expect(fake.selectedEasingSegment == EasingSegment(property: "x", startFrame: 0, endFrame: 24))
    #expect(fake.currentEasing == .ease)
    #expect(fake.currentEasingPreset == .ease)
    #expect(fake.canUndo == false)
}

@Test func selectingASegmentShowsItsEasingAndUnknownOnesAreIgnored() {
    var fake = FakeEasingEditing()
    fake.selectEasingSegment(EasingSegment(property: "y", startFrame: 0, endFrame: 24))
    #expect(fake.currentEasing == .hold)
    fake.selectEasingSegment(EasingSegment(property: "z", startFrame: 0, endFrame: 1))
    #expect(fake.currentEasingPreset == .hold)
}

@Test func presetThenUndoRestoresTheOldEasing() {
    var fake = FakeEasingEditing()
    fake.setEasingPreset(.easeIn)
    #expect(fake.currentEasing == .cubicBezier(x1: 0.42, y1: 0, x2: 1, y2: 1))
    fake.undo()
    #expect(fake.currentEasing == .ease)
    #expect(fake.canUndo == false)
    #expect(fake == FakeEasingEditing())
}

@Test func handleXIsClampedAndYMayOvershoot() {
    var fake = FakeEasingEditing()
    fake.moveEasingHandle(.first, to: Point(x: -0.5, y: 1.4))
    fake.moveEasingHandle(.second, to: Point(x: 1.7, y: -0.3))
    #expect(fake.currentEasing == .cubicBezier(x1: 0, y1: 1.4, x2: 1, y2: -0.3))
    fake.moveEasingHandle(.first, to: Point(x: .nan, y: 0))
    #expect(fake.currentEasingHandles?.first == Point(x: 0, y: 1.4))
}

@Test func aLinearSegmentBecomesABezierFromTheCorners() {
    var fake = FakeEasingEditing()
    fake.selectEasingSegment(EasingSegment(property: "x", startFrame: 24, endFrame: 48))
    fake.moveEasingHandle(.second, to: Point(x: 0.5, y: 0.5))
    #expect(fake.currentEasing == .cubicBezier(x1: 0, y1: 0, x2: 0.5, y2: 0.5))
}

@Test func oneDragIsOneUndoStep() {
    var fake = FakeEasingEditing()
    for i in 1...10 { fake.moveEasingHandle(.first, to: Point(x: Double(i) / 10, y: 0)) }
    fake.endEasingHandleDrag()
    fake.moveEasingHandle(.first, to: Point(x: 0.2, y: 0.2))
    fake.endEasingHandleDrag()
    fake.undo()
    #expect(fake.currentEasingHandles?.first == Point(x: 1, y: 0))
    fake.undo()
    #expect(fake.currentEasing == .ease)
    #expect(fake.canUndo == false)
}

@Test(arguments: EasingPreset.allCases)
func samplesMatchFlareCoreWithinOneBillionth(_ preset: EasingPreset) {
    var fake = FakeEasingEditing()
    fake.setEasingPreset(preset)
    let samples = fake.easingCurveSamples(count: 1001)
    #expect(samples.count == 1001)
    #expect(samples.first == Point(x: 0, y: 0))
    #expect(samples.last == Point(x: 1, y: 1))
    let worst = samples.map { abs($0.y - preset.easing.value(at: $0.x)) }.max() ?? 1
    #expect(worst <= 1e-9)
    #expect(fake.easingCurveSamples(count: 1).isEmpty)
}
