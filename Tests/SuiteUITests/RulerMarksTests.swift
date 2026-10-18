// RulerMarksTests.swift: the ruler draws only the ticks and labels inside the
// visible stretch, so their count is bounded by its width, not the duration.
// The canvas ruler corner names the given unit, "px" by default (CM-9); the
// viewport's tool drags report `canvas-drag` samples, and it lists itself in
// `suite.controls`, disabled with a reason when it takes nothing. No SwiftUI
// rendering. macOS only.
import SwiftUI
import Testing

@testable import SuiteUI

@MainActor
@Test func rulerCornerReadsTheGivenUnitPixelsByDefault() {
    #expect(RulerCorner().unit == "px")
    #expect(RulerCorner(unit: "pt").unit == "pt")
    let size = CGSize(width: 10, height: 10)
    #expect(CanvasViewport(documentSize: size, zoom: 1) { Color.clear } overlay: { EmptyView() }.unit == "px")
}

@Test func canvasDragSamplesCarryTheirSeries() {
    let sample = CanvasDragProbe.sample(eventTime: 2, shownAt: 2.01)
    #expect(sample == ProbeSample(series: "canvas-drag", eventTime: 2, shownAt: 2.01))
    var probe = FakeFrameProbe()
    probe.record(sample)
    #expect(probe.summary(of: "canvas-drag", refreshInterval: 1.0 / 60).count == 1)
}

@MainActor
@Test func canvasViewportRegistersEnabledOnlyWhileItTakesInput() {
    let size = CGSize(width: 10, height: 10)
    let inert = CanvasViewport(documentSize: size, zoom: 1) { Color.clear } overlay: { EmptyView() }
    let dragged = CanvasViewport(documentSize: size, zoom: 1, onDrag: { _, _ in }) { Color.clear } overlay: { EmptyView() }
    let zoomed = CanvasViewport(documentSize: size, zoom: 1, onZoom: { _ in }) { Color.clear } overlay: { EmptyView() }
    #expect(inert.controlEntry == ControlEntry(id: "suite.canvas", enabled: false, reason: CanvasDragProbe.inertReason))
    #expect(dragged.controlEntry == ControlEntry(id: "suite.canvas", enabled: true))
    #expect(zoomed.controlEntry.enabled)
    #expect(zoomed.controlEntry.reason == nil)
}

@Test func rulerMarksStayBoundedNearIntMax() {
    let mapping = FrameMapping(duration: .max - 1, frameWidth: 10)
    for start in [0, 1e9, mapping.contentWidth / 2, mapping.contentWidth - 1200] {
        let marks = mapping.rulerMarks(visibleX: start...(start + 1200), tickSpacing: 6, labelSpacing: 48)
        #expect(marks.ticks.count <= 1200 / 6 + 1)
        #expect(marks.labels.count <= 1200 / 48 + 1)
        #expect(marks.ticks.allSatisfy { (0...mapping.duration).contains($0) })
    }
}

@Test func rulerMarksSpanTheWholeVisibleStretch() {
    let mapping = FrameMapping(duration: 120, frameWidth: 10)
    let marks = mapping.rulerMarks(visibleX: 0...1200, tickSpacing: 6, labelSpacing: 48)
    #expect(marks.ticks == Array(0...120))
    #expect(marks.labels == Array(stride(from: 0, through: 120, by: 5)))
}

@Test func rulerMarksStartInsideAScrolledStretch() {
    let mapping = FrameMapping(duration: 10_000, frameWidth: 2)
    let marks = mapping.rulerMarks(visibleX: 1001...1100, tickSpacing: 6, labelSpacing: 48)
    #expect(marks.ticks == [505, 510, 515, 520, 525, 530, 535, 540, 545, 550])
    #expect(marks.labels == [550])
}

@Test func rulerMarksOnAZeroWidthHoldFrameZeroAlone() {
    let mapping = FrameMapping(duration: .max, frameWidth: 0)
    #expect(mapping.rulerMarks(visibleX: 0...500, tickSpacing: 6, labelSpacing: 48).ticks == [0])
    #expect(mapping.rulerMarks(visibleX: 10...500, tickSpacing: 6, labelSpacing: 48).labels.isEmpty)
}

@Test func rulerMarksSurviveSillySpacing() {
    let mapping = FrameMapping(duration: .max, frameWidth: 0.001)
    let marks = mapping.rulerMarks(visibleX: 0...100, tickSpacing: 0, labelSpacing: -5)
    #expect(marks.ticks.count <= 101)
    #expect(marks.labels.count <= 101)
}

@Test func rulerMarksOutsideTheContentAreEmpty() {
    let mapping = FrameMapping(duration: 48, frameWidth: 10)
    #expect(mapping.rulerMarks(visibleX: 600...900, tickSpacing: 6, labelSpacing: 48).ticks.isEmpty)
    #expect(mapping.rulerMarks(visibleX: -300 ... -10, tickSpacing: 6, labelSpacing: 48).ticks.isEmpty)
}
