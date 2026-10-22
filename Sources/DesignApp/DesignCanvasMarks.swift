// DesignCanvasMarks.swift: what DesignCanvas paints over the page. DesignArtwork is
// the page's nodes in paint order (frames, rectangles, ellipses, shapes, and text through
// DesignTextArtwork), at the canvas zoom, in one SwiftUI Canvas, each drawn as
// stored (style-rows ST-5): corner radius, a stroke centered on the edge, and its
// opacity times every enclosing layer's, so a frame fades its contents. The shape
// and stroke geometry are small functions (artworkPath, artworkStroke) the tests
// read; paintArtwork draws a list of them, for DesignArtwork and DesignPastEdge. DesignMarqueeMark
// is the rectangle a marquee drag covers, from the Model's `marquee`, drawn as a
// shape in the overlay. Frame names (DesignFrameLabels) and the selection
// (DesignSelectionMarks) have their own files. None takes clicks: the canvas
// gesture does, and the model decides what a press hits (hitTest, handle(at:)).
//
// Invariants:
// - Frames are absolute page points; multiplying by the zoom is the only mapping.
// - Paint order is DesignPage.painted: a node, then its children, siblings back to
//   front; a hidden node takes its whole subtree with it, label and handles too.
// - Text nodes scale with the zoom, like the artwork they sit in; marks keep one
//   line width on screen at any zoom. A document stroke is artwork: its width scales.
// - A node draws at `DesignPainted.opacity`, its own opacity times its ancestors'.
// - A turned or mirrored node draws its upright shape through artworkPlacement, the kernel's matrix.
// - A shape node draws its spec's path in its frame (DesignNode.path(in:), the kernel's ShapeRules), so a
//   resize redraws it; its box only when the spec can't be drawn. A line or arrow is stroked, never filled.
// - Colors come from SuiteColor, except the document's own fills (DesignColor).
import DesignModel
import SuiteKernel
import SuiteUI
import SwiftUI

/// A node as the canvas paints it, with the fill it sits on.
struct DesignPainted: Identifiable, Sendable {
    let node: DesignNode
    /// The fill of the nearest enclosing frame; nil on the bare page.
    let backdrop: DesignColor?
    /// How opaque the node draws: its own opacity times every enclosing layer's, in 0...1.
    let opacity: Double

    var id: String { node.id }
}

extension DesignPage {
    /// The nodes the canvas paints, back to front: depth first, skipping every hidden subtree.
    var painted: [DesignPainted] {
        func walk(_ nodes: [DesignNode], backdrop: DesignColor?, opacity: Double) -> [DesignPainted] {
            nodes.filter { !$0.isHidden }.flatMap { node in
                let faded = opacity * drawnOpacity(node.opacity)
                return [DesignPainted(node: node, backdrop: backdrop, opacity: faded)]
                    + walk(node.children, backdrop: node.kind == .frame ? node.fill : backdrop, opacity: faded)
            }
        }
        return walk(nodes, backdrop: nil, opacity: 1)
    }
}

/// `zoom` as a usable scale: a value that is not a positive finite number counts as 1.
func usable(_ zoom: Double) -> Double {
    zoom.isFinite && zoom > 0 ? zoom : 1
}

/// `opacity` kept within 0...1; a value that is not finite draws fully opaque.
func drawnOpacity(_ opacity: Double) -> Double {
    opacity.isFinite ? min(max(opacity, 0), 1) : 1
}

/// The outline `node` fills at `scale` (view points), or nil for a kind with no shape of its own:
/// rectangles, frames and instances as rounded rectangles at `drawnCornerRadius`, ellipses as
/// ellipses, a shape as its spec's path in its frame (its box when the spec draws none). All keep their curves.
func artworkPath(for node: DesignNode, scale: Double) -> Path? {
    let scale = usable(scale)
    let box = node.frame.cgRect.applying(CGAffineTransform(scaleX: scale, y: scale))
    switch node.kind {
    case .frame, .rectangle, .instance, .shape:
        if node.kind == .shape, let path = node.path(in: node.frame) { return artworkPath(path, scale: scale) }
        return RoundedRectangle(cornerRadius: node.drawnCornerRadius * scale).path(in: box)
    case .ellipse:
        return Path(ellipseIn: box)
    case .text, .group:
        return nil
    }
}

/// `path` (document space) at `scale`, in view points, curves kept.
func artworkPath(_ path: VectorPath, scale: Double) -> Path {
    let at = { (p: Point) in CGPoint(x: p.x * scale, y: p.y * scale) }
    var drawn = Path()
    for element in path.elements {
        switch element {
        case .move(let to): drawn.move(to: at(to))
        case .line(let to): drawn.addLine(to: at(to))
        case .quad(let control, let to): drawn.addQuadCurve(to: at(to), control: at(control))
        case .cubic(let c1, let c2, let to): drawn.addCurve(to: at(to), control1: at(c1), control2: at(c2))
        case .close: drawn.closeSubpath()
        }
    }
    return drawn
}

/// Whether `node` is a line or an arrow, which the canvas strokes and never fills.
func artworkIsOpen(_ node: DesignNode) -> Bool {
    node.kind == .shape && (node.shape?.kind == .line || node.shape?.kind == .arrow)
}

/// How a line or arrow `node` strokes at `scale`: its own stroke, else a default-width line in its fill colour,
/// so an open shape always shows.
func artworkLine(for node: DesignNode, scale: Double) -> (color: Color, style: StrokeStyle) {
    if let stroke = node.stroke, let style = artworkStroke(for: node, scale: scale) { return (stroke.color.color, style) }
    return (node.fill.color, StrokeStyle(lineWidth: DesignStroke.default.width * usable(scale)))
}

/// What `node` fills with at `scale` (view points): its gradient, its unit box drawn over its frame
/// through the kernel's one mapping (SuiteUI's `Fill.shading`), or its solid colour (gradient-fill DG-3).
func artworkShading(for node: DesignNode, scale: Double) -> GraphicsContext.Shading {
    guard let gradient = node.gradient else { return .color(node.fill.color) }
    let scale = usable(scale)
    let box = node.frame.cgRect.applying(CGAffineTransform(scaleX: scale, y: scale))
    return gradient.shading(in: box, box: Rect(minX: 0, minY: 0, maxX: 1, maxY: 1))
}

/// Where a box drawn upright at `scale` lands once `t` turns and mirrors it, in view points: the kernel's
/// `TransformRules.matrix` (unit box to document) after the upright box's own map to the unit box, so no
/// turn is worked out here (transform DT-3). The identity for an upright, unmirrored or empty box.
func artworkPlacement(_ t: TransformBox, scale: Double) -> CGAffineTransform {
    let (w, h) = (t.box.width, t.box.height)
    guard t.degrees != 0 || t.flipX || t.flipY, w > 0, h > 0, w.isFinite, h.isFinite else { return .identity }
    let m = TransformRules.matrix(of: t), s = usable(scale)
    let (a, b, c, d) = (m.a / w, m.b / w, m.c / h, m.d / h)
    let tx = m.tx - a * t.box.minX - c * t.box.minY, ty = m.ty - b * t.box.minX - d * t.box.minY
    return CGAffineTransform(a: a, b: b, c: c, d: d, tx: tx * s, ty: ty * s)
}

/// How `node`'s stroke draws at `scale`: its width times the scale, centered on the path's edge
/// (half inside, half outside), or nil when it has none, or a width that draws nothing.
func artworkStroke(for node: DesignNode, scale: Double) -> StrokeStyle? {
    guard let stroke = node.stroke, stroke.width.isFinite, stroke.width > 0 else { return nil }
    return StrokeStyle(lineWidth: stroke.width * usable(scale))
}

/// The page's nodes at `zoom`. The text node being edited is left out: the inline field sits there.
struct DesignArtwork: View {
    let painted: [DesignPainted]
    let zoom: Double
    var editingTextID: String?

    var body: some View {
        let painted = painted
        let scale = usable(zoom)
        let editing = editingTextID
        Canvas { context, _ in paintArtwork(painted, in: context, scale: scale, editing: editing) }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// Paints `painted` into `context` at `scale`, each node at its opacity times `fade`; the text
/// node `editing` is left out. DesignArtwork and DesignPastEdge both draw through it. Main actor,
/// as DesignTextArtwork is; both callers draw from a Canvas in their `body`.
@MainActor
func paintArtwork(
    _ painted: [DesignPainted], in context: GraphicsContext, scale: Double, editing: String?, fade: Double = 1
) {
    for item in painted {
        let node = item.node
        var faded = context
        faded.opacity = item.opacity * fade
        faded.concatenate(artworkPlacement(node.transformBox, scale: scale))
        if let shape = artworkPath(for: node, scale: scale), artworkIsOpen(node) {
            let line = artworkLine(for: node, scale: scale)
            faded.stroke(shape, with: .color(line.color), style: line.style)
        } else if let shape = artworkPath(for: node, scale: scale) {
            faded.fill(shape, with: artworkShading(for: node, scale: scale))
            if let stroke = node.stroke, let style = artworkStroke(for: node, scale: scale) {
                faded.stroke(shape, with: .color(stroke.color.color), style: style)
            } else if node.kind == .frame {
                faded.stroke(shape, with: .color(SuiteColor.overlayInk.opacity(0.15)), lineWidth: 1)
            }
        } else if node.kind == .text, node.id != editing {
            // Text scales with the artwork; the context carries the zoom for it.
            faded.scaleBy(x: scale, y: scale)
            DesignTextArtwork.draw(node, in: faded)
        }
    }
}

/// The marquee under way: `rect` (page points) at `zoom`, a 1 pt accent edge over a 10 % accent
/// fill. A shape, not a Canvas, so a marquee dragged past the page's edge still shows.
struct DesignMarqueeMark: View {
    let rect: DesignRect
    let zoom: Double

    var body: some View {
        let scale = usable(zoom)
        let box = Path(rect.cgRect.applying(CGAffineTransform(scaleX: scale, y: scale)))
        ZStack(alignment: .topLeading) {
            box.fill(SuiteColor.accent.opacity(0.1))
            box.stroke(SuiteColor.accent, lineWidth: 1)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
