// CanvasPathMarksTests.swift: PathMarks' geometry (CM-5). A smooth anchor and
// a corner anchor draw different shapes at a size that holds at every zoom;
// segments skip bad indices and curve only through handles; guide marks span
// the viewport. No SwiftUI views. macOS only.
import SuiteUI
import SwiftUI
import Testing

@Suite struct CanvasPathMarksTests {
    private let point = CGPoint(x: 40, y: 30)

    @Test func smoothAndCornerAnchorsDrawDifferentShapes() {
        let corner = PathMarkGeometry.anchorPath(PathMarkAnchor(point, kind: .corner), zoom: 2)
        let smooth = PathMarkGeometry.anchorPath(PathMarkAnchor(point, kind: .smooth), zoom: 2)
        let box = PathMarkGeometry.knobRect(at: point, zoom: 2)
        #expect(corner.boundingRect == box)
        #expect(abs(smooth.boundingRect.width - box.width) < 0.01 && abs(smooth.boundingRect.midX - box.midX) < 0.01)
        #expect(corner != smooth)
        // Just inside the box's corner: the square covers it, the circle doesn't.
        let nearCorner = CGPoint(x: box.minX + 0.5, y: box.minY + 0.5)
        #expect(corner.contains(nearCorner))
        #expect(!smooth.contains(nearCorner))
        let centre = CGPoint(x: box.midX, y: box.midY)
        #expect(corner.contains(centre) && smooth.contains(centre))
    }

    @Test func anchorsKeepTheirScreenSizeAtEveryZoom() {
        for zoom in [0.25, 1, 4] {
            let rect = PathMarkGeometry.knobRect(at: point, zoom: zoom)
            #expect(rect.width == SuiteSize.anchor && rect.height == SuiteSize.anchor)
            #expect(rect.midX == point.x * zoom && rect.midY == point.y * zoom)
        }
    }

    @Test func segmentsSkipIndicesThatNameNoAnchor() {
        let anchors = [PathMarkAnchor(.zero), PathMarkAnchor(point)]
        let bad = [PathMarkSegment(from: 0, to: 2), PathMarkSegment(from: -1, to: 1)]
        #expect(PathMarkGeometry.segmentsPath(anchors: anchors, segments: bad, zoom: 1).isEmpty)
        #expect(PathMarkGeometry.segmentsPath(anchors: [], segments: bad, zoom: 1).isEmpty)
    }

    @Test func aSegmentCurvesOnlyThroughHandles() {
        let line = [PathMarkAnchor(.zero), PathMarkAnchor(CGPoint(x: 10, y: 0))]
        let curve = [
            PathMarkAnchor(.zero, kind: .smooth, handleOut: CGPoint(x: 0, y: 10)),
            PathMarkAnchor(CGPoint(x: 10, y: 0)),
        ]
        let segment = [PathMarkSegment(from: 0, to: 1)]
        let straight = PathMarkGeometry.segmentsPath(anchors: line, segments: segment, zoom: 2)
        let bent = PathMarkGeometry.segmentsPath(anchors: curve, segments: segment, zoom: 2)
        #expect(elements(straight) == ["move", "line"])
        #expect(elements(bent) == ["move", "curve"])
        #expect(straight.boundingRect.maxX == 20)
    }

    @Test func handlesDrawALineAndAKnobEach() {
        let anchors = [
            PathMarkAnchor(point, kind: .smooth, handleIn: .zero, handleOut: CGPoint(x: 80, y: 60)),
            PathMarkAnchor(.zero),
        ]
        let lines = PathMarkGeometry.handleLines(anchors: anchors, zoom: 1)
        #expect(elements(lines) == ["move", "line", "move", "line"])
        let knobs = PathMarkGeometry.handleKnobs(anchors: anchors, zoom: 4)
        #expect(knobs.contains(CGPoint(x: 320, y: 240)))
        #expect(knobs.contains(.zero))
        #expect(PathMarkGeometry.handleKnobs(anchors: [PathMarkAnchor(point)], zoom: 1).isEmpty)
    }

    @Test func guidesSpanTheViewport() {
        // The view shows 50 pt past the artboard on the left and 20 pt above it.
        let viewport = CGRect(x: -50, y: -20, width: 900, height: 600)
        let vertical = PathMarkGeometry.guideLine(.vertical(100), zoom: 2, viewport: viewport)
        #expect(vertical.start == CGPoint(x: 200, y: viewport.minY))
        #expect(vertical.end == CGPoint(x: 200, y: viewport.maxY))
        let horizontal = PathMarkGeometry.guideLine(.horizontal(30), zoom: 0.5, viewport: viewport)
        #expect(horizontal.start == CGPoint(x: viewport.minX, y: 15))
        #expect(horizontal.end == CGPoint(x: viewport.maxX, y: 15))
    }

    private func elements(_ path: Path) -> [String] {
        var names: [String] = []
        path.forEach { element in
            switch element {
            case .move: names.append("move")
            case .line: names.append("line")
            case .curve: names.append("curve")
            case .quadCurve: names.append("quad")
            case .closeSubpath: names.append("close")
            }
        }
        return names
    }
}
