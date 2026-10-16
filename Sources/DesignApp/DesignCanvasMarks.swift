// DesignCanvasMarks.swift: what DesignCanvas paints, in two flat layers over the
// page. DesignArtwork is the page's nodes in paint order (frames, rectangles,
// ellipses and text, at the canvas zoom) plus each frame's name, in one SwiftUI
// Canvas; DesignSelectionMarks is the selected node's outline and its resize
// handles, in screen points, drawn as shapes so they show past the page's edge.
// Neither takes clicks: the canvas gesture does, and the model decides what a
// press hits (hitTest, handle(at:)), with the same handles the marks draw.
//
// Invariants:
// - Frames are absolute page points; multiplying by the zoom is the only mapping.
// - Paint order is DesignPage.painted: a node, then its children, siblings back to
//   front; a hidden node takes its whole subtree with it, label and handles too.
// - Frame names and handles stay one size on screen at any zoom. Text nodes scale
//   with the zoom, like the artwork they sit in. A selection under three handles
//   across shows only its corners, pushed outside it (DesignRect.handles).
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
private func usable(_ zoom: Double) -> Double {
    zoom.isFinite && zoom > 0 ? zoom : 1
}

private extension DesignColor {
    /// Whether dark ink reads on this color (Rec. 601 luma above the midpoint).
    var isLight: Bool { 0.299 * Double(red) + 0.587 * Double(green) + 0.114 * Double(blue) > 127.5 }
}

/// The color of a frame's name over `backdrop`: ink on a light fill, paper on a dark one, and
/// the secondary label color on the bare page, where the checkerboard sits behind it.
private func labelColor(over backdrop: DesignColor?) -> Color {
    guard let backdrop else { return SuiteColor.secondaryText }
    return backdrop.isLight ? SuiteColor.overlayInk.opacity(0.55) : SuiteColor.overlayPaper.opacity(0.7)
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
                    var clipped = scaled
                    clipped.clip(to: Path(node.frame.cgRect))
                    let text = Text(node.text).font(SuiteFont.body).foregroundStyle(node.fill.color)
                    clipped.draw(text, in: node.frame.cgRect)
                case .text, .group:
                    break
                }
            }
            for item in painted where item.node.kind == .frame {
                drawName(of: item, in: context, scaledBy: fit)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Draws a frame's name above its top-left corner, or just inside it when the artboard has no room
/// for the name above the frame (DesignFrameLabel decides). The Canvas is laid out on the artboard,
/// so the artboard's top is 0 here, and the name's own measured height sets the room it needs.
private func drawName(of item: DesignPainted, in context: GraphicsContext, scaledBy fit: CGAffineTransform) {
    let box = item.node.frame.cgRect.applying(fit)
    let text = Text(item.node.name).font(SuiteFont.caption)
    let height = context.resolve(text).measure(in: CGSize(width: CGFloat.infinity, height: .infinity)).height
    let label = DesignFrameLabel.place(
        frameTop: Double(box.minY), artboardTop: 0, labelHeight: Double(height),
        gap: Double(SuiteSpacing.xxs), inset: Double(SuiteSpacing.xs))
    let color = labelColor(over: label.isInside ? item.node.fill : item.backdrop)
    let name = context.resolve(text.foregroundStyle(color))
    switch label {
    case .inside(let top):
        context.draw(name, at: CGPoint(x: box.minX + SuiteSpacing.xs, y: top), anchor: .topLeading)
    case .above(let bottom):
        context.draw(name, at: CGPoint(x: box.minX, y: bottom), anchor: .bottomLeading)
    }
}

/// The selection: an accent outline around `rect`, and with `handles` its resize handles, white
/// squares with an accent edge where DesignRect.handles puts them (a small selection shows only its
/// corners, outside the box). Shapes, not a Canvas, so marks past the page's edge still draw:
/// CanvasViewport doesn't clip its overlay.
struct DesignSelectionMarks: View {
    let rect: DesignRect
    let zoom: Double
    var handles = true

    var body: some View {
        let scale = usable(zoom)
        let side = SuiteSpacing.s
        let box = rect.cgRect.applying(CGAffineTransform(scaleX: scale, y: scale))
        let centers = handles ? Array(rect.handles(size: Double(side) / scale).values) : []
        let squares = Path { path in
            for at in centers {
                path.addRect(CGRect(x: at.x * scale - side / 2, y: at.y * scale - side / 2, width: side, height: side))
            }
        }
        ZStack(alignment: .topLeading) {
            Path(box).stroke(SuiteColor.accent, lineWidth: 1)
            squares.fill(SuiteColor.overlayPaper)
            squares.stroke(SuiteColor.accent, lineWidth: 1)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
