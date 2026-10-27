// HaloStyledViewer.swift (layer-styles HY-7): the viewer's layers with styles on the GPU. `styledRuns` stack
// bottom first: plain runs are one linear Canvas each, a styled solid or shape is SuiteUI's StyleLayerView keyed by
// its content without the style, so a Glow Size scrub uploads nothing. Runs composite at normal blend; opacity rides
// on the view. Without `haloStyleRoute` (tests, snapshots) the viewer keeps one Canvas. Reads the list, never acts.
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
    @ViewBuilder let drawn: ([HaloDrawItem]) -> Drawn

    var body: some View {
        let list = list
        ZStack {
            ForEach(Array(list.styledRuns.enumerated()), id: \.offset) { _, run in
                switch run {
                case .drawn(let items): drawn(items)
                case .styled(let item):
                    StyleLayerView(route: route, id: item.layerID, content: list.styleContent(item),
                                   width: list.width, height: list.height, style: item.style,
                                   pixels: { list.stylePixels(item) })
                        .opacity(item.opacity)
                }
            }
        }
    }
}
