// DesignFrameLabels.swift: each visible top-level frame's name, drawn in the canvas
// overlay over the artwork, just above the frame's top-left corner, where
// DesignFrameLabel puts it (#266). Nested frames show no name. Text views, not a
// Canvas, so a name above the page's top edge still draws: CanvasViewport doesn't
// clip its overlay (the overlay's top is the page's top, 0 here). Names stay one
// size on screen at any zoom. A slot: the text styles (style-rows SR-t) change it
// here without touching DesignCanvasMarks.swift. Takes no clicks.
import DesignModel
import SuiteUI
import SwiftUI

struct DesignFrameLabels: View {
    let painted: [DesignPainted]
    let zoom: Double

    var body: some View {
        let scale = usable(zoom)
        ZStack(alignment: .topLeading) {
            ForEach(DesignFrameLabel.labelled(on: topLevel)) { node in
                let box = node.frame.cgRect.applying(CGAffineTransform(scaleX: scale, y: scale))
                let bottom = DesignFrameLabel.bottom(frameTop: Double(box.minY), gap: Double(SuiteSpacing.xxs))
                // One clear layer the artboard's size per name, so the name's guides move only the name.
                Color.clear.overlay(alignment: .topLeading) {
                    Text(node.name)
                        .font(SuiteFont.caption)
                        .foregroundStyle(SuiteColor.secondaryText)
                        .lineLimit(1)
                        .fixedSize()
                        // The name's bottom edge lands `bottom` down the artboard, its leading edge on the frame's.
                        .alignmentGuide(.top) { $0[.bottom] - CGFloat(bottom) }
                        .alignmentGuide(.leading) { _ in -box.minX }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// The painted nodes as a page of their top-level nodes: a painted node no other painted node
    /// holds as a child. `painted` already skips every hidden subtree.
    private var topLevel: DesignPage {
        let nested = Set(painted.flatMap { $0.node.children.map(\.id) })
        let nodes = painted.map(\.node).filter { !nested.contains($0.id) }
        return DesignPage(id: "", name: "", frameWidth: 0, frameHeight: 0, nodes: nodes)
    }
}
