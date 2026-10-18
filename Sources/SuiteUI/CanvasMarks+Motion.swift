// CanvasMarks+Motion.swift (CM-6): an animation's stage marks, drawn in a
// CanvasViewport's overlay. `MotionPathMarks` draws the path a layer travels
// as a dotted `secondaryText` line through its position at each frame, with a
// dot (a tick) per frame; positions are document pixels at the canvas zoom,
// while the dot size and the dotting stay fixed on screen. `GhostLayer` draws
// an onion-skin ghost: the app's artwork at a falling opacity, which the app
// tints `onionBefore` or `onionAfter`. Opacity is clamped to 0...1 (NaN draws
// nothing); a zoom that isn't a positive finite number counts as 1, and a
// point that isn't finite is dropped. Marks are hidden from accessibility and
// never take a click; the canvas gesture does. The geometry is static and
// plain so tests read it without rendering.
import SwiftUI

/// The dotted path through a layer's frame positions, a dot per frame.
public struct MotionPathMarks: View {
    private let points: [CGPoint]
    private let zoom: Double

    /// The marks never take a click: the canvas gesture under them does.
    public nonisolated static let takesHits = false
    /// The marks are hidden from accessibility; an app adds its own element.
    public nonisolated static let hiddenFromAccessibility = true

    /// `points` in document pixels, one per frame in frame order; `zoom` in points per pixel.
    public init(points: [CGPoint], zoom: Double) {
        self.points = points
        self.zoom = zoom
    }

    /// `zoom`, or 1 when it isn't a positive finite number.
    public nonisolated static func scale(_ zoom: Double) -> Double {
        zoom.isFinite && zoom > 0 ? zoom : 1
    }

    /// The frame points in view points at `zoom`, in order; points that aren't finite are dropped.
    public nonisolated static func line(points: [CGPoint], zoom: Double) -> [CGPoint] {
        let factor = Self.scale(zoom)
        return points.filter { $0.x.isFinite && $0.y.isFinite }.map { CGPoint(x: $0.x * factor, y: $0.y * factor) }
    }

    /// One `anchor`-sized dot per frame point, centred on it, the same size at every zoom.
    public nonisolated static func dots(points: [CGPoint], zoom: Double) -> [CGRect] {
        let side = SuiteSize.anchor
        return line(points: points, zoom: zoom).map {
            CGRect(x: $0.x - side / 2, y: $0.y - side / 2, width: side, height: side)
        }
    }

    public var body: some View {
        ZStack {
            MotionLineShape(points: Self.line(points: points, zoom: zoom))
                .stroke(
                    SuiteColor.secondaryText,
                    style: StrokeStyle(lineWidth: SuiteSpacing.xxs, lineCap: .round, dash: [0, SuiteSpacing.xs]))
            MotionDotsShape(dots: Self.dots(points: points, zoom: zoom))
                .fill(SuiteColor.secondaryText)
        }
        .allowsHitTesting(Self.takesHits)
        .accessibilityHidden(Self.hiddenFromAccessibility)
    }
}

/// An onion-skin ghost: `content` at `opacity`, hidden and hitless.
public struct GhostLayer<Content: View>: View {
    private let content: Content
    /// The opacity the ghost draws at, clamped to 0...1.
    public let opacity: Double

    /// `content` is the artwork as the app tints it; `opacity` falls with the frame's distance.
    public init(content: Content, opacity: Double) {
        self.content = content
        self.opacity = Self.clamped(opacity)
    }

    /// `opacity` kept in 0...1; NaN is 0, so a bad value draws nothing.
    public nonisolated static func clamped(_ opacity: Double) -> Double {
        opacity.isNaN ? 0 : min(max(opacity, 0), 1)
    }

    public var body: some View {
        content
            .opacity(opacity)
            .allowsHitTesting(MotionPathMarks.takesHits)
            .accessibilityHidden(MotionPathMarks.hiddenFromAccessibility)
    }
}

/// The polyline through `points`, in view points.
private struct MotionLineShape: Shape {
    let points: [CGPoint]

    func path(in _: CGRect) -> Path {
        var path = Path()
        if points.count > 1 { path.addLines(points) }
        return path
    }
}

/// A circle in each of `dots`, in view points.
private struct MotionDotsShape: Shape {
    let dots: [CGRect]

    func path(in _: CGRect) -> Path {
        var path = Path()
        for dot in dots { path.addEllipse(in: dot) }
        return path
    }
}
