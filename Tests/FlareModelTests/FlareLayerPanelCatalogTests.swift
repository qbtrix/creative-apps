// FlareLayerPanelCatalogTests.swift: the LAYERS panel's own catalog commands,
// over the selected layer: New Layer (needs a scene), Delete Layer, Hide/Show
// and Lock/Unlock (each needs a selected layer), titled by the layer's state,
// each one undo step through the workspace's own methods. Linux-safe.
import FlareCore
import SuiteKernel
import Testing
@testable import FlareModel

struct FlareLayerPanelCatalogTests {
    private func run(_ id: String, _ ws: inout FlareWorkspace) throws {
        _ = try FlareWorkspace.catalog.run(id, params: .object([:]), on: &ws)
    }

    @Test func availabilityFollowsTheSelection() {
        let none = FlareWorkspace(services: .fake())
        #expect(FlareWorkspace.catalog.availability("layers.add", on: none).why == "Select a scene to add a layer to.")
        var empty = none
        empty.newDocument()
        #expect(FlareWorkspace.catalog.availability("layers.add", on: empty) == .available)
        for id in ["layers.remove", "layers.toggle-visible", "layers.toggle-locked"] {
            #expect(FlareWorkspace.catalog.availability(id, on: none).why == "Select a layer first.", "\(id)")
        }
    }

    @Test func eachRunsOnTheSelectedLayer() throws {
        var ws = FlareCommandCatalogTests.lawsFixture()
        let count = ws.layers.count
        try run("layers.add", &ws)
        #expect(ws.layers.count == count + 1 && ws.undoActionName != nil)
        let added = try #require(ws.selectedLayerID)
        #expect(ws.menuTitle("layers.toggle-visible") == "Hide Layer" && ws.menuTitle("layers.toggle-locked") == "Lock Layer")
        try run("layers.toggle-visible", &ws)
        try run("layers.toggle-locked", &ws)
        let layer = try #require(ws.layers.first { $0.id == added })
        #expect(!layer.isVisible && layer.isLocked)
        #expect(ws.menuTitle("layers.toggle-visible") == "Show Layer" && ws.menuTitle("layers.toggle-locked") == "Unlock Layer")
        try run("layers.remove", &ws)
        #expect(ws.layers.count == count && !ws.layers.contains { $0.id == added })
    }
}
