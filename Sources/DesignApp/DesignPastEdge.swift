// DesignPastEdge.swift: the layers that reach past the page's edge, drawn dimmed outside it
// (canvas-basics CB-9). CanvasViewport clips its content to the page but not its overlay, so a
// page made smaller than its layers would hide their cut parts; this overlay draws each layer
// where DesignPage.isPastEdge holds at 40% of its own opacity, through paintArtwork, in one Canvas
// laid out over DesignPage.contentBounds and clipped even-odd to that area minus the page, so
// nothing draws twice inside the page. Draws nothing when every layer fits. Takes no clicks.
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
            let area = bounds.cgRect.applying(zoomed)
            let pageRect = CGRect(x: 0, y: 0, width: page.frameWidth, height: page.frameHeight).applying(zoomed)
            let inside = pageRect.intersection(area)
            // One clear layer the artboard's size; the guides move the Canvas onto `area`.
            Color.clear.overlay(alignment: .topLeading) {
                Canvas { context, _ in
                    context.translateBy(x: -area.minX, y: -area.minY)
                    var outside = Path(area)
                    if !inside.isNull { outside.addRect(inside) }
                    context.clip(to: outside, style: FillStyle(eoFill: true))
                    paintArtwork(past, in: context, scale: scale, editing: editing, fade: Self.fade)
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
