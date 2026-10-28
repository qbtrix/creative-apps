// HaloLayerPanelCommandsTests.swift: the LAYERS list's bar and row menus are
// the Layer menu's own catalog items. Every command is in Halo's catalog;
// each bar action has its menu item's enablement and reason; fx waits on
// layer styles; a row's menu reads that row as selected and selects it before
// it runs. macOS only.
import HaloModel
import SuiteUI
import SwiftUI
import Testing

@testable import HaloApp

@MainActor
@Suite struct HaloLayerPanelCommandsTests {
    /// Three layers with the top one selected.
    private func threeLayers() throws -> HaloProject {
        var project = HaloProject(services: .fake, document: try #require(HaloFixtures.project("three-layers")))
        project.selectLayer("comp-1-layer-4")
        return project
    }

    @Test func barMatchesTheLayerMenu() throws {
        let target = HaloMenuTarget(model: try threeLayers()) { _ in }
        let commands = HaloLayerList.barCommands.map(\.command) + HaloLayerList.rowCommands.map(\.command)
        for command in commands {
            #expect(HaloProject.catalog.spec(command.commandID) != nil, "\(command) is not a Halo catalog command")
        }
        let bar = HaloLayerList.bar(target)
        #expect(bar.map(\.identifier) == ["halo.layer.bar.new", "halo.layer.bar.duplicate", "halo.layer.bar.delete",
                                          "halo.layer.bar.fx"])
        for (entry, action) in zip(HaloLayerList.barCommands, bar) {
            let item = target.item(entry.command)
            #expect(action.isEnabled == item.isEnabled, "\(entry.command)")
            #expect(action.help == (item.isEnabled ? action.title : item.help), "\(entry.command)")
        }
        #expect(bar.first?.title == "New Layer")
        #expect(bar.last?.isEnabled == false && bar.last?.help == LayerActionBar.effectsPending)
        let closed = HaloLayerList.bar(HaloMenuTarget(model: nil, perform: nil))
        #expect(closed.dropLast().allSatisfy { !$0.isEnabled })
    }

    @Test func rowMenuActsOnItsRow() throws {
        let project = try threeLayers()
        let bottom = try #require(project.selectedComposition?.layers.last?.id)
        var sent: [HaloCommand] = []
        let target = HaloMenuTarget(model: project) { sent.append($0) }
        let top = HaloLayerList.rowMenu(target, row: "comp-1-layer-4")
        let low = HaloLayerList.rowMenu(target, row: bottom)
        #expect(low.count == HaloLayerList.rowCommands.count)
        // The top row can't come forward; the bottom one can, and can't go back.
        #expect(top[3].isEnabled == false && low[3].isEnabled == true && low[4].isEnabled == false)
        low[1].perform()
        #expect(sent == [.selectLayer(bottom), .duplicateLayer])
    }
}
