// PhotoLayersTests.swift: the layer stack in PhotoWorkspace: add, remove,
// rename, visibility, opacity, blend mode and reorder. Runs on Linux and macOS.
import CoreRaster
import PhotoModel
import Testing

private func workspace(layers extra: Int) throws -> PhotoWorkspace {
    var workspace = PhotoWorkspace()
    try workspace.newCanvas(width: 2, height: 2)
    for _ in 0..<extra { workspace.addLayer() }
    return workspace
}

@Suite struct PhotoLayersTests {
    @Test func newLayerIsNormalOpaqueVisibleWithAUniqueNameAboveTheSelection() throws {
        var workspace = try workspace(layers: 2)
        #expect(workspace.layers.map(\.name) == ["Layer 2", "Layer 1", "Background"])
        workspace.renameLayer("layer-3", to: "Layer 3")
        workspace.selectLayer("layer-1")
        workspace.addLayer()
        #expect(workspace.layers.map(\.name) == ["Layer 3", "Layer 1", "Layer 2", "Background"])
        let added = try #require(workspace.selectedLayer)
        #expect(added.name == "Layer 2")
        #expect(added.blendMode == .normal)
        #expect(added.opacity == 1)
        #expect(added.isVisible)
    }

    @Test func addLayerNeedsACanvas() {
        var workspace = PhotoWorkspace()
        workspace.addLayer()
        #expect(workspace.layers.isEmpty)
    }

    @Test func removingTheLastLayerIsRefused() throws {
        var workspace = try workspace(layers: 0)
        #expect(!workspace.canRemoveLayer)
        let removed = workspace.removeLayer("layer-1")
        #expect(!removed)
        #expect(workspace.layers.map(\.name) == ["Background"])
    }

    @Test func removeSelectsTheLayerThatTookItsPlace() throws {
        var workspace = try workspace(layers: 2)
        workspace.selectLayer("layer-3")
        let removed = workspace.removeLayer("layer-3")
        #expect(removed)
        #expect(workspace.layers.map(\.id) == ["layer-2", "layer-1"])
        #expect(workspace.selectedLayerID == "layer-2")
        let removedMissing = workspace.removeLayer("missing")
        #expect(!removedMissing)
    }

    @Test func reorderMovesALayer() throws {
        var workspace = try workspace(layers: 2)
        // Top first: layer-3, layer-2, layer-1. Drag the top layer to the bottom.
        workspace.moveLayers(fromOffsets: [0], toOffset: 3)
        #expect(workspace.layers.map(\.id) == ["layer-2", "layer-1", "layer-3"])
        workspace.moveLayers(fromOffsets: [2], toOffset: 0)
        #expect(workspace.layers.map(\.id) == ["layer-3", "layer-2", "layer-1"])
        workspace.moveLayers(fromOffsets: [1, 2], toOffset: 0)
        #expect(workspace.layers.map(\.id) == ["layer-2", "layer-1", "layer-3"])
        workspace.moveLayers(fromOffsets: [7], toOffset: 0)
        workspace.moveLayers(fromOffsets: [0], toOffset: 9)
        #expect(workspace.layers.map(\.id) == ["layer-2", "layer-1", "layer-3"])
    }

    @Test func opacityClampsToZeroThroughOne() throws {
        var workspace = try workspace(layers: 0)
        workspace.setOpacity("layer-1", percent: 40)
        #expect(workspace.layers.first?.opacity == 0.4)
        #expect(workspace.layers.first?.opacityPercent == 40)
        workspace.setOpacity("layer-1", percent: 150)
        #expect(workspace.layers.first?.opacity == 1)
        workspace.setOpacity("layer-1", percent: -20)
        #expect(workspace.layers.first?.opacity == 0)
        workspace.setOpacity("layer-1", percent: .nan)
        #expect(workspace.layers.first?.opacity == 0)
        #expect(PhotoLayer(id: "x", name: "x", opacity: 3).opacity == 1)
    }

    @Test func visibilityBlendModeAndRename() throws {
        var workspace = try workspace(layers: 0)
        workspace.toggleVisibility("layer-1")
        workspace.setBlendMode("layer-1", .colorDodge)
        workspace.renameLayer("layer-1", to: "  Sky  ")
        workspace.renameLayer("layer-1", to: "   ")
        let layer = try #require(workspace.layers.first)
        #expect(!layer.isVisible)
        #expect(layer.blendMode == .colorDodge)
        #expect(layer.name == "Sky")
    }

    @Test func blendModeTitles() {
        #expect(BlendMode.normal.title == "Normal")
        #expect(BlendMode.colorDodge.title == "Color Dodge")
        #expect(BlendMode.softLight.title == "Soft Light")
    }
}
