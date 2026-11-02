// DesignStrokeOutline.swift (stroke-style DK-3): the path a layer's stroke paints, in document space, for the canvas
// to draw. `strokeOutline` is the edge a stroke traces (a rectangle, frame or instance as its rounded box at
// `drawnCornerRadius`, an ellipse as its ellipse, a shape as its spec's path or its box when the spec draws none;
// text and groups have none), built by the kernel's `ShapeRules`. `strokedPath` runs it through
// `StrokeRules.paintedPath` at the canvas scale: a dashed one is one subpath per dash, a plain one draws its shape. Linux-safe.
import SuiteKernel

extension DesignNode {
    /// The edge this layer's stroke traces, in document space; nil for text and groups.
    public var strokeOutline: VectorPath? {
        let box: ShapeSpec
        switch kind {
        case .shape:
            if let drawn = path(in: frame) { return drawn }
            box = ShapeSpec(kind: .rectangle)
        case .frame, .rectangle, .instance:
            box = ShapeSpec(kind: .rectangle, cornerRadius: drawnCornerRadius)
        case .ellipse:
            box = ShapeSpec(kind: .ellipse)
        case .text, .group:
            return nil
        }
        return try? ShapeRules.path(box, in: frame.kernelRect)
    }

    /// The path `stroke` paints along `strokeOutline` at `scale` (view points per document point) when it dashes or
    /// trims it; nil when the layer has no outline, the stroke's width draws nothing, or the stroke paints the outline
    /// whole (the canvas then strokes the fill's own shape, so the two keep the same corners). The outline is scaled
    /// before it is cut, so `StrokeRules.tolerance` holds in view points and dashed curves stay smooth at any zoom.
    /// A zero-length dash under a round or square cap keeps a tiny length, so a dotted stroke paints its dots.
    public func strokedPath(_ stroke: VectorStroke, scale: Double = 1) -> VectorPath? {
        guard stroke.width.isFinite, stroke.width > 0, let outline = strokeOutline else { return nil }
        guard !stroke.dash.isEmpty || !(stroke.trim?.isWhole ?? true) else { return nil }
        let s = scale.isFinite && scale > 0 ? scale : 1
        var drawn = stroke
        drawn.dash = stroke.dash.enumerated().map { i, d in
            i % 2 == 0 && d == 0 && stroke.cap != .butt ? Self.dotLength : d * s
        }
        drawn.dashPhase = stroke.dashPhase * s
        return try? StrokeRules.paintedPath(outline.transformed(by: .scale(x: s, y: s)), drawn)
    }

    /// The length, in view points, a zero dash keeps so its cap draws a dot.
    static let dotLength = 0.001
}

extension VectorStroke {
    /// The stroke's colour as Design's, its opacity dropped (the kernel adapter's `DesignColor(kernel:)`).
    public var designColor: DesignColor { DesignColor(kernel: color) }
    /// The stroke colour's opacity, within 0...1 (1 when not finite), which the canvas paints it at, as the SVG does.
    public var designOpacity: Double { color.a.isFinite ? min(max(color.a, 0), 1) : 1 }
}
