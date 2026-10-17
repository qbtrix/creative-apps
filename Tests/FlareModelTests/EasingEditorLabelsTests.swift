// EasingEditorLabelsTests.swift: the easing inspector's words come from the
// Model. A KEYFRAMES row says its numbers are frames, each handle row has a
// tooltip saying which handle and axis it moves and over what range (#1847),
// and the KEYFRAMES header shows only over rows (#1861). Runs on Linux and macOS.
import FlareCore
import FlareModel
import Testing

@Test func aSegmentRowSaysItsNumbersAreFrames() {
    let segment = EasingSegment(property: "x", startFrame: 0, endFrame: 24)
    #expect(segment.frameSpan == "frames 0 → 24")
    #expect(segment.title == "x frames 0 → 24")
}

@Test func eachHandleRowHasItsLabelAndADistinctTooltip() {
    let rows = EasingHandle.allCases.flatMap { handle in EasingAxis.allCases.map { (handle, $0) } }
    #expect(rows.map { $0.0.label($0.1) } == ["X1", "Y1", "X2", "Y2"])
    let helps = rows.map { $0.0.help($0.1) }
    #expect(helps == [
        "First handle, horizontal (time, 0 to 1)", "First handle, vertical (progress, -1 to 2)",
        "Second handle, horizontal (time, 0 to 1)", "Second handle, vertical (progress, -1 to 2)",
    ])
    #expect(EasingAxis.x.range == 0...1)
    #expect(EasingAxis.y.range == -1...2)
}

@Test func theKeyframesHeaderShowsOnlyOverRows() {
    #expect(FakeEasingEditing().showsKeyframesHeader)
    #expect(NoSegmentsEditing().showsKeyframesHeader == false)
}

/// A selected layer with no keys: no segments, nothing selected.
private struct NoSegmentsEditing: EasingEditing {
    var easingSegments: [EasingSegment] { [] }
    var selectedEasingSegment: EasingSegment? { nil }
    var currentEasing: Easing? { nil }
    var canUndo: Bool { false }
    var easingUnavailableReason: String? { nil }
    mutating func selectEasingSegment(_ segment: EasingSegment) {}
    mutating func setEasingPreset(_ preset: EasingPreset) {}
    mutating func moveEasingHandle(_ handle: EasingHandle, to point: Point) {}
    mutating func endEasingHandleDrag() {}
    func easingCurveSamples(count: Int) -> [Point] { [] }
    mutating func undo() {}
}
