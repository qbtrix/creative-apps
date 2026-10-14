// PhotoHistoryStepsTests.swift: the history list (#25): named steps from
// "New Image" or "Open" through every undo and redo step, the current step,
// and jumping to a step. Runs on Linux and macOS.
import CoreRaster
import PhotoModel
import Testing

@Suite struct PhotoHistoryStepsTests {
    /// A new image with "New Layer", "Rename Layer" and "Hide Layer" steps.
    private func threeEdits() throws -> (PhotoWorkspace, PhotoLayer.ID) {
        var workspace = try whiteImage(4, 4)
        workspace.addLayer()
        let id = try #require(workspace.selectedLayerID)
        workspace.renameLayer(id, to: "Sky")
        workspace.toggleVisibility(id)
        return (workspace, id)
    }

    @Test func noImageHasNoSteps() {
        let workspace = PhotoWorkspace()
        #expect(workspace.historySteps.isEmpty)
        #expect(workspace.historyIndex == 0)
    }

    @Test func aNewImageStartsAtNewImage() throws {
        let workspace = try whiteImage(4, 4)
        #expect(workspace.historySteps == ["New Image"])
        #expect(workspace.historyIndex == 0)
    }

    @Test func anOpenedFileStartsAtOpen() throws {
        var workspace = PhotoWorkspace()
        try workspace.open(rgba8: [255, 0, 0, 255], width: 1, height: 1, name: "red.png")
        #expect(workspace.historySteps == ["Open"])
    }

    @Test func eachEditIsANamedStepAndUndoMovesTheIndex() throws {
        var (workspace, _) = try threeEdits()
        #expect(workspace.historySteps == ["New Image", "New Layer", "Rename Layer", "Hide Layer"])
        #expect(workspace.historyIndex == 3)
        workspace.undo()
        #expect(workspace.historySteps == ["New Image", "New Layer", "Rename Layer", "Hide Layer"])
        #expect(workspace.historyIndex == 2)
    }

    @Test func jumpBackRestoresThatStepsLayers() throws {
        var (workspace, id) = try threeEdits()
        let finalLayers = workspace.layers
        workspace.jumpToHistoryStep(1)
        #expect(workspace.historyIndex == 1)
        #expect(workspace.layers.first { $0.id == id }?.name == "Layer 1")
        #expect(workspace.layers.first { $0.id == id }?.isVisible == true)
        workspace.jumpToHistoryStep(0)
        #expect(workspace.layers.count == 1 && workspace.pixels.count == 1)
        workspace.jumpToHistoryStep(3)
        #expect(workspace.historyIndex == 3)
        #expect(workspace.layers == finalLayers)
        #expect(workspace.pixels.count == 2)
    }

    @Test func anEditAfterAJumpDropsTheLaterSteps() throws {
        var (workspace, id) = try threeEdits()
        workspace.jumpToHistoryStep(1)
        workspace.setBlendMode(id, .screen)
        #expect(workspace.historySteps == ["New Image", "New Layer", "Blend Mode"])
        #expect(workspace.historyIndex == 2)
        #expect(!workspace.canRedo)
    }

    @Test func oneDragOnTheSameControlIsOneStep() throws {
        var workspace = try whiteImage(4, 4)
        let id = try #require(workspace.selectedLayerID)
        workspace.setOpacity(id, percent: 80)
        workspace.setOpacity(id, percent: 60)
        workspace.endAdjust()
        #expect(workspace.historySteps == ["New Image", "Layer Opacity"])
        workspace.setOpacity(id, percent: 40)
        #expect(workspace.historySteps == ["New Image", "Layer Opacity", "Layer Opacity"])
    }

    @Test func outOfRangeOrCurrentJumpsChangeNothing() throws {
        var (workspace, _) = try threeEdits()
        let before = workspace
        for index in [-1, 4, 99, 3] { workspace.jumpToHistoryStep(index) }
        #expect(workspace == before)
        #expect(workspace.revision == before.revision)
    }

    @Test func aJumpMidDragIsIgnored() throws {
        var (workspace, _) = try threeEdits()
        workspace.selectTool(.brush)
        workspace.drag(from: point(0, 0), to: point(0, 0))
        workspace.jumpToHistoryStep(0)
        #expect(workspace.historyIndex == 3)
        workspace.endDrag()
        #expect(workspace.historySteps.last == "Paint")
    }

    @Test func pastTheLimitTheFirstStepIsTheNewestDroppedOne() throws {
        var workspace = try whiteImage(4, 4)
        let id = try #require(workspace.selectedLayerID)
        workspace.renameLayer(id, to: "First")
        for _ in 0..<50 { workspace.toggleVisibility(id) }
        #expect(workspace.historySteps.count == 51)
        #expect(workspace.historySteps.first == "Rename Layer")
        workspace.jumpToHistoryStep(0)
        #expect(workspace.layers.first?.name == "First")
        #expect(!workspace.canUndo)
    }
}
