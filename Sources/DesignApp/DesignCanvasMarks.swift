// DesignCanvasMarks.swift: what DesignCanvas paints over the page. DesignArtwork is
// the page's nodes in paint order (frames, rectangles, ellipses, and text through
// DesignTextArtwork), at the canvas zoom, in one SwiftUI Canvas, each drawn as
// stored (style-rows ST-5): corner radius, a stroke centered on the edge, and its
// opacity times every enclosing layer's, so a frame fades its contents. The shape
// and stroke geometry are small functions (artworkPath, artworkStroke) the tests
// read. DesignMarqueeMark
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
// - Colors come from SuiteColor, except the document's own fills (DesignColor).
import DesignModel
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
/// ellipses. Both keep their curves.
func artworkPath(for node: DesignNode, scale: Double) -> Path? {
    let scale = usable(scale)
    let box = node.frame.cgRect.applying(CGAffineTransform(scaleX: scale, y: scale))
    switch node.kind {
    case .frame, .rectangle, .instance:
        return RoundedRectangle(cornerRadius: node.drawnCornerRadius * scale).path(in: box)
    case .ellipse:
        return Path(ellipseIn: box)
    case .text, .group:
        return nil
    }
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
        Canvas { context, _ in
            for item in painted {
                let node = item.node
                var faded = context
                faded.opacity = item.opacity
                if let shape = artworkPath(for: node, scale: scale) {
                    faded.fill(shape, with: .color(node.fill.color))
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
        .allowsHitTesting(false)
        .accessibilityHidden(true)
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
