// PhotoLayerStyleSnapshots.swift (layer-styles PY-2): Layer > Layer Style… while its sheet is open: the `layered`
// fixture with its "Paint" layer selected, the style panel open on Drop Shadow and drawn on top, the way a sheet sits
// over the window, with its Done button. Light and Dark. Writes photo-layer-style-panel-light.png and
// photo-layer-style-panel-dark.png. macOS only.
import PhotoModel
import SuiteUI
import SwiftUI
import Testing

@testable import PhotoApp

@MainActor
@Suite struct PhotoLayerStyleSnapshots {
    @Test func panel() throws {
        var model = try PhotoWorkspace.fixture(.layered)
        model.showStylePanel(.dropShadow)
        #expect(model.stylePanel == .dropShadow)
        #expect(model.layers.first { $0.id == model.selectedLayerID }?.name == "Paint")
        let tiles = try photoTiles(model)
        for scheme in [ColorScheme.light, .dark] {
            let view = ZStack(alignment: .top) {
                PhotoEditor(model: model, tiles: tiles, renderMilliseconds: 8, zoom: 1)
                PhotoStyleSheet(model: model, perform: { _ in })
                    .background(SuiteColor.panel, in: .rect(cornerRadius: SuiteRadius.large))
                    .padding(.top, SuiteSpacing.xxl)
            }
            try snapshot(view, name: "photo-layer-style-panel-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}
