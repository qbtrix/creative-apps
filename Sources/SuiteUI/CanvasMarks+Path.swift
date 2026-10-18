// CanvasMarks+Path.swift: a pen path's marks and the ruler guides, drawn in a
// CanvasViewport's overlay (origin at the artboard's top-left, document
// pixels times the zoom). Anchors are `anchor` squares for corners and circles
// for smooth points; curve handles are 1 pt lines ending in `anchor` circles
// (docs/design.md, Stage marks). Anchors keep their on-screen size at every
// zoom. A guide is a 1 pt `accent` line across the whole visible viewport, so
// it shows past the artboard's edge. The geometry is in `PathMarkGeometry`,
// plain functions the tests call; the views only draw. Marks never take a
// click and are hidden from accessibility; the canvas gesture acts.
import SwiftUI

/// One pen anchor in document pixels, with its optional curve handles.
public struct PathMarkAnchor: Hashable, Sendable {
    /// A corner draws a square; a smooth point (its handles in line) a circle.
    public enum Kind: Hashable, Sendable { case corner, smooth }

    public let point: CGPoint
    public let kind: Kind
    public let handleIn: CGPoint?
    public let handleOut: CGPoint?

    public init(_ point: CGPoint, kind: Kind = .corner, handleIn: CGPoint? = nil, handleOut: CGPoint? = nil) {
        (self.point, self.kind, self.handleIn, self.handleOut) = (point, kind, handleIn, handleOut)
    }
}

/// A segment joining two anchors by index: a cubic through the first one's
/// `handleOut` and the second one's `handleIn`, a line when both are absent.
public struct PathMarkSegment: Hashable, Sendable {
    public let from: Int
    public let to: Int

    public init(from: Int, to: Int) {
        (self.from, self.to) = (from, to)
    }
}

/// A ruler guide at a document coordinate: a vertical one at `x`, a
/// horizontal one at `y`, in pixels.
public enum CanvasGuide: Hashable, Sendable {
    case vertical(Double)
    case horizontal(Double)
}

/// The marks' geometry in overlay points. Pure: no view state.
public enum PathMarkGeometry {
    /// `point` (document pixels) in overlay points at `zoom`.
    public static func onScreen(_ point: CGPoint, zoom: Double) -> CGPoint {
        CGPoint(x: point.x * zoom, y: point.y * zoom)
    }

    /// The `anchor`-sized square centred on `point` at `zoom`; its size never
    /// scales with the zoom.
    public static func knobRect(at point: CGPoint, zoom: Double) -> CGRect {
        let centre = onScreen(point, zoom: zoom)
        let side = SuiteSize.anchor
        return CGRect(x: centre.x - side / 2, y: centre.y - side / 2, width: side, height: side)
    }

    /// The anchor's outline: a square for a corner, a circle for a smooth point.
    public static func anchorPath(_ anchor: PathMarkAnchor, zoom: Double) -> Path {
        let rect = knobRect(at: anchor.point, zoom: zoom)
        switch anchor.kind {
        case .corner: return Path(rect)
        case .smooth: return Path(ellipseIn: rect)
        }
    }

    /// Every segment whose two indices name anchors; others are skipped.
    public static func segmentsPath(anchors: [PathMarkAnchor], segments: [PathMarkSegment], zoom: Double) -> Path {
        Path { path in
            for segment in segments
            where anchors.indices.contains(segment.from) && anchors.indices.contains(segment.to) {
                let start = anchors[segment.from], end = anchors[segment.to]
                path.move(to: onScreen(start.point, zoom: zoom))
                let target = onScreen(end.point, zoom: zoom)
                if start.handleOut == nil && end.handleIn == nil {
                    path.addLine(to: target)
                } else {
                    path.addCurve(
                        to: target,
                        control1: onScreen(start.handleOut ?? start.point, zoom: zoom),
                        control2: onScreen(end.handleIn ?? end.point, zoom: zoom))
                }
            }
        }
    }

    /// The handle lines, each from its anchor to the handle.
    public static func handleLines(anchors: [PathMarkAnchor], zoom: Double) -> Path {
        Path { path in
            for anchor in anchors {
                for handle in [anchor.handleIn, anchor.handleOut].compactMap({ $0 }) {
                    path.move(to: onScreen(anchor.point, zoom: zoom))
                    path.addLine(to: onScreen(handle, zoom: zoom))
                }
            }
        }
    }

    /// The circles at the handles' ends.
    public static func handleKnobs(anchors: [PathMarkAnchor], zoom: Double) -> Path {
        Path { path in
            for anchor in anchors {
                for handle in [anchor.handleIn, anchor.handleOut].compactMap({ $0 }) {
                    path.addEllipse(in: knobRect(at: handle, zoom: zoom))
                }
            }
        }
    }

    /// A guide's line across `viewport` (overlay points): a vertical guide
    /// from its top to its bottom, a horizontal one from its left to its right.
    public static func guideLine(_ guide: CanvasGuide, zoom: Double, viewport: CGRect) -> (start: CGPoint, end: CGPoint) {
        switch guide {
        case .vertical(let x):
            (CGPoint(x: x * zoom, y: viewport.minY), CGPoint(x: x * zoom, y: viewport.maxY))
        case .horizontal(let y):
            (CGPoint(x: viewport.minX, y: y * zoom), CGPoint(x: viewport.maxX, y: y * zoom))
        }
    }
}

/// A pen path's segments, curve handles and anchors.
public struct PathMarks: View {
    private let anchors: [PathMarkAnchor]
    private let segments: [PathMarkSegment]
    private let zoom: Double

    /// `anchors` in document pixels; `segments` join them by index; `zoom` in
    /// points per pixel.
    public init(anchors: [PathMarkAnchor], segments: [PathMarkSegment], zoom: Double) {
        (self.anchors, self.segments, self.zoom) = (anchors, segments, zoom)
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            PathMarkGeometry.segmentsPath(anchors: anchors, segments: segments, zoom: zoom)
                .stroke(SuiteColor.accent, lineWidth: 1)
            PathMarkGeometry.handleLines(anchors: anchors, zoom: zoom)
                .stroke(SuiteColor.accent, lineWidth: 1)
            knobs(PathMarkGeometry.handleKnobs(anchors: anchors, zoom: zoom))
            ForEach(Array(anchors.enumerated()), id: \.offset) { _, anchor in
                knobs(PathMarkGeometry.anchorPath(anchor, zoom: zoom))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// White fill, accent edge, like the selection handles.
    private func knobs(_ path: Path) -> some View {
        ZStack {
            path.fill(SuiteColor.overlayPaper)
            path.stroke(SuiteColor.accent, lineWidth: 1)
        }
    }
}

/// The ruler guides, each across the whole visible viewport.
public struct GuideMarks: View {
    private let guides: [CanvasGuide]
    private let zoom: Double
    private let viewport: CGRect

    /// `guides` in document pixels; `viewport` is the visible area in overlay
    /// points (its origin is negative where the view shows past the artboard).
    public init(guides: [CanvasGuide], zoom: Double, viewport: CGRect) {
        (self.guides, self.zoom, self.viewport) = (guides, zoom, viewport)
    }

    public var body: some View {
        Path { path in
            for guide in guides {
                let line = PathMarkGeometry.guideLine(guide, zoom: zoom, viewport: viewport)
                path.move(to: line.start)
                path.addLine(to: line.end)
            }
        }
        .stroke(SuiteColor.accent, lineWidth: 1)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
