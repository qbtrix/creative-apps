// CanvasMarks+Path.swift (CM-5): a vector path's marks and the viewport's
// guide lines, drawn in a CanvasViewport's overlay. `PathMarks` strokes the
// path's segments and marks each anchor: a corner anchor is a square, a smooth
// anchor a circle with its handle lines and handle dots, so the two read apart
// at a glance. `ViewportGuideMarks` draws ruler guides as hairlines across the
// whole visible stretch (not the kernel's snap guides between two boxes,
// which editor-kernel's `SnapGuideMarks` draws). Positions are document
// pixels at the canvas zoom; mark sizes are fixed on screen (`SuiteSize.anchor`
// at any zoom). Black and white, or the accent for guides, so they read on any
// pixels. Marks are hidden from accessibility and never take a click; the
// canvas gesture does. The geometry is static and plain so tests read it.
import SwiftUI

/// One anchor of a vector path, in document pixels.
public struct PathAnchor: Equatable, Sendable {
    /// How the path turns at the anchor.
    public enum Kind: Equatable, Sendable {
        /// A sharp turn: the anchor draws as a square, with no handles.
        case corner
        /// A smooth turn: the anchor draws as a circle, with its handles.
        case smooth
    }

    public let point: CGPoint
    public let kind: Kind
    /// The control point of the segment arriving here, if it curves.
    public let handleIn: CGPoint?
    /// The control point of the segment leaving here, if it curves.
    public let handleOut: CGPoint?

    public init(point: CGPoint, kind: Kind, handleIn: CGPoint? = nil, handleOut: CGPoint? = nil) {
        self.point = point
        self.kind = kind
        self.handleIn = handleIn
        self.handleOut = handleOut
    }
}

/// A segment between two anchors, by their indices in `PathMarks`' anchors.
/// It curves through the start's `handleOut` and the end's `handleIn`, and is
/// straight where neither is set.
public struct PathSegment: Equatable, Sendable {
    public let from: Int
    public let to: Int

    public init(from: Int, to: Int) {
        self.from = from
        self.to = to
    }
}

/// A path's segments and anchors over the canvas.
public struct PathMarks: View {
    private let anchors: [PathAnchor]
    private let segments: [PathSegment]
    private let zoom: Double

    /// `anchors` in document pixels; `segments` index into them; `zoom` in points per pixel.
    public init(anchors: [PathAnchor], segments: [PathSegment], zoom: Double) {
        self.anchors = anchors
        self.segments = segments
        self.zoom = zoom
    }

    public var body: some View {
        let outline = Self.outline(anchors: anchors, segments: segments, zoom: zoom)
        let handles = Self.handleLines(anchors: anchors, zoom: zoom)
        let marks = Self.anchorMarks(anchors: anchors, zoom: zoom)
        ZStack {
            outline.stroke(SuiteColor.overlayInk, lineWidth: 2)
            outline.stroke(SuiteColor.overlayPaper, lineWidth: 1)
            handles.stroke(SuiteColor.overlayInk, lineWidth: 1)
            marks.fill(SuiteColor.overlayPaper)
            marks.stroke(SuiteColor.overlayInk, lineWidth: 1)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// A non-finite or non-positive zoom draws at 1, like `CanvasLayout`.
    public static func scale(_ zoom: Double) -> Double { zoom.isFinite && zoom > 0 ? zoom : 1 }

    private static func view(_ point: CGPoint, _ zoom: Double) -> CGPoint {
        let s = scale(zoom)
        return CGPoint(x: point.x * s, y: point.y * s)
    }

    /// The anchor's mark in view points: a square for a corner, a circle for a
    /// smooth anchor, `SuiteSize.anchor` across at every zoom, centered on it.
    public static func anchorShape(_ anchor: PathAnchor, zoom: Double) -> Path {
        let side = SuiteSize.anchor
        let center = view(anchor.point, zoom)
        let box = CGRect(x: center.x - side / 2, y: center.y - side / 2, width: side, height: side)
        switch anchor.kind {
        case .corner: return Path(box)
        case .smooth: return Path(ellipseIn: box)
        }
    }

    /// Every anchor's mark, plus a half-size dot on each smooth anchor's handles.
    public static func anchorMarks(anchors: [PathAnchor], zoom: Double) -> Path {
        var path = Path()
        let dot = SuiteSize.anchor / 2
        for anchor in anchors {
            path.addPath(anchorShape(anchor, zoom: zoom))
            guard anchor.kind == .smooth else { continue }
            for handle in [anchor.handleIn, anchor.handleOut].compactMap({ $0 }) {
                let c = view(handle, zoom)
                path.addEllipse(in: CGRect(x: c.x - dot / 2, y: c.y - dot / 2, width: dot, height: dot))
            }
        }
        return path
    }

    /// The lines from each smooth anchor to its handles; corners draw none.
    public static func handleLines(anchors: [PathAnchor], zoom: Double) -> Path {
        var path = Path()
        for anchor in anchors where anchor.kind == .smooth {
            for handle in [anchor.handleIn, anchor.handleOut].compactMap({ $0 }) {
                path.move(to: view(anchor.point, zoom))
                path.addLine(to: view(handle, zoom))
            }
        }
        return path
    }

    /// The segments in view points; one whose index is out of range draws nothing.
    public static func outline(anchors: [PathAnchor], segments: [PathSegment], zoom: Double) -> Path {
        var path = Path()
        for segment in segments {
            guard anchors.indices.contains(segment.from), anchors.indices.contains(segment.to) else { continue }
            let start = anchors[segment.from], end = anchors[segment.to]
            path.move(to: view(start.point, zoom))
            if start.handleOut == nil, end.handleIn == nil {
                path.addLine(to: view(end.point, zoom))
            } else {
                path.addCurve(to: view(end.point, zoom),
                              control1: view(start.handleOut ?? start.point, zoom),
                              control2: view(end.handleIn ?? end.point, zoom))
            }
        }
        return path
    }
}

/// A ruler guide: a vertical line at `x` or a horizontal line at `y`, in document pixels.
public enum ViewportGuide: Equatable, Sendable {
    case vertical(x: Double)
    case horizontal(y: Double)
}

/// One guide's line in view points.
public struct GuideLine: Equatable, Sendable {
    public let start: CGPoint
    public let end: CGPoint

    public init(start: CGPoint, end: CGPoint) {
        self.start = start
        self.end = end
    }
}

/// Ruler guides drawn across the visible part of the canvas.
public struct ViewportGuideMarks: View {
    private let guides: [ViewportGuide]
    private let zoom: Double
    private let viewport: CGRect

    /// `guides` in document pixels; `viewport` is the visible stretch in the
    /// overlay's points (the artboard's, at `zoom`), which every line spans.
    public init(guides: [ViewportGuide], zoom: Double, viewport: CGRect) {
        self.guides = guides
        self.zoom = zoom
        self.viewport = viewport
    }

    public var body: some View {
        Path { path in
            for line in Self.lines(guides: guides, zoom: zoom, viewport: viewport) {
                path.move(to: line.start)
                path.addLine(to: line.end)
            }
        }
        .stroke(SuiteColor.accent, lineWidth: 1)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Each guide's line from one edge of `viewport` to the other; a guide at a
    /// non-finite position, or an empty or non-finite viewport, draws nothing.
    public static func lines(guides: [ViewportGuide], zoom: Double, viewport: CGRect) -> [GuideLine] {
        let v = viewport.standardized
        guard [v.minX, v.minY, v.width, v.height].allSatisfy(\.isFinite), v.width > 0, v.height > 0 else { return [] }
        let s = PathMarks.scale(zoom)
        return guides.compactMap { guide in
            switch guide {
            case .vertical(let x):
                guard x.isFinite else { return nil }
                return GuideLine(start: CGPoint(x: x * s, y: v.minY), end: CGPoint(x: x * s, y: v.maxY))
            case .horizontal(let y):
                guard y.isFinite else { return nil }
                return GuideLine(start: CGPoint(x: v.minX, y: y * s), end: CGPoint(x: v.maxX, y: y * s))
            }
        }
    }
}
