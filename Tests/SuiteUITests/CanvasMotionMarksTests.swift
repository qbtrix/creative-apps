// CanvasMotionMarksTests.swift: MotionPathMarks draws one dot per frame
// point, centered on the point at the zoom and the same size on screen at
// every zoom; a point that isn't a number draws none. GhostLayer draws at its
// opacity, kept to 0...1. SuiteMotionMarksSnapshots checks the pixels.
// macOS only.
import CoreGraphics
import SuiteUI
import SwiftUI
import Testing

@MainActor
@Suite struct CanvasMotionMarksTests {
    nonisolated static let path = [CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 5), CGPoint(x: 20, y: 20), CGPoint(x: 35, y: 20)]

    @Test(arguments: [0.25, 1, 4])
    func oneDotPerFramePoint(zoom: Double) {
        let dots = MotionPathMarks.dots(Self.path, zoom: zoom)
        #expect(dots.count == Self.path.count)
        for (dot, point) in zip(dots, Self.path) {
            #expect(abs(dot.midX - point.x * zoom) < 1e-9)
            #expect(abs(dot.midY - point.y * zoom) < 1e-9)
            #expect(dot.width == SuiteSize.curvePreviewDot)
            #expect(dot.height == SuiteSize.curvePreviewDot)
        }
    }

    @Test func noPointsDrawNoDots() {
        #expect(MotionPathMarks.dots([], zoom: 1).isEmpty)
        #expect(MotionPathMarks.centers([], zoom: 1).isEmpty)
    }

    @Test func aPointThatIsNotANumberDrawsNone() {
        let points = [CGPoint(x: 1, y: 1), CGPoint(x: .nan, y: 2), CGPoint(x: 3, y: .infinity), CGPoint(x: 4, y: 4)]
        #expect(MotionPathMarks.centers(points, zoom: 2) == [CGPoint(x: 2, y: 2), CGPoint(x: 8, y: 8)])
    }

    @Test func aZoomThatIsNotANumberIsOneHundredPercent() {
        #expect(MotionPathMarks.centers([CGPoint(x: 7, y: 9)], zoom: .nan) == [CGPoint(x: 7, y: 9)])
    }

    @Test(arguments: [(0.35, 0.35), (0, 0), (1, 1), (-0.5, 0), (2, 1), (.nan, 0), (.infinity, 1)])
    func ghostDrawsAtItsOpacity(given: Double, drawn: Double) {
        let ghost = GhostLayer(content: { Color.clear }, opacity: given)
        #expect(ghost.drawnOpacity == drawn)
        #expect(GhostLayer<Color>.drawn(given) == drawn)
    }
}
