// PhotoMultiLayerSnapshots.swift (multi-layer-select PM-7): the four states
// of picking several layers, in Light and Dark, on the `layered` fixture plus
// one new layer (four rows, as the journey has them):
// - photo-layers-several-picked: rows 1 to 3 picked (the Shift-click range),
// - photo-layers-all-picked: every row picked by Select > All Layers,
// - photo-select-menu-all-layers: the Select menu with no image beside one
//   with an image, All Layers (⌥⌘A) disabled then enabled. The menu bar
//   doesn't render here, so the items are drawn in columns, as
//   PhotoEditMenuSnapshots does,
// - photo-layers-delete-refused: every row picked, Delete refused, the status
//   line saying "At least one layer must stay."
// The window states are shot through PhotoEditor, as PhotoEditorSnapshots
// does. Until PM-4 fills in the Shift range, the range is set on the kernel
// selection directly (`@testable`), so the picture is the finished state.
// macOS only.
import CoreRaster
import PhotoModel
import SuiteKernel
import SuiteUI
import SwiftUI
import Testing

@testable import PhotoApp
@testable import PhotoModel

@MainActor
@Suite struct PhotoMultiLayerSnapshots {
    @Test func severalPicked() throws {
        var model = try Self.fourLayers()
        let order = model.layers.map(\.id)
        let first = try #require(order.first)
        model.layerSelection.replace([first])
        model.layerSelection.pick(order[2], .extend, order: order)
        #expect(model.selectedLayerIDs == Array(order.prefix(3)))
        try shoot("several-picked", model)
    }

    @Test func allPicked() throws {
        var model = try Self.fourLayers()
        model.selectAllLayers()
        #expect(model.selectedLayerIDs == model.layers.map(\.id))
        try shoot("all-picked", model)
    }

    @Test func deleteRefused() throws {
        var model = try Self.fourLayers()
        model.selectAllLayers()
        model.removeSelectedLayers()
        #expect(model.layers.count == 4)
        #expect(model.statusMessage == "At least one layer must stay.")
        try shoot("delete-refused", model)
    }

    @Test func selectMenuAllLayers() throws {
        var sent: [PhotoIntent] = []
        let menus = try [PhotoWorkspace(), Self.fourLayers()].map { model in
            PhotoMenu(model: model, perform: { sent.append($0) })
        }
        let items = menus.map(\.allLayersItem)
        #expect(items.map(\.isEnabled) == [false, true])
        #expect(items.first?.help == "All Layers: Open an image first.")
        items.last?.perform()
        let sentAll = sent.contains { if case .selectAllLayers = $0 { true } else { false } }
        #expect(sent.count == 1 && sentAll)
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                SelectMenuStates(menus: menus),
                name: "photo-select-menu-all-layers-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }

    /// The `layered` fixture (Paint, Curves 1, Background) with a new layer on top: four rows.
    static func fourLayers() throws -> PhotoWorkspace {
        var model = try PhotoWorkspace.fixture(.layered)
        model.addLayer()
        return model
    }

    private func shoot(_ state: String, _ model: PhotoWorkspace) throws {
        let tiles = try photoTiles(model)
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                PhotoEditor(model: model, tiles: tiles, renderMilliseconds: 8, zoom: 1),
                name: "photo-layers-\(state)-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}

private struct SelectMenuStates: View {
    let menus: [PhotoMenu]
    var body: some View {
        HStack(alignment: .top, spacing: SuiteSpacing.xxl) {
            ForEach(menus.indices, id: \.self) { index in
                VStack(alignment: .leading, spacing: SuiteSpacing.s) {
                    menus[index].selectAllItem
                    Divider()
                    menus[index].allLayersItem
                }
                .labelStyle(.titleAndIcon)
            }
        }
        .padding(SuiteSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
