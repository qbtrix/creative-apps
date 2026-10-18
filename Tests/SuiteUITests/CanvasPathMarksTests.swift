// CanvasPathMarksTests.swift (CM-5): PathMarks draws a corner anchor and a
// smooth anchor as different shapes, at one on-screen size at any zoom, and
// ViewportGuideMarks' lines span the viewport. Geometry only. macOS only.
import SuiteUI
import SwiftUI
import Testing

@Test func smoothAndCornerAnchorsDrawDifferentShapes() {
    let point = CGPoint(x: 40, y: 30)
    let corner = PathMarks.anchorShape(PathAnchor(point: point, kind: .corner), zoom: 1)
    let smooth = PathMarks.anchorShape(PathAnchor(point: point, kind: .smooth), zoom: 1)
    #expect(corner != smooth)
    #expect(corner.boundingRect == smooth.boundingRect)
    // The square fills its corner; the circle doesn't.
    let nearCorner = CGPoint(x: point.x - SuiteSize.anchor / 2 + 0.5, y: point.y - SuiteSize.anchor / 2 + 0.5)
    #expect(corner.contains(nearCorner))
    #expect(!smooth.contains(nearCorner))
}

@Test(arguments: [0.25, 1, 4])
func anchorMarksKeepTheirSizeOnScreen(zoom: Double) {
    for kind in [PathAnchor.Kind.corner, .smooth] {
        let rect = PathMarks.anchorShape(PathAnchor(point: CGPoint(x: 100, y: 50), kind: kind), zoom: zoom).boundingRect
        #expect(abs(rect.width - SuiteSize.anchor) < 0.001)
        #expect(abs(rect.height - SuiteSize.anchor) < 0.001)
        #expect(abs(rect.midX - 100 * zoom) < 0.001)
        #expect(abs(rect.midY - 50 * zoom) < 0.001)
    }
}

@Test func onlySmoothAnchorsDrawHandles() {
    let handles = (CGPoint(x: 0, y: 10), CGPoint(x: 20, y: 10))
    let corner = PathAnchor(point: CGPoint(x: 10, y: 10), kind: .corner, handleIn: handles.0, handleOut: handles.1)
    let smooth = PathAnchor(point: CGPoint(x: 10, y: 10), kind: .smooth, handleIn: handles.0, handleOut: handles.1)
    #expect(PathMarks.handleLines(anchors: [corner], zoom: 1).isEmpty)
    #expect(PathMarks.handleLines(anchors: [smooth], zoom: 2).boundingRect == CGRect(x: 0, y: 20, width: 40, height: 0))
}

@Test func segmentsCurveThroughHandlesAndSkipBadIndices() {
    let anchors = [
        PathAnchor(point: CGPoint(x: 0, y: 0), kind: .corner),
        PathAnchor(point: CGPoint(x: 100, y: 0), kind: .smooth, handleIn: CGPoint(x: 50, y: 80)),
    ]
    let straight = PathMarks.outline(anchors: anchors, segments: [PathSegment(from: 1, to: 0)], zoom: 1)
    let curved = PathMarks.outline(anchors: anchors, segments: [PathSegment(from: 0, to: 1)], zoom: 1)
    #expect(straight.boundingRect.height == 0)
    #expect(curved.boundingRect.height > 0)
    #expect(PathMarks.outline(anchors: anchors, segments: [PathSegment(from: 0, to: 2)], zoom: 1).isEmpty)
    #expect(PathMarks.outline(anchors: [], segments: [PathSegment(from: 0, to: 1)], zoom: 1).isEmpty)
    #expect(PathMarks.anchorMarks(anchors: [], zoom: 1).isEmpty)
}

@Test func guideMarksSpanTheViewport() {
    let viewport = CGRect(x: 20, y: 10, width: 300, height: 200)
    let lines = ViewportGuideMarks.lines(guides: [.vertical(x: 50), .horizontal(y: 40)], zoom: 2, viewport: viewport)
    #expect(lines == [
        GuideLine(start: CGPoint(x: 100, y: 10), end: CGPoint(x: 100, y: 210)),
        GuideLine(start: CGPoint(x: 20, y: 80), end: CGPoint(x: 320, y: 80)),
    ])
}

@Test func guideMarksSkipBadInput() {
    let viewport = CGRect(x: 0, y: 0, width: 100, height: 100)
    #expect(ViewportGuideMarks.lines(guides: [.vertical(x: .nan), .horizontal(y: .infinity)], zoom: 1, viewport: viewport).isEmpty)
    #expect(ViewportGuideMarks.lines(guides: [.vertical(x: 5)], zoom: 1, viewport: .zero).isEmpty)
    #expect(ViewportGuideMarks.lines(guides: [.vertical(x: 5)], zoom: .nan, viewport: viewport).first?.start.x == 5)
}
