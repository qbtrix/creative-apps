// CanvasMarks+Points.swift: the point mark, a ring with a cross at one
// document point (a clone source, a sampled pixel) drawn in a CanvasViewport's
// overlay. Only its centre follows the zoom: the ring and cross keep their
// size in view points, so the mark reads the same at 25 % and at 400 %. A
// black line over a white halo, so it reads on any pixels. It never takes a
// click and is hidden from accessibility; the app gives it an element.
import SwiftUI

/// A point mark at a document point: a `pointMarkRing` ring and a
/// `pointMarkCross` cross, ink over a paper halo, fixed on screen.
public struct CanvasPointMark: View {
    private let point: CGPoint
    private let zoom: Double

    /// The mark never takes a click: the canvas gesture under it does.
    public static let takesHits = false
    /// The mark is hidden from accessibility; an app adds its own element.
    public static let hiddenFromAccessibility = true

    /// `point` in document pixels; `zoom` in points per pixel.
    public init(point: CGPoint, zoom: Double) {
        self.point = point
        self.zoom = zoom
    }

    /// The mark's frame in view points, its halo included: centred on `point`
    /// at `zoom`, its size the same at every zoom.
    public static func frame(point: CGPoint, zoom: Double) -> CGRect {
        let side = SuiteSize.pointMarkRing + SuiteSize.pointMarkPaper
        let center = CGPoint(x: point.x * zoom, y: point.y * zoom)
        return CGRect(x: center.x - side / 2, y: center.y - side / 2, width: side, height: side)
    }

    public var body: some View {
        let shape = PointMarkShape(center: CGPoint(x: point.x * zoom, y: point.y * zoom))
        ZStack {
            shape.stroke(SuiteColor.overlayPaper, style: StrokeStyle(lineWidth: SuiteSize.pointMarkPaper, lineCap: .round))
            shape.stroke(SuiteColor.overlayInk, style: StrokeStyle(lineWidth: SuiteSize.pointMarkInk, lineCap: .round))
        }
        .allowsHitTesting(Self.takesHits)
        .accessibilityHidden(Self.hiddenFromAccessibility)
    }
}

/// The ring and cross around `center`, in view points.
private struct PointMarkShape: Shape {
    let center: CGPoint

    func path(in _: CGRect) -> Path {
        let ring = SuiteSize.pointMarkRing / 2
        let arm = SuiteSize.pointMarkCross / 2
        var path = Path()
        path.addEllipse(in: CGRect(x: center.x - ring, y: center.y - ring, width: 2 * ring, height: 2 * ring))
        path.move(to: CGPoint(x: center.x - arm, y: center.y))
        path.addLine(to: CGPoint(x: center.x + arm, y: center.y))
        path.move(to: CGPoint(x: center.x, y: center.y - arm))
        path.addLine(to: CGPoint(x: center.x, y: center.y + arm))
        return path
    }
}
