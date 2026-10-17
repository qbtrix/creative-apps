// DesignTextArtwork.swift: how the canvas paints a text node, called by
// DesignArtwork in paint order inside its Canvas: the node's text in body type
// and its fill color, wrapped and clipped to its frame. The context comes in
// already scaled by the canvas zoom, so text grows and shrinks with the artwork.
// A slot: the text styles (style-rows SR-t) change it here without touching
// DesignCanvasMarks.swift.
import DesignModel
import SuiteUI
import SwiftUI

enum DesignTextArtwork {
    /// Draws `node`'s text in its frame (page points) on `context`, which is scaled to the zoom.
    static func draw(_ node: DesignNode, in context: GraphicsContext) {
        var clipped = context
        clipped.clip(to: Path(node.frame.cgRect))
        let text = Text(node.text).font(SuiteFont.body).foregroundStyle(node.fill.color)
        clipped.draw(text, in: node.frame.cgRect)
    }
}
