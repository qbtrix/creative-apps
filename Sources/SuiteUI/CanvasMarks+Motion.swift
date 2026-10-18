// CanvasMarks+Motion.swift: the animation marks drawn over a canvas inside a
// CanvasViewport's overlay. MotionPathMarks draws a layer's motion path: one
// dot per frame point, joined by a hairline, the points in document pixels at
// the canvas zoom and the dots the same size on screen at every zoom.
// GhostLayer draws onion-skin content (another frame's drawing) as one flat
// layer at its opacity, so overlapping shapes inside it don't darken each
// other. Black and white, like the other marks, so they read on any pixels.
// Neither takes a click nor shows to accessibility; the canvas gesture does.
// The points and the opacity come from the app's Model (Flare's
// `FlareWorkspace.motionPath` and `Ghost.opacity`); these views only draw.
import SwiftUI

/// A motion path: one dot per frame point and the line through them.
public struct MotionPathMarks: View {
    private let points: [CGPoint]
    private let zoom: Double

    /// `points` in document pixels, one per frame; `zoom` in points per pixel.
    public init(points: [CGPoint], zoom: Double) {
        self.points = points
        self.zoom = zoom
    }

    /// Each finite point at `zoom` in view points; a zoom that isn't a number is 100%.
    public static func centers(_ points: [CGPoint], zoom: Double) -> [CGPoint] {
        let scale = ZoomMath.clamped(zoom)
        return points.filter { $0.x.isFinite && $0.y.isFinite }.map { CGPoint(x: $0.x * scale, y: $0.y * scale) }
    }

    /// One dot per finite point: a `curvePreviewDot` circle on its center, the
    /// same size at every zoom.
    public static func dots(_ points: [CGPoint], zoom: Double) -> [CGRect] {
        let side = SuiteSize.curvePreviewDot
        return centers(points, zoom: zoom).map {
            CGRect(x: $0.x - side / 2, y: $0.y - side / 2, width: side, height: side)
        }
    }

    public var body: some View {
        let line = Path { $0.addLines(Self.centers(points, zoom: zoom)) }
        let dots = Path { path in
            for dot in Self.dots(points, zoom: zoom) { path.addEllipse(in: dot) }
        }
        ZStack {
            line.stroke(SuiteColor.overlayPaper, lineWidth: SuiteSize.pointMarkPaper)
            line.stroke(SuiteColor.overlayInk, lineWidth: 1)
            dots.fill(SuiteColor.overlayInk)
            dots.stroke(SuiteColor.overlayPaper, lineWidth: SuiteSize.pointMarkInk)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Onion-skin content drawn as one layer at `opacity`.
public struct GhostLayer<Content: View>: View {
    private let content: Content
    /// The opacity it draws at: the given one kept to 0...1, 0 when it isn't a number.
    public let drawnOpacity: Double

    public init(@ViewBuilder content: () -> Content, opacity: Double) {
        self.content = content()
        drawnOpacity = Self.drawn(opacity)
    }

    /// `opacity` kept to 0...1; a value that isn't a number hides the ghost.
    public static func drawn(_ opacity: Double) -> Double {
        opacity.isNaN ? 0 : min(max(opacity, 0), 1)
    }

    public var body: some View {
        content
            .compositingGroup()
            .opacity(drawnOpacity)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
