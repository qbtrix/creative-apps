// FlareLayersTests.swift: the Layers section's edits on FlareWorkspace, each a
// FlareCore command with exact undo. Runs on Linux and macOS.
import FlareCore
import FlareModel
import Testing

/// A workspace with a new document and `count` layers added, the last on top.
private func workspace(layers count: Int) -> FlareWorkspace {
    var workspace = FlareWorkspace()
    workspace.newDocument()
    for _ in 0..<count { workspace.addLayer() }
    return workspace
}

@Test func twoAddsGiveLayerOneAndLayerTwoTopFirst() {
    let workspace = workspace(layers: 2)
    #expect(workspace.layers.map(\.name) == ["Layer 2", "Layer 1"])
    #expect(workspace.selectedLayerID == "layer-2")
    #expect(workspace.layerError == nil)
}

@Test func reorderMovesALayer() {
    var workspace = workspace(layers: 3)
    // Drag the top row ("Layer 3") to the bottom of the panel.
    workspace.moveLayer(from: 0, to: 3)
    #expect(workspace.layers.map(\.id) == ["layer-2", "layer-1", "layer-3"])
    workspace.moveLayer(from: 2, to: 1)
    #expect(workspace.layers.map(\.id) == ["layer-2", "layer-3", "layer-1"])
    workspace.moveLayer(from: 5, to: 0)
    #expect(workspace.layers.map(\.id) == ["layer-2", "layer-3", "layer-1"])
    #expect(workspace.layerError == .command(.invalidIndex(5)))
}

@Test func emptyRenameIsRefusedAndTheNameStays() {
    var workspace = workspace(layers: 1)
    workspace.renameLayer("layer-1", to: "   ")
    #expect(workspace.layers.map(\.name) == ["Layer 1"])
    #expect(workspace.layerError == .emptyName)
    workspace.renameLayer("layer-1", to: " Sky ")
    #expect(workspace.layers.map(\.name) == ["Sky"])
    #expect(workspace.layerError == nil)
}

@Test func removingTheSelectedLayerSelectsItsNeighbor() {
    var workspace = workspace(layers: 3)
    workspace.selectLayer("layer-2")
    workspace.removeLayer("layer-2")
    #expect(workspace.layers.map(\.id) == ["layer-3", "layer-1"])
    #expect(workspace.selectedLayerID == "layer-1")
    // The bottom layer's neighbor is the one above it.
    workspace.removeLayer("layer-1")
    #expect(workspace.selectedLayerID == "layer-3")
    workspace.removeLayer("layer-3")
    #expect(workspace.selectedLayerID == nil)
}

@Test func aToggleFlipsOnlyItsOwnLayer() {
    var workspace = workspace(layers: 2)
    workspace.toggleLayerFlag("layer-1", .visible)
    workspace.toggleLayerFlag("layer-2", .locked)
    let flags = workspace.layers.map { [$0.isVisible, $0.isLocked] }
    #expect(flags == [[true, true], [false, false]])
}

@Test func undoAfterAnAddGivesBackTheOriginalDocument() {
    var workspace = workspace(layers: 1)
    let original = workspace.document
    workspace.addLayer()
    #expect(workspace.layers.count == 2)
    workspace.undo()
    #expect(workspace.document == original)
    #expect(workspace.selectedLayerID == nil)
    workspace.redo()
    #expect(workspace.layers.map(\.name) == ["Layer 2", "Layer 1"])
}

@Test func undoRestoresEachLayerEditExactly() {
    var workspace = workspace(layers: 3)
    let original = workspace.document
    workspace.renameLayer("layer-1", to: "Ground")
    workspace.toggleLayerFlag("layer-2", .visible)
    workspace.moveLayer(from: 0, to: 3)
    workspace.removeLayer("layer-2")
    for _ in 0..<4 { workspace.undo() }
    #expect(workspace.document == original)
    #expect(workspace.canUndo)
}

@Test func selectingAnotherSceneClearsTheLayerSelection() {
    var workspace = workspace(layers: 1)
    #expect(workspace.selectedLayerID == "layer-1")
    workspace.selectItem("scene-1")
    #expect(workspace.selectedLayerID == nil)
    workspace.selectItem("layer-1")
    #expect(workspace.selectedLayerID == "layer-1")
    workspace.selectLayer("nope")
    #expect(workspace.selectedLayerID == "layer-1")
}
