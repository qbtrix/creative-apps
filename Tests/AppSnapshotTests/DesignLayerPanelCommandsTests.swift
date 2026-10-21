// DesignLayerPanelCommandsTests.swift: the Layers panel's bar and context
// menu are the Edit and Object menus' own catalog items. Every command is in
// Design's catalog; each bar action has its menu item's enablement and
// reason; fx waits on layer styles; the menu, opened on a row outside the
// selection, reads that row as selected and selects it before it runs, and a
// page row gets no menu. macOS only.
import DesignModel
import SuiteUI
import SwiftUI
import Testing

@testable import DesignApp

@MainActor
@Suite struct DesignLayerPanelCommandsTests {
    let a = "node-2", pair = "node-6"

    /// `cards` with A selected.
    private func cards() throws -> DesignWorkspace {
        var model = DesignFixtures.cards
        try model.setExpanded("node-1", true)
        model.selectItem(a)
        return model
    }

    @Test func barMatchesTheMenus() throws {
        let menu = DesignMenu(model: try cards(), perform: { _ in })
        for id in DesignLayersPanel.barCommands.map(\.id) + DesignLayersPanel.rowCommands.map(\.id) {
            #expect(DesignWorkspace.catalog.spec(id) != nil, "\(id) is not a Design catalog command")
        }
        let bar = DesignLayersPanel.bar(menu)
        #expect(bar.map(\.identifier) == ["design.layers.bar.group", "design.layers.bar.duplicate",
                                          "design.layers.bar.delete", "design.layers.bar.fx"])
        for (command, action) in zip(DesignLayersPanel.barCommands, bar) {
            let item = menu.item(command.id, systemImage: command.symbol) {}
            #expect(action.title == item.title && action.isEnabled == item.isEnabled, "\(command.id)")
            #expect(action.help == (item.isEnabled ? item.title : item.help), "\(command.id)")
        }
        #expect(bar.last?.isEnabled == false && bar.last?.help == LayerActionBar.effectsPending)
    }

    @Test func rowMenuActsOnTheRowsItOpenedOn() throws {
        var sent: [DesignIntent] = []
        let menu = DesignMenu(model: try cards(), perform: { sent.append($0) })
        let ungroup = { (items: [ToolbarAction]) in items.first { $0.title == "Ungroup" } }
        let selected = DesignLayersPanel.rowMenu(menu, rows: [a])
        let group = DesignLayersPanel.rowMenu(menu, rows: [pair])
        #expect(selected.count == DesignLayersPanel.rowCommands.count)
        #expect(ungroup(selected)?.isEnabled == false && ungroup(group)?.isEnabled == true)
        #expect(DesignLayersPanel.rowMenu(menu, rows: ["page-1"]).isEmpty)
        #expect(DesignLayersPanel.rowMenu(menu, rows: []).isEmpty)
        group.first?.perform()
        guard sent.count == 2, case .select(let id) = sent[0], case .command(.duplicate) = sent[1] else {
            Issue.record("expected select then duplicate, got \(sent)")
            return
        }
        #expect(id == pair)
        sent = []
        selected.first?.perform()
        guard sent.count == 1, case .command(.duplicate) = sent[0] else {
            Issue.record("a selected row re-selected or sent \(sent)")
            return
        }
    }
}
