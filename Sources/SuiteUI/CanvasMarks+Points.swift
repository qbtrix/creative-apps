// CanvasMarks+Points.swift: CanvasPointMark, one document point marked
// inside a CanvasViewport's overlay, such as a clone source or an anchor:
// a ring with a short cross centred on the point. The point moves with the
// zoom; the mark's size does not, so it reads the same at every zoom. Ink
// over a wider paper halo, black and white, so it reads on any pixels. Like
// the other canvas marks it takes no click and is hidden from accessibility.
import SwiftUI

/// A mark at one document point, the same size on screen at every zoom.
public struct CanvasPointMark: View {
    private let point: CGPoint
    private let zoom: Double

    /// `point` in document pixels; `zoom` in points per pixel.
    public init(point: CGPoint, zoom: Double) {
        self.point = point
        self.zoom = zoom
    }

    /// The mark never takes a click: the canvas gesture under it does.
    public static let takesHits = false
    /// The mark is never an accessibility element.
    public static let hiddenFromAccessibility = true

    /// The ring's square in view points, centred on `point` at `zoom`: always
    /// `pointMarkRing` wide. A zoom that is not finite or not above 0 counts
    /// as 1; nil for a point that is not finite.
    public static func ring(point: CGPoint, zoom: Double) -> CGRect? {
        guard point.x.isFinite, point.y.isFinite else { return nil }
        let scale = zoom.isFinite && zoom > 0 ? zoom : 1
        let side = SuiteSize.pointMarkRing
        return CGRect(x: point.x * scale - side / 2, y: point.y * scale - side / 2, width: side, height: side)
    }

    /// The ring and its cross, `pointMarkCross` long each way, in view points;
    /// empty when `ring(point:zoom:)` is nil.
    public static func path(point: CGPoint, zoom: Double) -> Path {
        var path = Path()
        guard let ring = ring(point: point, zoom: zoom) else { return path }
        let arm = SuiteSize.pointMarkCross / 2
        path.addEllipse(in: ring)
        path.move(to: CGPoint(x: ring.midX - arm, y: ring.midY))
        path.addLine(to: CGPoint(x: ring.midX + arm, y: ring.midY))
        path.move(to: CGPoint(x: ring.midX, y: ring.midY - arm))
        path.addLine(to: CGPoint(x: ring.midX, y: ring.midY + arm))
        return path
    }

    public var body: some View {
        let shape = PointMarkShape(outline: Self.path(point: point, zoom: zoom))
        ZStack {
            shape.stroke(
                SuiteColor.overlayPaper, style: StrokeStyle(lineWidth: SuiteSize.pointMarkPaper, lineCap: .round))
            shape.stroke(SuiteColor.overlayInk, style: StrokeStyle(lineWidth: SuiteSize.pointMarkInk, lineCap: .round))
        }
        .allowsHitTesting(Self.takesHits)
        .accessibilityHidden(Self.hiddenFromAccessibility)
    }
}

/// A fixed path in the overlay's coordinates, for stroking.
private struct PointMarkShape: Shape {
    let outline: Path

    func path(in _: CGRect) -> Path { outline }
}
