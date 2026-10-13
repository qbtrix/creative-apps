// PhotoHistoryTests.swift: every document edit is one named undo step, redo
// makes it again, and a new edit clears redo. Runs on Linux and macOS.
import CoreRaster
import PhotoModel
import Testing

@Suite struct PhotoHistoryTests {
    @Test func layerEditsUndoAndRedoByName() throws {
        var workspace = try whiteImage(4, 4)
        let original = workspace.layers
        workspace.addLayer()
        let id = try #require(workspace.selectedLayerID)
        workspace.renameLayer(id, to: "Sky")
        workspace.toggleVisibility(id)
        workspace.setBlendMode(id, .screen)
        workspace.moveLayers(fromOffsets: [0], toOffset: 2)
        for (name, check) in [
            ("Reorder Layers", { (w: PhotoWorkspace) in w.layers.first?.id == id }),
            ("Blend Mode", { $0.layers.first?.blendMode == .normal }),
            ("Hide Layer", { $0.layers.first?.isVisible == true }),
            ("Rename Layer", { $0.layers.first?.name == "Layer 1" }),
            ("New Layer", { $0.layers == original }),
        ] {
            #expect(workspace.undoActionName == "Undo \(name)")
            workspace.undo()
            #expect(check(workspace), "after undoing \(name)")
        }
        #expect(!workspace.canUndo)
        workspace.redo()
        #expect(workspace.layers.count == 2 && workspace.pixels.count == 2)
    }

    @Test func deleteLayerUndoesWithItsPixels() throws {
        var workspace = try whiteImage(4, 4)
        addFilledLayer(&workspace, red: 0, green: 0, blue: 255)
        let painted = try workspace.composite()
        #expect(workspace.removeLayer(try #require(workspace.selectedLayerID)))
        workspace.undo()
        #expect(try workspace.composite() == painted)
    }

    @Test func oneLayersOpacityRunIsOneStep() throws {
        var workspace = try whiteImage(4, 4)
        let id = try #require(workspace.selectedLayerID)
        for percent in [90.0, 80, 70, 60] { workspace.setOpacity(id, percent: percent) }
        workspace.undo()
        #expect(workspace.selectedLayer?.opacity == 1)
        #expect(!workspace.canUndo)
    }

    @Test func aNewEditClearsRedo() throws {
        var workspace = try whiteImage(4, 4)
        workspace.adjust(.exposure(1))
        workspace.undo()
        #expect(workspace.canRedo)
        workspace.adjust(.blurSigma(1))
        #expect(!workspace.canRedo && workspace.redoActionName == "Redo")
    }

    @Test func theHistoryKeepsItsLimit() throws {
        var workspace = try whiteImage(4, 4)
        let id = try #require(workspace.selectedLayerID)
        for step in 0..<60 { workspace.renameLayer(id, to: "Name \(step)") }
        var undone = 0
        while workspace.canUndo {
            workspace.undo()
            undone += 1
        }
        #expect(undone == 50)
    }

    @Test func newImageAndOpenStartAFreshHistory() throws {
        var workspace = try whiteImage(4, 4)
        workspace.adjust(.exposure(1))
        try workspace.newCanvas(width: 2, height: 2)
        #expect(!workspace.canUndo && workspace.undoActionName == "Undo")
    }
}
