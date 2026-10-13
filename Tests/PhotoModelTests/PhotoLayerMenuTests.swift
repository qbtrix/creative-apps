// PhotoLayerMenuTests.swift: the Layer menu's enable state and Show/Hide
// title as a user moves through no image, a new image, more layers, hiding
// and deleting, Bring Forward / Send Backward moving the selected layer one
// place as one undo step, and Select Layer Above / Below moving the selection
// with no undo step. Runs on Linux and macOS.
import PhotoModel
import Testing

@Suite struct PhotoLayerMenuTests {
    @Test func everythingIsDisabledWithNoImageOpen() {
        let workspace = PhotoWorkspace()
        #expect(!workspace.canAddLayer)
        #expect(!workspace.canDeleteSelectedLayer)
        #expect(!workspace.canEditSelectedLayer)
        #expect(workspace.visibilityCommandTitle == "Hide Layer")
    }

    @Test func aNewImageEnablesAllButDelete() throws {
        var workspace = PhotoWorkspace()
        try workspace.newCanvas(width: 4, height: 4)
        #expect(workspace.canAddLayer)
        #expect(workspace.canEditSelectedLayer)
        #expect(!workspace.canDeleteSelectedLayer)
    }

    @Test func deleteFollowsTheLayerCount() throws {
        var workspace = PhotoWorkspace()
        try workspace.newCanvas(width: 4, height: 4)
        workspace.addLayer()
        #expect(workspace.canDeleteSelectedLayer)
        if let id = workspace.selectedLayerID { workspace.removeLayer(id) }
        #expect(!workspace.canDeleteSelectedLayer)
        #expect(workspace.canEditSelectedLayer)
    }

    @Test func showHideTitleSaysWhatItWillDo() throws {
        var workspace = PhotoWorkspace()
        try workspace.newCanvas(width: 4, height: 4)
        let id = try #require(workspace.selectedLayerID)
        #expect(workspace.visibilityCommandTitle == "Hide Layer")
        workspace.toggleVisibility(id)
        #expect(workspace.visibilityCommandTitle == "Show Layer")
        workspace.toggleVisibility(id)
        #expect(workspace.visibilityCommandTitle == "Hide Layer")
    }

    @Test func titleFollowsTheSelectedLayer() throws {
        var workspace = PhotoWorkspace()
        try workspace.newCanvas(width: 4, height: 4)
        let background = try #require(workspace.selectedLayerID)
        workspace.toggleVisibility(background)
        workspace.addLayer()
        #expect(workspace.visibilityCommandTitle == "Hide Layer")
        workspace.selectLayer(background)
        #expect(workspace.visibilityCommandTitle == "Show Layer")
    }

    @Test func bringForwardAndSendBackwardMoveTheSelectedLayerOnePlace() throws {
        var workspace = try whiteImage(4, 4)
        let background = try #require(workspace.selectedLayerID)
        workspace.addLayer()
        workspace.addLayer()
        let names = { workspace.layers.map(\.name) }
        #expect(names() == ["Layer 2", "Layer 1", "Background"])
        workspace.selectLayer(background)
        #expect(workspace.canBringSelectedLayerForward && !workspace.canSendSelectedLayerBackward)

        workspace.bringSelectedLayerForward()
        #expect(names() == ["Layer 2", "Background", "Layer 1"])
        #expect(workspace.undoActionName == "Undo Reorder Layers")
        workspace.bringSelectedLayerForward()
        #expect(names() == ["Background", "Layer 2", "Layer 1"])
        #expect(!workspace.canBringSelectedLayerForward && workspace.canSendSelectedLayerBackward)
        #expect(workspace.selectedLayerID == background)

        workspace.sendSelectedLayerBackward()
        #expect(names() == ["Layer 2", "Background", "Layer 1"])
        workspace.undo()
        #expect(names() == ["Background", "Layer 2", "Layer 1"])
    }

    @Test func reorderAtTheEndOfTheStackOrWithNoImageChangesNothing() throws {
        var empty = PhotoWorkspace()
        #expect(!empty.canBringSelectedLayerForward && !empty.canSendSelectedLayerBackward)
        empty.bringSelectedLayerForward()
        empty.sendSelectedLayerBackward()
        #expect(empty == PhotoWorkspace())

        var single = try whiteImage(4, 4)
        let before = single
        #expect(!single.canBringSelectedLayerForward && !single.canSendSelectedLayerBackward)
        single.bringSelectedLayerForward()
        single.sendSelectedLayerBackward()
        #expect(single == before)
        #expect(!single.canUndo)
    }

    @Test func selectLayerAboveAndBelowStepThroughTheStackWithoutAnUndoStep() throws {
        var workspace = try whiteImage(4, 4)
        let background = try #require(workspace.selectedLayerID)
        workspace.addLayer()
        let top = try #require(workspace.selectedLayerID)
        let history = workspace.undoActionName
        workspace.selectLayerAbove()
        #expect(workspace.selectedLayerID == top)
        workspace.selectLayerBelow()
        #expect(workspace.selectedLayerID == background)
        workspace.selectLayerBelow()
        #expect(workspace.selectedLayerID == background)
        workspace.selectLayerAbove()
        #expect(workspace.selectedLayerID == top)
        #expect(workspace.undoActionName == history)

        var empty = PhotoWorkspace()
        empty.selectLayerAbove()
        empty.selectLayerBelow()
        #expect(empty == PhotoWorkspace())
    }
}
