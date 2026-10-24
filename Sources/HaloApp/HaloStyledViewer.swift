// HaloStyledViewer.swift: the viewer's layers with styles on the GPU
// (layer-styles HY-7). The draw list's `styledRuns` stack bottom first: a
// run of plain layers is one linear Canvas (HaloDrawnLayers.canvas), a styled
// solid or shape is SuiteUI's StyleLayerView keyed by the layer's content
// without its style, so a Glow Size scrub uploads nothing and runs only the
// style draw. Each run composites over the ones below at normal blend; the
// layer's opacity rides on its view. The app scene sets `haloStyleRoute` to the
// suite's shared route; a window without one (tests, snapshots) keeps the one
// Canvas. Reads the list, never acts.
import HaloModel
import SuiteUI
import SwiftUI

extension EnvironmentValues {
    /// The GPU route styled layers draw on; nil draws them in the viewer's Canvas.
    @Entry var haloStyleRoute: StyleLayerRoute?
}

struct HaloStyledViewer<Drawn: View>: View {
    let list: HaloDrawList
    let route: StyleLayerRoute
    /// A run of plain layers, drawn as the viewer's Canvas draws them.
    @ViewBuilder let drawn: ([HaloDrawItem]) -> Drawn

    var body: some View {
        let list = list
        ZStack {
            ForEach(Array(list.styledRuns.enumerated()), id: \.offset) { _, run in
                switch run {
                case .drawn(let items):
                    drawn(items)
                case .styled(let item):
                    StyleLayerView(
                        route: route, id: item.layerID, content: AnyHashable(list.styleContent(item)),
                        width: list.width, height: list.height, style: item.style,
                        pixels: { list.stylePixels(item) })
                        .opacity(item.opacity)
                }
            }
        }
    }
}
