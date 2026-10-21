// PhotoLayerRowSnapshots.swift: the whole layer list with its command bar
// (PhotoLayerList, on LayerTreeList since AL-p3, which draws the selection).
// The bar and each row's context menu are the Layer menu's own catalog items:
// every id is in Photo's catalog, each action matches `PhotoMenu.item` on the
// same state, and a row's menu reads that row as selected and selects it
// before it runs. Writes photo-layer-list-light.png and photo-layer-list-dark.png.
import PhotoModel
import SuiteUI
import SwiftUI
import Testing

@testable import PhotoApp

@MainActor
@Suite struct PhotoLayerRowSnapshots {
    /// Background hidden, then Layer 1 at Multiply 50%, selected.
    private func twoLayers() throws -> PhotoWorkspace {
        var model = PhotoWorkspace()
        try model.newCanvas(width: 64, height: 64)
        let background = try #require(model.selectedLayerID)
        model.toggleVisibility(background)
        model.addLayer()
        let top = try #require(model.selectedLayerID)
        model.setBlendMode(top, .multiply)
        model.setOpacity(top, percent: 50)
        return model
    }

    /// The list of both layers with its command bar under it.
    @Test func layerList() throws {
        let model = try twoLayers()
        let identifiers = PhotoLayerList.bar(PhotoMenu(model: model, perform: { _ in })).map(\.identifier)
        #expect(identifiers == ["photo.layer.new", "photo.layer.duplicate", "photo.layer.delete", "photo.layer.fx",
                                "photo.layer.lock", "photo.layer.visibility", "photo.layer.rename"])
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                PhotoLayerList(model: model, perform: { _ in })
                    .frame(width: SuiteSize.editorPanelWidth, height: 200)
                    .background(SuiteColor.panel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(SuiteSpacing.xxl),
                name: "photo-layer-list-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }

    /// The bar is the Layer menu's items on the selection: same title, enablement and reason.
    @Test func barMatchesTheLayerMenu() throws {
        let menu = PhotoMenu(model: try twoLayers(), perform: { _ in })
        let commands = PhotoLayerList.barCommands(selected: menu.selectedLayer) + PhotoLayerList.rowCommands(row: "x")
        for id in Set(commands.map(\.id)) {
            #expect(PhotoWorkspace.catalog.spec(id) != nil, "\(id) is not a Photo catalog command")
        }
        for (command, action) in zip(PhotoLayerList.barCommands(selected: menu.selectedLayer),
                                     PhotoLayerList.bar(menu).filter { $0.identifier != "photo.layer.fx" }) {
            let item = menu.item(command.id) {}
            #expect(action.title == item.title && action.isEnabled == item.isEnabled, "\(command.id)")
            #expect(action.help == (item.isEnabled ? item.title : item.help), "\(command.id)")
        }
        let fx = try #require(PhotoLayerList.bar(menu).first { $0.identifier == "photo.layer.fx" })
        #expect(!fx.isEnabled && fx.help == LayerActionBar.effectsPending)
    }

    /// A row's menu reads that row as selected (Background, at the bottom, can't merge down), and a pick selects it first.
    @Test func rowMenuActsOnItsRow() throws {
        let model = try twoLayers()
        let background = try #require(model.layers.first { !$0.isVisible }?.id)
        var sent: [PhotoIntent] = []
        let menu = PhotoMenu(model: model, perform: { sent.append($0) })
        let top = PhotoLayerList.rowMenu(menu, row: try #require(model.selectedLayerID))
        let bottom = PhotoLayerList.rowMenu(menu, row: background)
        #expect(bottom.map(\.title) == ["Rename Layer…", "Duplicate Layer", "Delete Layer", "Merge Down", "Flatten Image",
                                         "Bring Forward", "Send Backward", "Lock Layer", "Show Layer"])
        let merge = { (menu: [ToolbarAction]) in menu.first { $0.identifier == "photo.layer.merge-down" } }
        #expect(merge(top)?.isEnabled == true && merge(bottom)?.isEnabled == false)
        #expect(bottom.first { $0.identifier == "photo.layer.send-backward" }?.isEnabled == false)
        bottom.first { $0.identifier == "photo.layer.duplicate" }?.perform()
        #expect(sent.count == 2)
        if case .selectLayer(let id) = sent.first { #expect(id == background) } else { Issue.record("no select first: \(sent)") }
    }
}
