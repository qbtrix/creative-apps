// PhotoSeveralLayersTests.swift: Hide and Show, Opacity, Delete and Move on
// every picked layer, one undo step each (multi-layer-select PM-2, PM-5,
// PM-6). An eye or slider on an unpicked row acts on that row alone; Delete
// refuses to take every layer. Runs on Linux and macOS.
import CoreRaster
import SuiteKernel
import Testing
@testable import PhotoModel

/// Four layers (fourLayers) with Layer 1 and Layer 3 picked, Layer 3 the
/// primary. Picked on the kernel selection, so it holds before PM-4's Command-click.
private func onePlusThree() throws -> (PhotoWorkspace, one: PhotoLayer.ID, two: PhotoLayer.ID, three: PhotoLayer.ID) {
    var workspace = try fourLayers()
    let (one, two, three) = (layerID(workspace, "Layer 1"), layerID(workspace, "Layer 2"), layerID(workspace, "Layer 3"))
    workspace.layerSelection.replace([one, three])
    return (workspace, one, two, three)
}

private func layer(_ workspace: PhotoWorkspace, _ id: PhotoLayer.ID) -> PhotoLayer? {
    workspace.layers.first { $0.id == id }
}

@Suite struct PhotoSeveralLayersTests {
    @Test func anEyeOnAPickedRowHidesEveryPickedLayer() throws {
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

    @Test func opacityAppliesToEvery() throws {
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

    @Test func threePickedDeleteInOneStepAndUndoKeepsTheOrder() throws {
        var (workspace, one, two, three) = try onePlusThree()
        let before = workspace.layers.map(\.id)
        workspace.layerSelection.replace([one, two, three])
        workspace.removeSelectedLayers()
        #expect(workspace.layers.map(\.name) == ["Background"])
        #expect(workspace.undoActionName == "Undo Delete Layers")
        workspace.undo()
        #expect(workspace.layers.map(\.id) == before)
    }

    @Test func oneStepForSeveral() throws {
        var (workspace, one, _, _) = try onePlusThree()
        let (before, undoName) = (workspace.layers, workspace.undoActionName)
        workspace.toggleVisibility(one)
        workspace.undo()
        #expect(workspace.layers == before)
        #expect(workspace.undoActionName == undoName)
    }

    @Test func anEyeOnAHiddenPickedRowShowsEveryPickedLayer() throws {
        var (workspace, one, _, three) = try onePlusThree()
        workspace.toggleVisibility(three)
        workspace.toggleVisibility(three)
        #expect(layer(workspace, one)?.isVisible == true && layer(workspace, three)?.isVisible == true)
        #expect(workspace.undoActionName == "Undo Show Layers")
    }

    @Test func commandsPickAndSetOpacity() throws {
        var (workspace, one, two, three) = try onePlusThree()
        let catalog = PhotoWorkspace.catalog
        _ = try catalog.run("layer.set-opacity", params: .object(["percent": .number(25)]), on: &workspace)
        #expect(layer(workspace, one)?.opacity == 0.25 && layer(workspace, three)?.opacity == 0.25)
        #expect(layer(workspace, two)?.opacity == 1)
        _ = try catalog.run("layer.select-all", params: .object([:]), on: &workspace)
        #expect(workspace.selectedLayerIDs.count == 4)
        _ = try catalog.run("layer.pick", params: .object(["id": .string(two), "mode": .string("replace")]), on: &workspace)
        #expect(workspace.selectedLayerIDs == [two])
        #expect(throws: (any Error).self) {
            try catalog.run("layer.pick", params: .object(["id": .string("layer-99"), "mode": .string("replace")]), on: &workspace)
        }
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
