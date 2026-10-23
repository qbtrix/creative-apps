// PhotoKernelLayersTests.swift: Photo's layer stack run on SuiteKernel's
// LayerTree (adopt-kernel-layers AL-p1). Reorder, arrange, duplicate, remove
// and show/hide give what the kernel gives on the same tree, each one undo
// step, and a refusal changes nothing. Runs on Linux and macOS.
import CoreRaster
@testable import PhotoModel
import SuiteKernel
import Testing

/// A 2×2 image with `extra` layers added over the Background, the last on top.
private func workspace(layers extra: Int) throws -> PhotoWorkspace {
    var workspace = PhotoWorkspace()
    try workspace.newCanvas(width: 2, height: 2)
    for _ in 0..<extra { workspace.addLayer() }
    return workspace
}

/// What a list drag does to `ids`: the reference `moveLayers` must match.
private func listMoved(_ ids: [String], _ offsets: Set<Int>, _ destination: Int) -> [String] {
    let moving = ids.indices.filter { offsets.contains($0) }.map { ids[$0] }
    var staying = ids.indices.filter { !offsets.contains($0) }.map { ids[$0] }
    staying.insert(contentsOf: moving, at: destination - offsets.filter { $0 < destination }.count)
    return staying
}

@Suite struct PhotoKernelLayersTests {
    @Test func theTreeHoldsTheLayersBottomFirstAsFlatRoots() throws {
        var workspace = try workspace(layers: 2)
        workspace.toggleVisibility("layer-2")
        let tree = workspace.layerTree
        #expect(tree.roots.map(\.id) == ["layer-1", "layer-2", "layer-3"])
        #expect(tree.frontToBack == workspace.layers.map(\.id))
        #expect(tree.roots.allSatisfy { $0.children.isEmpty && !$0.payload.holdsChildren })
        let rows = tree.rows(expanded: [])
        #expect(rows.map(\.name) == workspace.layers.map(\.name))
        #expect(rows.map(\.isHidden) == [false, true, false])
        #expect(PhotoWorkspace.layers(of: tree) == workspace.layers)
    }

    @Test func everyListDragMatchesTheKernelAndTheListsOwnMove() throws {
        let base = try workspace(layers: 3)
        let ids = base.layers.map(\.id)
        for mask in 1..<(1 << ids.count) {
            let offsets = Set(ids.indices.filter { mask & (1 << $0) != 0 })
            for destination in 0...ids.count {
                var workspace = base
                workspace.moveLayers(fromOffsets: Array(offsets), toOffset: destination)
                let expected = listMoved(ids, offsets, destination)
                #expect(workspace.layers.map(\.id) == expected, "offsets \(offsets.sorted()) to \(destination)")
                let steps = expected == ids ? 0 : 1
                #expect(workspace.historySteps.count == base.historySteps.count + steps)
            }
        }
    }

    @Test func oneLayersDragIsTheKernelsMove() throws {
        let base = try workspace(layers: 3)
        for row in 0..<4 {
            var workspace = base
            workspace.moveLayers(fromOffsets: [3], toOffset: row)
            var tree = base.layerTree
            // Top-first row `row` is bottom-first index 3 - row once the layer is out.
            try tree.move("layer-1", into: nil, at: 3 - row)
            #expect(workspace.layerTree.roots.map(\.id) == tree.roots.map(\.id))
        }
    }

    @Test func bringForwardAndSendBackwardAreTheKernelsArrange() throws {
        var workspace = try workspace(layers: 2)
        workspace.selectLayer("layer-1")
        var tree = workspace.layerTree
        try tree.arrange(.bringForward, ["layer-1"])
        workspace.bringSelectedLayerForward()
        #expect(workspace.layerTree.roots.map(\.id) == tree.roots.map(\.id))
        #expect(workspace.layers.map(\.id) == ["layer-3", "layer-1", "layer-2"])
        try tree.arrange(.sendBackward, ["layer-1"])
        workspace.sendSelectedLayerBackward()
        #expect(workspace.layerTree.roots.map(\.id) == tree.roots.map(\.id))
        #expect(workspace.historySteps.suffix(2) == ["Reorder Layers", "Reorder Layers"])
        workspace.undo()
        #expect(workspace.layers.map(\.id) == ["layer-3", "layer-1", "layer-2"])
    }

    @Test func duplicateIsTheKernelsDuplicateWithAFreshIdAndEveryProperty() throws {
        var workspace = try workspace(layers: 2)
        workspace.selectLayer("layer-2")
        workspace.setOpacity("layer-2", percent: 40)
        workspace.setBlendMode("layer-2", .multiply)
        workspace.toggleVisibility("layer-2")
        let before = workspace.layers
        var tree = workspace.layerTree
        let copies = tree.duplicate(["layer-2"]) { "layer-4" }
        workspace.duplicateSelectedLayer()
        #expect(copies == ["layer-4"])
        #expect(workspace.layerTree.roots.map(\.id) == tree.roots.map(\.id))
        let copy = try #require(workspace.selectedLayer)
        #expect(copy.id == "layer-4")
        #expect(copy.name == "Layer 1 copy")
        #expect(copy.opacity == 0.4 && copy.blendMode == .multiply && !copy.isVisible)
        #expect(workspace.pixels["layer-4"] != nil)
        #expect(workspace.historySteps.last == "Duplicate Layer")
        workspace.addLayer()
        #expect(workspace.selectedLayerID == "layer-5")
        workspace.undo()
        workspace.undo()
        #expect(workspace.layers == before)
    }

    @Test func removeLeavesTheKernelsTreeWithoutTheLayer() throws {
        var workspace = try workspace(layers: 2)
        let expected = workspace.layerTree.frontToBack.filter { $0 != "layer-2" }
        workspace.removeLayer("layer-2")
        #expect(workspace.layerTree.frontToBack == expected)
    }

    @Test func showHideIsTheNodesHiddenFlagAsOneStep() throws {
        var workspace = try workspace(layers: 1)
        workspace.toggleVisibility("layer-1")
        #expect(workspace.layerTree.node("layer-1")?.isHidden == true)
        #expect(workspace.layers.map(\.isVisible) == [true, false])
        #expect(workspace.historySteps.last == "Hide Layer")
        workspace.undo()
        #expect(workspace.layerTree.node("layer-1")?.isHidden == false)
    }

    @Test func aRefusalChangesNothing() throws {
        var workspace = try workspace(layers: 2)
        let before = workspace
        let refused = PhotoWorkspace.kernelEdited(workspace.layers) {
            (tree: inout LayerTree<PhotoLayer>) throws(TreeRefusal) in
            // A multi-layer drag refused part way: the first move ran, the next is refused.
            try tree.move("layer-1", into: nil, at: 3)
            try tree.move("layer-3", into: "layer-1", at: 0)
        }
        #expect(refused == nil)
        workspace.commitKernelLayers(refused, named: "Reorder Layers")
        workspace.arrangeLayer("missing", .bringForward)
        #expect(workspace.kernelDuplicate("missing", named: "missing copy") == nil)
        #expect(workspace == before)
        #expect(workspace.historySteps == before.historySteps)
        workspace.selectLayer("layer-3")
        workspace.bringSelectedLayerForward()
        workspace.selectLayer("layer-1")
        workspace.sendSelectedLayerBackward()
        #expect(workspace.layers == before.layers)
        #expect(workspace.historySteps == before.historySteps)
    }
}
