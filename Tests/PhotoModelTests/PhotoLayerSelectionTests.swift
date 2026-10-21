// PhotoLayerSelectionTests.swift: picking several layers in Photo's Layers
// list on the kernel's Selection (multi-layer-select PM-2, PM-4): Shift picks
// a top-first range from the anchor, Command toggles, All picks every layer,
// a delete or an undo leaves only live ids, and the selection is never empty
// while there are layers. `selectedLayerID` stays the primary, and setting it
// leaves one layer picked. Runs on Linux and macOS.
import CoreRaster
@testable import PhotoModel
import SuiteKernel
import Testing

/// A white image with Background and Layer 1 to 3 above it, Layer 3 on top
/// and selected.
func fourLayers() throws -> PhotoWorkspace {
    var workspace = try whiteImage(8, 8)
    for _ in 0..<3 { workspace.addLayer() }
    return workspace
}

/// The id of the layer named `name`; "" for none.
func layerID(_ workspace: PhotoWorkspace, _ name: String) -> PhotoLayer.ID {
    workspace.layers.first { $0.name == name }?.id ?? ""
}

@Suite struct PhotoLayerSelectionTests {
    @Test func settingTheSelectedLayerLeavesOnePicked() throws {
        var workspace = try fourLayers()
        let one = layerID(workspace, "Layer 1")
        workspace.selectAllLayers()
        workspace.selectedLayerID = one
        #expect(workspace.selectedLayerIDs == [one])
        #expect(workspace.selectedLayerID == one && workspace.layerSelection.primary == one)
        workspace.selectedLayerID = nil
        #expect(workspace.selectedLayerIDs.isEmpty && workspace.selectedLayerID == nil)
    }

    @Test func aPlainPickReplacesTheSelection() throws {
        var workspace = try fourLayers()
        let two = layerID(workspace, "Layer 2")
        workspace.pickLayer(two, .replace)
        #expect(workspace.selectedLayerIDs == [two] && workspace.selectedLayerID == two)
        workspace.pickLayer("layer-99", .replace)
        #expect(workspace.selectedLayerIDs == [two])
    }

    @Test func allPicksEveryLayerTopFirst() throws {
        var workspace = try fourLayers()
        let top = workspace.selectedLayerID
        workspace.selectAllLayers()
        #expect(workspace.selectedLayerIDs == workspace.layers.map(\.id))
        #expect(workspace.selectedLayerID == top)
    }

    @Test(.disabled("waits on PM-4")) func shiftPicksATopFirstRangeFromTheAnchor() throws {
        var workspace = try fourLayers()
        let (one, two, three) = (layerID(workspace, "Layer 1"), layerID(workspace, "Layer 2"), layerID(workspace, "Layer 3"))
        workspace.pickLayer(one, .replace)
        workspace.pickLayer(three, .extend)
        #expect(workspace.selectedLayerIDs == [three, two, one])
        #expect(workspace.selectedLayerID == three)
        workspace.pickLayer(two, .extend)
        #expect(workspace.selectedLayerIDs == [two, one])
        #expect(workspace.selectedLayerID == two)
    }

    @Test(.disabled("waits on PM-4")) func commandTogglesOneLayer() throws {
        var workspace = try fourLayers()
        let (one, three) = (layerID(workspace, "Layer 1"), layerID(workspace, "Layer 3"))
        workspace.pickLayer(one, .replace)
        workspace.pickLayer(three, .toggle)
        #expect(workspace.selectedLayerIDs == [three, one] && workspace.selectedLayerID == three)
        workspace.pickLayer(three, .toggle)
        #expect(workspace.selectedLayerIDs == [one] && workspace.selectedLayerID == one)
    }

    @Test func togglingTheLastPickedLayerKeepsOne() throws {
        var workspace = try fourLayers()
        let one = layerID(workspace, "Layer 1")
        workspace.pickLayer(one, .replace)
        workspace.pickLayer(one, .toggle)
        #expect(!workspace.selectedLayerIDs.isEmpty && workspace.selectedLayerID != nil)
    }

    @Test(.disabled("waits on PM-4")) func deletingThePrimaryLeavesTheRestWithANewPrimary() throws {
        var workspace = try fourLayers()
        let (one, three) = (layerID(workspace, "Layer 1"), layerID(workspace, "Layer 3"))
        workspace.pickLayer(one, .replace)
        workspace.pickLayer(three, .toggle)
        workspace.removeLayer(three)
        #expect(workspace.selectedLayerIDs == [one] && workspace.selectedLayerID == one)
    }

    @Test func undoRestoresALayerAndKeepsOnlyLiveIDs() throws {
        var workspace = try fourLayers()
        let one = layerID(workspace, "Layer 1")
        workspace.selectAllLayers()
        workspace.removeLayer(one)
        workspace.undo()
        #expect(workspace.layers.contains { $0.id == one })
        workspace.addLayer()
        workspace.selectAllLayers()
        workspace.undo()
        let live = Set(workspace.layers.map(\.id))
        #expect(workspace.layerSelection.ordered.allSatisfy(live.contains))
        #expect(!workspace.selectedLayerIDs.isEmpty)
        #expect(workspace.selectedLayerID.map(live.contains) == true)
    }
}
