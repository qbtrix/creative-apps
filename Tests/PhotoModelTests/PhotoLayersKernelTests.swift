// PhotoLayersKernelTests.swift: what Photo's Layers panel hands LayerTreeList
// (AL-p3): rows top first, captions (info line, blend summary), and a drop
// (index from the bottom) mapped to the list move the kernel's order gives.
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

@Suite struct PhotoLayersKernelTests {
    @Test func rowsAreTheLayersTopFirst() throws {
        var workspace = try workspace(layers: 2)
        workspace.toggleVisibility("layer-1")
        let rows = workspace.layerRows
        #expect(rows.map(\.id) == ["layer-3", "layer-2", "layer-1"])
        #expect(rows.map(\.name) == workspace.layers.map(\.name))
        #expect(rows.map(\.isHidden) == [false, false, true])
        #expect(rows.allSatisfy { $0.depth == 0 && !$0.holdsChildren && !$0.isLocked })
    }

    @Test func captionIsTheInfoLineThenTheBlendSummary() throws {
        var workspace = try workspace(layers: 1)
        #expect(workspace.layerCaption("layer-2") == nil, "a Normal layer at 100% has no caption")
        workspace.setBlendMode("layer-2", .multiply)
        workspace.setOpacity("layer-2", percent: 50)
        #expect(workspace.layerCaption("layer-2") == "Multiply 50%")
        workspace.addAdjustmentLayer(.curves)
        let curves = try #require(workspace.layers.first).id
        workspace.moveLayers(fromOffsets: [0], toOffset: workspace.layers.count)
        #expect(workspace.layerCaption(curves) == "Nothing below to adjust.")
        workspace.setOpacity(curves, percent: 40)
        #expect(workspace.layerCaption(curves) == "Nothing below to adjust. · Normal 40%")
        #expect(workspace.layerCaption("nope") == nil)
    }

    /// Every drop of every layer at every index among the others gives the
    /// order the kernel's move gives on the same tree.
    @Test func everyDropMapsToTheKernelsOrder() throws {
        let base = try workspace(layers: 3)
        for id in base.layers.map(\.id) {
            for index in 0..<base.layers.count {
                var tree = base.layerTree
                try tree.move(id, into: nil, at: index)
                let expected = Array(tree.frontToBack)
                var workspace = base
                if let move = workspace.layerListMove(id, parent: nil, index: index) {
                    workspace.moveLayers(fromOffsets: [move.offset], toOffset: move.destination)
                }
                #expect(workspace.layers.map(\.id) == expected, "\(id) to \(index)")
                let steps = expected == base.layers.map(\.id) ? 0 : 1
                #expect(workspace.historySteps.count == base.historySteps.count + steps)
            }
        }
    }

    @Test func aDropThatCantLandMapsToNothing() throws {
        let workspace = try workspace(layers: 2)
        #expect(workspace.layerListMove("layer-3", parent: nil, index: 2) == nil, "the top layer dropped on top")
        #expect(workspace.layerListMove("nope", parent: nil, index: 0) == nil)
        #expect(workspace.layerListMove("layer-1", parent: "layer-2", index: 0) == nil, "a layer holds no layers")
        #expect(workspace.layerListMove("layer-1", parent: nil, index: 3) == nil)
        #expect(workspace.layerListMove("layer-1", parent: nil, index: 2).map { [$0.offset, $0.destination] } == [2, 0])
    }
}
