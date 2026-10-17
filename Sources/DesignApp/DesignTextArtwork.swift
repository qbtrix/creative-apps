// DesignTextArtwork.swift: how the canvas paints a text node, called by
// DesignArtwork in paint order inside its Canvas: the node's text in its style's
// family, size, weight and alignment (DesignTextFont, the font the inline editor
// uses too) and its fill color, wrapped and clipped to its frame, from the frame's
// top. The context comes in already scaled by the canvas zoom, so the style's size
// is in page points and text grows and shrinks with the artwork. Alignment places
// the measured text across the box: one line sits exactly as aligned; text that
// wraps fills the box's width. style-rows SR-t.
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
        let text = Text(node.text).font(DesignTextFont.font(style)).foregroundStyle(node.fill.color)
        let resolved = clipped.resolve(text)
        clipped.draw(resolved, in: textRect(measured: resolved.measure(in: box.size), in: box, style: style))
    }

    /// The rect `measured` text is laid out in inside `box`: at the box's top, across by the style's
    /// alignment. It is a point wider than the text so rounding never wraps the last word; the
    /// text sits at its leading edge, so the extra point never moves it.
    static func textRect(measured: CGSize, in box: CGRect, style: DesignTextStyle) -> CGRect {
        let width = min(measured.width, box.width)
        let x = box.minX + (box.width - width) * DesignTextFont.across(style)
        return CGRect(x: x, y: box.minY, width: width + 1, height: box.height)
    }
}
