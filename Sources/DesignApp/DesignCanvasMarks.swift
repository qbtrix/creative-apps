// DesignCanvasMarks.swift: what DesignCanvas paints over the page. DesignArtwork is
// the page's nodes in paint order (frames, rectangles, ellipses, and text through
// DesignTextArtwork), at the canvas zoom, in one SwiftUI Canvas. DesignMarqueeMark
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
//   line width on screen at any zoom.
// - Colors come from SuiteColor, except the document's own fills (DesignColor).
import DesignModel
import SuiteUI
import SwiftUI

/// A node as the canvas paints it, with the fill it sits on.
struct DesignPainted: Identifiable, Sendable {
    let node: DesignNode
    /// The fill of the nearest enclosing frame; nil on the bare page.
    let backdrop: DesignColor?

    var id: String { node.id }
}

extension DesignPage {
    /// The nodes the canvas paints, back to front: depth first, skipping every hidden subtree.
    var painted: [DesignPainted] {
        func walk(_ nodes: [DesignNode], backdrop: DesignColor?) -> [DesignPainted] {
            nodes.filter { !$0.isHidden }.flatMap { node in
                [DesignPainted(node: node, backdrop: backdrop)]
                    + walk(node.children, backdrop: node.kind == .frame ? node.fill : backdrop)
            }
        }
        return walk(nodes, backdrop: nil)
    }
}

/// `zoom` as a usable scale: a value that is not a positive finite number counts as 1.
func usable(_ zoom: Double) -> Double {
    zoom.isFinite && zoom > 0 ? zoom : 1
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
            let fit = CGAffineTransform(scaleX: scale, y: scale)
            // Text scales with the artwork; the context carries the zoom for it.
            var scaled = context
            scaled.scaleBy(x: scale, y: scale)
            for item in painted {
                let node = item.node
                let box = node.frame.cgRect.applying(fit)
                switch node.kind {
                case .frame:
                    context.fill(Path(box), with: .color(node.fill.color))
                    context.stroke(Path(box), with: .color(SuiteColor.overlayInk.opacity(0.15)), lineWidth: 1)
                case .rectangle, .instance:
                    context.fill(Path(box), with: .color(node.fill.color))
                case .ellipse:
                    context.fill(Path(ellipseIn: box), with: .color(node.fill.color))
                case .text where node.id != editing:
                    DesignTextArtwork.draw(node, in: scaled)
                case .text, .group:
                    break
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
