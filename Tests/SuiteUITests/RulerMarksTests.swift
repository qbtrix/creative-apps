// RulerMarksTests.swift: the ruler draws only the ticks and labels inside the
// visible stretch, so their count is bounded by its width, not the duration.
// The canvas rulers' corner reads the unit it is given, "px" by default, so
// Photo's rulers stay in pixels while Design's say points (#264). The
// viewport's drag samples carry series `canvas-drag` (SP2). No rendering.
// macOS only.
@testable import SuiteUI
import SwiftUI
import Testing

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

@Test func theRulerCornerReadsItsUnitPixelsByDefault() {
    #expect(RulerCorner().unit == "px")
    #expect(RulerCorner(unit: "pt").unit == "pt")
}

@MainActor
@Test func theViewportPassesItsRulerUnitToTheCorner() {
    let size = CGSize(width: 100, height: 100)
    let pixels = CanvasViewport(documentSize: size, zoom: 1) { Color.clear } overlay: { EmptyView() }
    let points = CanvasViewport(documentSize: size, zoom: 1, rulerUnit: "pt") { Color.clear } overlay: { EmptyView() }
    let older = CanvasViewport(documentSize: size, zoom: 1, unit: "pt") { Color.clear } overlay: { EmptyView() }
    #expect(pixels.rulerUnit == "px")
    #expect(points.rulerUnit == "pt")
    #expect(older.rulerUnit == "pt")
}

@Test func theCanvasDragSeriesIsCanvasDrag() {
    #expect(CanvasProbe.dragSeries == "canvas-drag")
}

@Test func aCanvasDragSampleCarriesItsSeriesAndTimes() {
    #expect(CanvasProbe.sample(eventTime: 1, shownAt: 2) == ProbeSample(series: "canvas-drag", eventTime: 1, shownAt: 2))
    #expect(CanvasProbe.sample(eventTime: 3.5, shownAt: 3.25).eventTime == 3.5)
    #expect(CanvasProbe.sample(eventTime: 3.5, shownAt: 3.25).shownAt == 3.25)
}
