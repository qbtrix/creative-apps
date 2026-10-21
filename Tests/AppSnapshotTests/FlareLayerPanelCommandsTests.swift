// FlareLayerPanelCommandsTests.swift: the LAYERS bar and row menus are built
// from Flare's catalog specs. Every command is in the catalog; each bar action
// has its spec's enablement and reason on the workspace; fx waits on layer
// styles; a row's menu reads that row as selected and selects it before it
// runs. macOS only.
import FlareModel
import SuiteKernel
import SuiteUI
import SwiftUI
import Testing

@testable import FlareApp

@MainActor
@Suite struct FlareLayerPanelCommandsTests {
    /// A new animation with three layers, the top one selected.
    private func threeLayers() -> FlareWorkspace {
        var model = FlareWorkspace(services: .fake())
        model.newDocument()
        for _ in 0..<3 { model.addLayer() }
        return model
    }

    @Test func barFollowsTheCatalog() throws {
        let model = threeLayers()
        for id in FlareLayersList.barCommands.map(\.id) + FlareLayersList.rowCommands.map(\.id) {
            #expect(FlareWorkspace.catalog.spec(id) != nil, "\(id) is not a Flare catalog command")
            #expect(FlareLayersList.intent(id, layer: "x") != nil, "\(id) sends nothing")
        }
        let bar = FlareLayersList.bar(model) { _ in }
        #expect(bar.map(\.identifier) == ["flare.layers.bar.new", "flare.layers.bar.duplicate", "flare.layers.bar.delete",
                                          "flare.layers.bar.fx", "flare.layers.bar.lock", "flare.layers.bar.visibility"])
        for (command, action) in zip(FlareLayersList.barCommands, bar.filter { $0.identifier != "flare.layers.bar.fx" }) {
            let item = MenuCommand(try #require(FlareWorkspace.catalog.spec(command.id)), on: model,
                                   title: model.menuTitle(command.id)) {}
            #expect(action.title == item.title && action.isEnabled == item.isEnabled, "\(command.id)")
            #expect(action.help == (item.isEnabled ? item.title : item.help), "\(command.id)")
        }
        let none = FlareLayersList.bar(FlareWorkspace(services: .fake())) { _ in }
        #expect(none.allSatisfy { !$0.isEnabled })
    }

    @Test func rowMenuActsOnItsRow() throws {
        let model = threeLayers()
        let bottom = try #require(model.layers.last?.id)
        var sent: [FlareIntent] = []
        let top = FlareLayersList.rowMenu(model, row: try #require(model.selectedLayerID)) { sent.append($0) }
        let low = FlareLayersList.rowMenu(model, row: bottom) { sent.append($0) }
        #expect(low.map(\.title).contains("Bring Forward"))
        let forward = { (menu: [ToolbarAction]) in menu.first { $0.title == "Bring Forward" }?.isEnabled }
        #expect(forward(top) == false && forward(low) == true)
        low.first { $0.title == "Delete Layer" }?.perform()
        #expect(sent == [.layers(.select(id: bottom)), .layers(.remove(id: bottom))])
    }
}
