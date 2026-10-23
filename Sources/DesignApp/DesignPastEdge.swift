// DesignPastEdge.swift: the layers that reach past the page's edge, drawn dimmed outside it
// (canvas-basics CB-9). CanvasViewport clips its content to the page but not its overlay, so a
// page made smaller than its layers would hide their cut parts; this overlay draws each layer
// where DesignPage.isPastEdge holds at 40% of its own opacity, through paintArtwork, in one Canvas
// laid out over DesignPage.contentBounds (and the page's 1 pt rim) and clipped even-odd to that
// area minus the page, so nothing draws twice inside the page. Light content faded on the Light
// surround all but vanishes (about 1.04:1), so each faded shape also gets a 1 pt outline and the
// page's edge a 1 pt line just outside it, both in the canvas's own mark ink, SuiteColor.rulerTick
// (the label color at 40%), which reads in Light and Dark. Draws nothing when every layer fits.
// Takes no clicks.
import DesignModel
import SuiteUI
import SwiftUI

struct DesignPastEdge: View {
    let page: DesignPage
    let painted: [DesignPainted]
    let zoom: Double
    var editingTextID: String?

    /// How opaque a layer draws past the page, times its own opacity.
    nonisolated static let fade = 0.4

    /// The painted layers that reach past `page`'s edge, back to front.
    nonisolated static func layers(_ painted: [DesignPainted], on page: DesignPage) -> [DesignPainted] {
        painted.filter { page.isPastEdge($0.node) }
    }

    var body: some View {
        let past = Self.layers(painted, on: page)
        let scale = usable(zoom)
        let editing = editingTextID
        let zoomed = CGAffineTransform(scaleX: scale, y: scale)
        if !past.isEmpty, let bounds = page.contentBounds {
            let pageRect = CGRect(x: 0, y: 0, width: page.frameWidth, height: page.frameHeight).applying(zoomed)
            let area = bounds.cgRect.applying(zoomed).union(pageRect.insetBy(dx: -1, dy: -1))
            // One clear layer the artboard's size; the guides move the Canvas onto `area`.
            Color.clear.overlay(alignment: .topLeading) {
                Canvas { context, _ in
                    context.translateBy(x: -area.minX, y: -area.minY)
                    let unclipped = context
                    var outside = Path(area)
                    outside.addRect(pageRect)
                    context.clip(to: outside, style: FillStyle(eoFill: true))
                    paintArtwork(past, in: context, scale: scale, editing: editing, fade: Self.fade)
                    // Each shape's outline at full strength, times the layer's own opacity.
                    for item in past {
                        guard let shape = artworkPath(for: item.node, scale: scale) else { continue }
                        var ink = context
                        ink.opacity = item.opacity
                        ink.stroke(shape, with: .color(SuiteColor.rulerTick), lineWidth: 1)
                    }
                    // The cut line, last: 1 pt just outside the page, so it covers none of the page's artwork.
                    let rim = Path(pageRect.insetBy(dx: -0.5, dy: -0.5))
                    unclipped.stroke(rim, with: .color(SuiteColor.rulerTick), lineWidth: 1)
                }
                .frame(width: area.width, height: area.height)
                .alignmentGuide(.leading) { _ in -area.minX }
                .alignmentGuide(.top) { _ in -area.minY }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}
