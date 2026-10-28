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
// - A rectangle's or frame's picture draws by cover through SuiteUI's drawPlaced, clipped to its rounded box,
//   over its fill and under its stroke, in the same one Canvas (placed-images PD-u).
// - A turned or mirrored node draws its upright shape through artworkPlacement, the kernel's matrix.
// - A shape node draws its spec's path in its frame (DesignNode.path(in:), the kernel's ShapeRules), so a
//   resize redraws it; its box only when the spec can't be drawn. A line or arrow is stroked, and an arrow's
//   closed head is filled in the line colour too; nothing else of an open shape fills.
// - A stroke draws `DesignPainted.stroke` (the node's, read through `vectorStroke`) along the Model's
//   `strokedPath`, the kernel's StrokeRules.paintedPath, so its dashes are path geometry, with its join and cap
//   (stroke-style DK-3). The same one Canvas draws it: no route of its own.
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
    /// The stroke the node draws: its own (`vectorStroke`) unless one is given.
    let stroke: VectorStroke?

    init(node: DesignNode, backdrop: DesignColor?, opacity: Double, stroke: VectorStroke? = nil) {
        (self.node, self.backdrop, self.opacity) = (node, backdrop, opacity)
        self.stroke = stroke ?? node.vectorStroke
    }

    var id: String { node.id }
}

extension DesignPage {
    /// The nodes the canvas paints, back to front: depth first, skipping every hidden subtree.
    var painted: [DesignPainted] {
        var out: [DesignPainted] = []
        func walk(_ nodes: [DesignNode], backdrop: DesignColor?, opacity: Double) {
            for node in nodes where !node.isHidden {
                let faded = opacity * drawnOpacity(node.opacity)
                out.append(DesignPainted(node: node, backdrop: backdrop, opacity: faded))
                walk(node.children, backdrop: node.kind == .frame ? node.fill : backdrop, opacity: faded)
            }
        }
        walk(nodes, backdrop: nil, opacity: 1)
        return out
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
/// rectangles, frames and instances as rounded rectangles at `drawnCornerRadius` (circular corners, as the kernel
/// outline a dashed stroke traces and the SVG's `rx` draw them), ellipses as
/// ellipses, a shape as its spec's path in its frame (its box when the spec draws none). All keep their curves.
func artworkPath(for node: DesignNode, scale: Double) -> Path? {
    let scale = usable(scale)
    let box = node.frame.cgRect.applying(CGAffineTransform(scaleX: scale, y: scale))
    switch node.kind {
    case .frame, .rectangle, .instance, .shape:
        if node.kind == .shape, let path = node.path(in: node.frame) { return artworkPath(path, scale: scale) }
        return RoundedRectangle(cornerRadius: node.drawnCornerRadius * scale, style: .circular).path(in: box)
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

/// Whether `node` is a line or an arrow, which the canvas strokes in its line colour (an arrow's head filled too).
func artworkIsOpen(_ node: DesignNode) -> Bool {
    node.kind == .shape && (node.shape?.kind == .line || node.shape?.kind == .arrow)
}

/// How a line or arrow `node` strokes at `scale`: its own stroke, else a default-width line in its fill colour,
/// so an open shape always shows.
func artworkLine(for node: DesignNode, stroke: VectorStroke?, scale: Double) -> (color: Color, style: StrokeStyle) {
    if let stroke, let style = artworkStyle(stroke, scale: scale) { return (artworkInk(stroke), style) }
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
    node.vectorStroke.flatMap { artworkStyle($0, scale: scale) }
}

/// How `stroke` draws at `scale`: its width times the scale, with its join and cap, or nil for a width that draws
/// nothing. Its dash is not here: the path it strokes is already dashed (`DesignNode.strokedPath`).
func artworkStyle(_ stroke: VectorStroke, scale: Double) -> StrokeStyle? {
    guard stroke.width.isFinite, stroke.width > 0 else { return nil }
    let cap: CGLineCap = switch stroke.cap {
    case .butt: .butt
    case .round: .round
    case .square: .square
    }
    let join: CGLineJoin = switch stroke.join {
    case .miter: .miter
    case .round: .round
    case .bevel: .bevel
    }
    return StrokeStyle(lineWidth: stroke.width * usable(scale), lineCap: cap, lineJoin: join)
}

/// What `stroke` traces on `node` at `scale`: the Model's `strokedPath` (dashed, trimmed, already in view points),
/// else `shape`, the fill's own outline, for a stroke that paints it whole.
func artworkTrace(_ node: DesignNode, _ stroke: VectorStroke?, shape: Path, scale: Double) -> Path {
    stroke.flatMap { node.strokedPath($0, scale: usable(scale)) }.map { artworkPath($0, scale: 1) } ?? shape
}

/// The colour `stroke` paints in: its colour at its opacity, as the SVG writes it.
func artworkInk(_ stroke: VectorStroke) -> Color {
    stroke.designColor.color.opacity(stroke.designOpacity)
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

/// The page's artwork on the canvas, compared by its inputs (`.equatable()`), so a step that leaves
/// the page as it was (a marquee, a hover) repaints nothing. During a move drag (`lift`) it draws
/// the page as it was at the press in three parts: the nodes under the moved run, the run, and
/// the nodes over it. Each part is its own DesignArtwork with unchanged inputs, so a step only
/// moves the run's view by the drag's offset and paints no node (render contract rule 3).
struct DesignPageArtwork: View, Equatable {
    let page: DesignPage
    let zoom: Double
    var editingTextID: String?
    var lift: DesignMoveLift?

    var body: some View {
        if let lift {
            let scale = usable(zoom)
            ForEach([DesignLiftPart.Part.under, .run, .over], id: \.self) { part in
                DesignLiftPart(page: lift.page, firstID: lift.firstID, lastID: lift.lastID, part: part, zoom: zoom,
                               editingTextID: editingTextID)
                .equatable()
                .offset(x: part == .run ? lift.offset.x * scale : 0, y: part == .run ? lift.offset.y * scale : 0)
            }
        } else {
            DesignArtwork(painted: page.painted, zoom: zoom, editingTextID: editingTextID)
        }
    }
}

/// One part of a lifted page (DesignPageArtwork): the painted nodes before, in, or after the moved run.
struct DesignLiftPart: View, Equatable {
    enum Part { case under, run, over }
    let page: DesignPage
    let firstID, lastID: String
    let part: Part
    let zoom: Double
    var editingTextID: String?

    var body: some View {
        DesignArtwork(painted: Self.slice(page.painted, part, from: firstID, to: lastID),
                      zoom: zoom, editingTextID: editingTextID)
    }

    /// `part` of `painted`, the run being `first` through `last`; the run's own ids missing, all of it under.
    static func slice(_ painted: [DesignPainted], _ part: Part, from first: String, to last: String) -> [DesignPainted] {
        guard let i = painted.firstIndex(where: { $0.id == first }),
              let j = painted[i...].firstIndex(where: { $0.id == last })
        else { return part == .under ? painted : [] }
        switch part {
        case .under: return Array(painted[..<i])
        case .run: return Array(painted[i...j])
        case .over: return Array(painted[(j + 1)...])
        }
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
        let shape = artworkPath(for: node, scale: scale)
        if let shape, artworkIsOpen(node) {
            // The fill covers only an arrow's closed head (a shaft has no area), so the head reads solid.
            let line = artworkLine(for: node, stroke: item.stroke, scale: scale)
            faded.fill(shape, with: .color(line.color))
            faded.stroke(artworkTrace(node, item.stroke, shape: shape, scale: scale), with: .color(line.color), style: line.style)
        } else if let shape {
            faded.fill(shape, with: artworkShading(for: node, scale: scale))
            if let asset = node.placedAsset, let image = node.placedImage {
                faded.drawPlaced(asset, image, cornerRadius: node.drawnCornerRadius, scale: scale)
            }
            if let stroke = item.stroke, let style = artworkStyle(stroke, scale: scale) {
                let trace = artworkTrace(node, stroke, shape: shape, scale: scale)
                faded.stroke(trace, with: .color(artworkInk(stroke)), style: style)
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
