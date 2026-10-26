// PhotoLayerStyleSnapshots.swift (layer-styles PY-2 `panel`, PY-3 the rest): Layer > Layer Style… and what it shows,
// each in Light and Dark, on the `layered` fixture (Paint, Curves 1, Background, top first; Paint selected).
// - `panel`: the style panel open on Drop Shadow, off, drawn on top the way a sheet sits over the window, with its
//   Done button. Writes photo-layer-style-panel-light.png and -dark.png.
// - `stroke`: Paint styled with a drop shadow and a white 4 px outside stroke, the panel open on Stroke, both
//   switches on. Writes photo-layer-style-stroke-light.png and -dark.png.
// - `canvas`: the same style on the canvas with the panel closed. Disabled until PY-6 draws styles in the
//   composite, so the PNG never shows an unstyled layer under the name of a styled one. Writes
//   photo-layer-style-canvas-light.png and -dark.png.
// - `disabled`: Curves 1, an adjustment layer, selected: the Layer menu's style items drawn as a column (the menu bar
//   doesn't render here), Layer Style… disabled, and its help, "Layer styles go on pixel and text layers.", under
//   it. Writes photo-layer-style-disabled-light.png and -dark.png.
// The style is set on the layer directly (@testable): `setStyle` throws until PY-5. macOS only.
import CoreRaster
import PhotoModel
import SuiteImaging
import SuiteUI
import SwiftUI
import Testing

@testable import PhotoApp
@testable import PhotoModel

@MainActor
@Suite struct PhotoLayerStyleSnapshots {
    @Test func panel() throws {
        var model = try PhotoWorkspace.fixture(.layered)
        model.showStylePanel(.dropShadow)
        #expect(model.stylePanel == .dropShadow)
        #expect(model.layers.first { $0.id == model.selectedLayerID }?.name == "Paint")
        let tiles = try photoTiles(model)
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(Self.sheet(over: model, tiles: tiles), name: "photo-layer-style-panel-\(Self.suffix(scheme))", scheme: scheme)
        }
    }

    @Test func stroke() throws {
        var model = try Self.styled()
        model.showStylePanel(.stroke)
        #expect(model.styleSelection?.effect(.stroke)?.isEnabled == true)
        #expect(model.styleSelection?.effect(.dropShadow)?.isEnabled == true)
        #expect(model.styleHelp == nil)
        let tiles = try photoTiles(model)
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(Self.sheet(over: model, tiles: tiles), name: "photo-layer-style-stroke-\(Self.suffix(scheme))", scheme: scheme)
        }
    }

    @Test(.disabled("waits on PY-6: the composite draws no layer style yet")) func canvas() throws {
        let model = try Self.styled()
        #expect(model.stylePanel == nil)
        let tiles = try photoTiles(model)
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                PhotoEditor(model: model, tiles: tiles, renderMilliseconds: 8, zoom: 1),
                name: "photo-layer-style-canvas-\(Self.suffix(scheme))", scheme: scheme)
        }
    }

    @Test func disabled() throws {
        var model = try PhotoWorkspace.fixture(.layered)
        let curves = try #require(model.layers.first { $0.name == "Curves 1" })
        model.selectLayer(curves.id)
        let help = "Layer styles go on pixel and text layers."
        #expect(model.styleSelection == nil && model.styleHelp == help)
        let state = PhotoMenuState(workspace: model, hasWindow: true)
        #expect(state.availability("style.panel").why == help)
        let menu = PhotoMenu(model: model, perform: { _ in })
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(DisabledMenu(menu: menu, help: help), name: "photo-layer-style-disabled-\(Self.suffix(scheme))", scheme: scheme)
        }
    }

    // MARK: - Helpers

    /// The window's editor with the style sheet drawn over its top, as a sheet sits.
    static func sheet(over model: PhotoWorkspace, tiles: CanvasTiles?) -> some View {
        ZStack(alignment: .top) {
            PhotoEditor(model: model, tiles: tiles, renderMilliseconds: 8, zoom: 1)
            PhotoStyleSheet(model: model, perform: { _ in })
                .background(SuiteColor.panel, in: .rect(cornerRadius: SuiteRadius.large))
                .padding(.top, SuiteSpacing.xxl)
        }
    }

    /// The `layered` fixture with Paint styled: a drop shadow 20 px at 120°, size 8, and a white 4 px outside stroke.
    static func styled() throws -> PhotoWorkspace {
        var model = try PhotoWorkspace.fixture(.layered)
        let at = try #require(model.layers.firstIndex { $0.id == model.selectedLayerID })
        #expect(model.layers[at].name == "Paint")
        let shadow = StyleShadow(color: .black, angle: 120, distance: 20, spread: 0, size: 8)
        let stroke = StyleStroke(fill: .solid(.white), size: 4, position: .outside)
        model.layers[at].style = LayerStyle(effects: [
            StyleEffect(kind: .dropShadow, isEnabled: true, blendMode: .multiply, opacity: 0.75, parameters: .shadow(shadow)),
            StyleEffect(kind: .stroke, isEnabled: true, blendMode: .normal, opacity: 1, parameters: .stroke(stroke)),
        ], fillOpacity: 1)
        return model
    }

    static func suffix(_ scheme: ColorScheme) -> String { scheme == .dark ? "dark" : "light" }
}

/// The Layer menu's items in a column with an adjustment layer selected, and Layer Style…'s help under them.
private struct DisabledMenu: View {
    let menu: PhotoMenu
    let help: String

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            PhotoLayerMenu(menu: menu)
            Divider()
            Text("Layer Style…: \(help)").font(SuiteFont.caption).foregroundStyle(.secondary)
        }
        .labelStyle(.titleAndIcon)
        .padding(SuiteSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
