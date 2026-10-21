// PhotoSeveralLayersTests.swift: Hide and Show, Opacity, Delete and Move on
// every picked layer, one undo step each (multi-layer-select PM-2, PM-5,
// PM-6). An eye or slider on an unpicked row acts on that row alone; Delete
// refuses to take every layer. Runs on Linux and macOS.
import CoreRaster
import PhotoModel
import SuiteKernel
import Testing

/// Four layers (fourLayers) with Layer 1 and Layer 3 picked, Layer 3 the primary.
private func onePlusThree() throws -> (PhotoWorkspace, one: PhotoLayer.ID, two: PhotoLayer.ID, three: PhotoLayer.ID) {
    var workspace = try fourLayers()
    let (one, two, three) = (layerID(workspace, "Layer 1"), layerID(workspace, "Layer 2"), layerID(workspace, "Layer 3"))
    workspace.pickLayer(one, .replace)
    workspace.pickLayer(three, .toggle)
    return (workspace, one, two, three)
}

private func layer(_ workspace: PhotoWorkspace, _ id: PhotoLayer.ID) -> PhotoLayer? {
    workspace.layers.first { $0.id == id }
}

@Suite struct PhotoSeveralLayersTests {
    @Test(.disabled("waits on PM-5")) func anEyeOnAPickedRowHidesEveryPickedLayer() throws {
        var (workspace, one, two, three) = try onePlusThree()
        workspace.toggleVisibility(one)
        #expect(layer(workspace, one)?.isVisible == false && layer(workspace, three)?.isVisible == false)
        #expect(layer(workspace, two)?.isVisible == true)
        #expect(workspace.undoActionName == "Undo Hide Layers")
    }

    @Test func anEyeOnAnUnpickedRowHidesOnlyThatLayer() throws {
        var (workspace, one, two, three) = try onePlusThree()
        workspace.toggleVisibility(two)
        #expect(layer(workspace, two)?.isVisible == false)
        #expect(layer(workspace, one)?.isVisible == true && layer(workspace, three)?.isVisible == true)
        #expect(workspace.undoActionName == "Undo Hide Layer")
    }

    @Test(.disabled("waits on PM-5")) func opacityAppliesToEvery() throws {
        var (workspace, one, two, three) = try onePlusThree()
        let before = workspace.layers
        workspace.setOpacity(three, percent: 50)
        #expect(layer(workspace, one)?.opacity == 0.5 && layer(workspace, three)?.opacity == 0.5)
        #expect(layer(workspace, two)?.opacity == 1)
        workspace.setOpacity(three, percent: 40)
        workspace.setOpacity(three, percent: 30)
        workspace.undo()
        #expect(workspace.layers == before)
    }

    @Test func deleteRefusesAll() throws {
        var workspace = try fourLayers()
        #expect(workspace.removeSelectedHelp == nil)
        workspace.selectAllLayers()
        #expect(workspace.removeSelectedHelp == "At least one layer must stay.")
        let before = workspace.layers
        workspace.removeSelectedLayers()
        #expect(workspace.layers == before)
    }

    @Test(.disabled("waits on PM-5")) func threePickedDeleteInOneStepAndUndoKeepsTheOrder() throws {
        var (workspace, _, two, _) = try onePlusThree()
        let before = workspace.layers.map(\.id)
        workspace.pickLayer(two, .toggle)
        workspace.removeSelectedLayers()
        #expect(workspace.layers.map(\.name) == ["Background"])
        #expect(workspace.undoActionName == "Undo Delete Layers")
        workspace.undo()
        #expect(workspace.layers.map(\.id) == before)
    }

    @Test(.disabled("waits on PM-5")) func oneStepForSeveral() throws {
        var (workspace, one, _, _) = try onePlusThree()
        let (before, undoName) = (workspace.layers, workspace.undoActionName)
        workspace.toggleVisibility(one)
        workspace.undo()
        #expect(workspace.layers == before)
        #expect(workspace.undoActionName == undoName)
    }

    @Test(.disabled("waits on PM-6")) func moveMovesEvery() throws {
        var (workspace, one, two, three) = try onePlusThree()
        stroke(&workspace, .move, from: point(2, 2), to: point(5, 3))
        #expect(layer(workspace, one)?.offsetX == 3 && layer(workspace, one)?.offsetY == 1)
        #expect(layer(workspace, three)?.offsetX == 3 && layer(workspace, three)?.offsetY == 1)
        #expect(layer(workspace, two)?.offsetX == 0)
        #expect(workspace.undoActionName == "Undo Move Layers")
        workspace.moveSelectedLayers(dx: -1, dy: 2)
        #expect(layer(workspace, one)?.offsetX == 2 && layer(workspace, three)?.offsetY == 3)
        workspace.undo()
        workspace.undo()
        #expect(layer(workspace, one)?.offsetX == 0 && layer(workspace, three)?.offsetX == 0)
    }

    @Test func moveSelectedLayersMovesThePrimaryInOneStep() throws {
        var workspace = try fourLayers()
        let top = try #require(workspace.selectedLayerID)
        workspace.moveSelectedLayers(dx: 4, dy: -2)
        #expect(layer(workspace, top)?.offsetX == 4 && layer(workspace, top)?.offsetY == -2)
        workspace.undo()
        #expect(layer(workspace, top)?.offsetX == 0 && layer(workspace, top)?.offsetY == 0)
    }
}
