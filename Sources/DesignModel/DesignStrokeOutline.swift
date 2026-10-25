// DesignStrokeOutline.swift (stroke-style DK-3): the path a layer's stroke paints, in document space, for the canvas
// to draw. `strokeOutline` is the edge a stroke traces (a rectangle, frame or instance as its rounded box at
// `drawnCornerRadius`, an ellipse as its ellipse, a shape as its spec's path or its box when the spec draws none;
// text and groups have none), built by the kernel's `ShapeRules`. `strokedPath` runs it through
// `StrokeRules.paintedPath`: a plain stroke keeps it whole, a dashed one is one subpath per dash. Linux-safe.
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

    /// The path `stroke` paints along `strokeOutline` (dashed, trimmed), in document space; nil when the layer has
    /// no outline or the stroke's width draws nothing.
    public func strokedPath(_ stroke: VectorStroke) -> VectorPath? {
        guard stroke.width.isFinite, stroke.width > 0, let outline = strokeOutline else { return nil }
        return try? StrokeRules.paintedPath(outline, stroke)
    }
}

extension VectorStroke {
    /// The stroke's colour as Design's, its opacity dropped (the kernel adapter's `DesignColor(kernel:)`).
    public var designColor: DesignColor { DesignColor(kernel: color) }
}
