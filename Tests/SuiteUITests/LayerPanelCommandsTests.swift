// LayerPanelCommandsTests.swift: the Layers panel's commands come from the
// same catalog specs as the menu bar. A panel button or context item made
// from a spec-built MenuCommand keeps its title, symbol, enablement, reason
// and action, over every fake catalog id on an empty document and the
// fixture, so the panel can't drift from the Layer menu. The fx button waits
// for shared layer styles, disabled with its reason. LayerTreeList gives each
// row the context menu its app builds for that row's id, and none without
// one. The bar draws. macOS only.
import SuiteKernel
@testable import SuiteUI
import SwiftUI
import Testing

@MainActor @Suite struct LayerPanelCommandsTests {
    private let catalog = FakeCanvasDocument.catalog

    @Test func panelActionMatchesItsMenuItem() throws {
        for doc in [FakeCanvasDocument(), .fixture] {
            for id in catalog.ids {
                var ran = 0
                let item = MenuCommand(try #require(catalog.spec(id)), on: doc, systemImage: "square") { ran += 1 }
                let action = ToolbarAction(item, identifier: "suite.layer.\(id)")
                #expect(action.title == item.title && action.systemImage == "square", "\(id)")
                #expect(action.isEnabled == item.isEnabled, "\(id)")
                #expect(action.help == (item.isEnabled ? item.title : item.help), "\(id)")
                #expect(action.identifier == "suite.layer.\(id)")
                action.perform()
                #expect(ran == 1, "\(id)")
            }
        }
        let off = ToolbarAction(MenuCommand(try #require(catalog.spec("rect.remove")), on: FakeCanvasDocument()) {})
        #expect(off.unavailableHelp == "Remove Rectangle: Select a rectangle first.")
    }

    @Test func effectsWaitForLayerStyles() {
        let fx = LayerActionBar.effects(identifier: "photo.layer.fx")
        #expect(fx.title == "Layer Effects" && fx.systemImage == "fx" && fx.identifier == "photo.layer.fx")
        #expect(!fx.isEnabled && fx.help == LayerActionBar.effectsPending)
    }

    @Test func rowsCarryTheirContextMenu() throws {
        let rows = KernelFixtures.tree200.rows(expanded: [])
        let first = try #require(rows.first)
        var asked: [String] = []
        let list = LayerTreeList(
            rows: rows, childCount: { _ in 0 },
            contextActions: { id in
                asked.append(id)
                return id == first.id ? [ToolbarAction("Duplicate Layer", systemImage: "plus.square.on.square"),
                                         ToolbarAction("Delete Layer", systemImage: "trash", unavailableHelp: "Locked.")] : []
            },
            onAction: { _ in })
        let menu = try #require(list.contextMenu(for: first.id))
        #expect(menu.map(\.title) == ["Duplicate Layer", "Delete Layer"])
        #expect(menu.last?.isDisabled == true && menu.last?.help == "Locked.")
        #expect(list.contextMenu(for: "nosuch") == nil)
        #expect(asked == [first.id, "nosuch"])
        #expect(LayerTreeList(rows: rows, childCount: { _ in 0 }, onAction: { _ in }).contextMenu(for: first.id) == nil)
    }

    @Test func barDraws() throws {
        let bar = LayerActionBar([
            ToolbarAction("New Layer", systemImage: "plus"),
            ToolbarAction("Delete Layer", systemImage: "trash", unavailableHelp: "The last layer can't be deleted."),
            LayerActionBar.effects(identifier: nil),
        ])
        #expect(bar.actions.map(\.title) == ["New Layer", "Delete Layer", "Layer Effects"])
        let renderer = ImageRenderer(content: bar.environment(\.suiteSnapshotRendering, true).frame(width: 240))
        let image = try #require(renderer.cgImage, "the bar drew nothing")
        #expect(image.width >= 240 && image.height > 0)
    }
}
