// FlareKernelLayersTests.swift: Flare's layers projected through SuiteKernel's LayerTree (adopt-kernel-layers
// AL-f1). The tree's front-to-back order and rows are Flare's panel order, names and flags, and a panel move
// runs through LayerTree.move before FlareCore's ReorderLayer. Runs on Linux and macOS.
import FlareCore
@testable import FlareModel
import SuiteKernel
import Testing

/// A workspace with a new document and `count` layers added, the last on top.
private func workspace(layers count: Int) -> FlareWorkspace {
    var workspace = FlareWorkspace()
    workspace.newDocument()
    for _ in 0..<count { workspace.addLayer() }
    return workspace
}

@Test func theTreeListsFlaresLayersFrontToBack() {
    var workspace = workspace(layers: 3)
    workspace.renameLayer("layer-1", to: "Ground")
    #expect(workspace.layerTree.frontToBack == ["layer-3", "layer-2", "layer-1"])
    #expect(workspace.layerTree.frontToBack == workspace.layers.map(\.id))
    #expect(workspace.layerTree.roots.map(\.id) == ["layer-1", "layer-2", "layer-3"])
}

@Test func theRowsCarryEachLayersNameAndFlagsTopFirst() {
    var workspace = workspace(layers: 3)
    workspace.renameLayer("layer-2", to: "Sky")
    workspace.toggleLayerFlag("layer-1", .visible)
    workspace.toggleLayerFlag("layer-3", .locked)
    let rows = workspace.layerRows
    #expect(rows.map(\.id) == workspace.layers.map(\.id))
    #expect(rows.map(\.name) == ["Layer 3", "Sky", "Layer 1"])
    #expect(rows.map(\.isHidden) == [false, false, true])
    #expect(rows.map(\.isLocked) == [true, false, false])
    #expect(rows.allSatisfy { $0.depth == 0 && !$0.holdsChildren && !$0.isExpanded })
}

@Test func noOwnerGivesAnEmptyTree() {
    let workspace = FlareWorkspace()
    #expect(workspace.layerTree.roots.isEmpty)
    #expect(workspace.layerRows.isEmpty)
}

/// The tree a panel drag from row `source` to `destination` should leave, by LayerTree.move itself.
private func movedByKernel(_ tree: LayerTree<FlareLayerPayload>, from source: Int, to destination: Int) throws
    -> LayerTree<FlareLayerPayload> {
    var tree = tree
    let rows = tree.frontToBack
    let row = destination > source ? destination - 1 : destination
    try tree.move(rows[source], into: nil, at: rows.count - 1 - row)
    return tree
}

@Test(arguments: [(0, 3), (2, 1), (0, 2), (2, 0), (1, 3), (3, 0), (1, 0)])
func aPanelMoveReordersAsLayerTreeMoveDoes(source: Int, destination: Int) throws {
    var workspace = workspace(layers: 4)
    let expected = try movedByKernel(workspace.layerTree, from: source, to: destination)
    workspace.moveLayer(from: source, to: destination)
    #expect(workspace.layerError == nil)
    #expect(workspace.layerTree.frontToBack == expected.frontToBack)
    #expect(workspace.layers.map(\.id) == expected.frontToBack)
}

@Test func aMoveIsOneUndoStep() {
    var workspace = workspace(layers: 3)
    let original = workspace.document
    workspace.moveLayer(from: 0, to: 3)
    #expect(workspace.layers.map(\.id) == ["layer-2", "layer-1", "layer-3"])
    workspace.undo()
    #expect(workspace.document == original)
}

@Test func aMoveTheKernelRefusesGivesNoReorder() {
    let layers = [Layer(id: "a", name: "A"), Layer(id: "b", name: "B")]
    #expect(FlareWorkspace.kernelReorderIndex("gone", toRow: 0, in: layers) == nil)
    #expect(FlareWorkspace.kernelReorderIndex("a", toRow: 0, in: layers) == 1)
    #expect(FlareWorkspace.kernelReorderIndex("b", toRow: 1, in: layers) == 0)
}
