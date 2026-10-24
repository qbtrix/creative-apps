// DesignTextArtwork.swift: how the canvas paints a text node, called by
// DesignArtwork in paint order inside its Canvas: the node's text in its style's
// family, size, weight and alignment (DesignTextFont, the font the inline editor
// uses too) and its fill (its colour, or its gradient over its frame as the
// resolved text's shading, gradient-fill DG-3), clipped to its frame, from the frame's top. A
// fixed-width box wraps its text at the frame's width; an auto-width box, which the
// window fits to its text on commit (canvas-basics CB-6), keeps one line per
// paragraph. The context comes in already scaled by the canvas zoom, so the style's
// size is in page points and text grows and shrinks with the artwork. Alignment
// places the measured text across the box: one line sits exactly as aligned; text
// that wraps fills the box's width. style-rows SR-t. A style using italic, line height,
// tracking or justify (text-style TS-8) draws word by word where the kernel's layout put
// them (DesignTextFont.setting, the same setting the box is measured by), in its italic
// face or, when the family has none, slanted about each word's baseline.
import DesignModel
import SuiteUI
import SwiftUI

@MainActor
enum DesignTextArtwork {
    /// Draws `node`'s text in its frame (page points) on `context`, which is scaled to the zoom.
    static func draw(_ node: DesignNode, in context: GraphicsContext) {
        var clipped = context
        let box = node.frame.cgRect
        clipped.clip(to: Path(box))
        let style = node.textStyle
        if style.drawsThroughLayout {
            drawLaidOut(node, in: clipped)
            return
        }
        let text = Text(node.text).font(DesignTextFont.font(style))
        var resolved = clipped.resolve(text)
        let wraps = style.fixedWidth == true
        let measured = resolved.measure(in: CGSize(width: wraps ? box.width : .infinity, height: box.height))
        let rect = textRect(measured: measured, in: box, wraps: wraps, style: style)
        // The text is uncoloured, so the resolved text's shading fills it: the solid colour or the
        // gradient, in the context's page points (the zoom is already on the context).
        resolved.shading = artworkShading(for: node, scale: 1)
        clipped.draw(resolved, in: rect)
    }

    /// Draws each word of `node`'s laid-out text at its pen x and baseline, filled like the plain path.
    private static func drawLaidOut(_ node: DesignNode, in context: GraphicsContext) {
        let style = node.textStyle
        let box = node.frame.cgRect
        let fixed = style.fixedWidth == true
        guard let set = DesignTextFont.setting(node.text, style, wrapWidth: fixed ? Double(box.width) : nil) else { return }
        let (font, oblique) = DesignTextFont.face(style)
        let left = Double(box.minX) + (fixed ? 0 : (Double(box.width) - set.width) * DesignTextFont.across(style))
        let unbounded = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        for word in set.words {
            var resolved = context.resolve(
                Text(word.text).font(Font(font as CTFont)).tracking(CGFloat(style.trackingPoints)))
            resolved.shading = artworkShading(for: node, scale: 1)
            let rise = resolved.firstBaseline(in: unbounded)
            let pen = CGPoint(x: left + word.x, y: Double(box.minY) + word.baseline)
            guard oblique else {
                context.draw(resolved, at: CGPoint(x: pen.x, y: pen.y - rise), anchor: .topLeading)
                continue
            }
            var slanted = context
            slanted.translateBy(x: pen.x, y: pen.y)
            slanted.concatenate(DesignTextFont.obliqueShear)
            slanted.draw(resolved, at: CGPoint(x: 0, y: -rise), anchor: .topLeading)
        }
    }

    /// The rect `measured` text is laid out in inside `box`: at the box's top, across by the style's
    /// alignment, no wider than the box when it `wraps`. It is a point wider than the text so
    /// rounding never wraps the last word; the text sits at its leading edge, so the extra point
    /// never moves it.
    static func textRect(measured: CGSize, in box: CGRect, wraps: Bool, style: DesignTextStyle) -> CGRect {
        let width = wraps ? min(measured.width, box.width) : measured.width
        let x = box.minX + (box.width - width) * DesignTextFont.across(style)
        return CGRect(x: x, y: box.minY, width: width + 1, height: box.height)
    }
}
