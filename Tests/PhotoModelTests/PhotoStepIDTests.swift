// PhotoStepIDTests.swift: history step ids (S-6b, #812). Every recorded step
// gets an id that never repeats, `currentStepID` names the step the image is
// at (the base after a trim), `isDirty` compares it with the step last saved,
// opened or created, a selection change undoes as one step, and layer-list
// undo works beside an adjustment layer, which has no pixels. Linux-safe.
import CoreRaster
import Testing

@testable import PhotoModel

@Suite struct PhotoStepIDTests {
    @Test func editUndoEditGivesAnIDNeverSeenBefore() throws {
        var workspace = try whiteImage()
        let background = try #require(workspace.selectedLayerID)
        var seen: Set<Int> = [workspace.currentStepID]
        workspace.toggleVisibility(background)
        seen.insert(workspace.currentStepID)
        workspace.undo()
        #expect(workspace.currentStepID == 0)
        workspace.toggleVisibility(background)
        #expect(!seen.contains(workspace.currentStepID))
    }

    @Test func undoingEverythingAfterATrimReadsAsTheTrimmedBase() throws {
        var workspace = try whiteImage()
        let background = try #require(workspace.selectedLayerID)
        for _ in 0...PhotoHistory.limit { workspace.toggleVisibility(background) }
        for _ in 0..<PhotoHistory.limit { workspace.undo() }
        #expect(!workspace.canUndo)
        #expect(workspace.currentStepID != 0)
        #expect(workspace.isDirty)
    }

    @Test func redoComesBackToTheSameStep() throws {
        var workspace = try whiteImage()
        let background = try #require(workspace.selectedLayerID)
        workspace.toggleVisibility(background)
        let edited = workspace.currentStepID
        workspace.undo()
        workspace.redo()
        #expect(workspace.currentStepID == edited)
    }

    @Test func aNewOrOpenedImageIsCleanAndAnEditIsDirtyUntilUndone() throws {
        #expect(!PhotoWorkspace().isDirty)
        var workspace = try whiteImage()
        #expect(!workspace.isDirty)
        let background = try #require(workspace.selectedLayerID)
        workspace.toggleVisibility(background)
        #expect(workspace.isDirty)
        workspace.undo()
        #expect(!workspace.isDirty)
        workspace.toggleVisibility(background)
        try workspace.open(rgba8: [UInt8](repeating: 255, count: 16), width: 2, height: 2, name: "a.png")
        #expect(!workspace.isDirty)
    }

    @Test func aCoalescedChangeIsANewStep() throws {
        var workspace = try whiteImage()
        let background = try #require(workspace.selectedLayerID)
        workspace.setOpacity(background, percent: 80)
        let first = workspace.currentStepID
        workspace.setOpacity(background, percent: 60)
        #expect(workspace.historySteps.count == 2)
        #expect(workspace.currentStepID != first)
    }

    @Test func aSelectionStepUndoesTheSelection() throws {
        var workspace = try whiteImage(8, 8)
        let mask = try Mask(width: 8, height: 8, fill: 0.5)
        workspace.record(.selection(workspace.selection, workspace.selectionMask), named: "Select")
        workspace.selectAll()
        workspace.selectionMask = mask
        workspace.undo()
        #expect(workspace.selection == nil)
        #expect(workspace.selectionMask == nil)
        workspace.redo()
        #expect(workspace.selection == PixelRect(x: 0, y: 0, width: 8, height: 8))
        #expect(workspace.selectionMask == mask)
    }

    @Test func aMaskTilesStepPutsTheMaskBack() throws {
        var workspace = try whiteImage(8, 8)
        let id = try #require(workspace.selectedLayerID)
        let before = try TiledPixels(width: 8, height: 8, fill: RGBA(r: 1, g: 1, b: 1, a: 1))
        var after = before
        try after.tiles[0].setPixel(x: 0, y: 0, RGBA(r: 0, g: 0, b: 0, a: 1))
        workspace.masks[id] = after
        workspace.record(.maskTiles(layer: id, [0: before.tiles[0]]), named: "Paint Mask")
        workspace.undo()
        #expect(workspace.masks[id] == before)
        workspace.redo()
        #expect(workspace.masks[id] == after)
    }

    @Test func layerListUndoWorksBesideAnAdjustmentLayer() throws {
        var workspace = try whiteImage()
        let background = try #require(workspace.selectedLayerID)
        let curves = workspace.insertLayer(
            named: "Curves 1", pixels: nil, kind: .adjustment(AdjustmentSettings()), at: 0)
        #expect(workspace.pixels[curves] == nil)
        workspace.toggleVisibility(background)
        #expect(workspace.layers.first { $0.id == background }?.isVisible == false)
        workspace.undo()
        #expect(workspace.layers.first { $0.id == background }?.isVisible == true)
    }

    @Test func wholeStackStepsRestoreMasks() throws {
        var workspace = try whiteImage(8, 8)
        let id = try #require(workspace.selectedLayerID)
        let mask = try TiledPixels(width: 8, height: 8, fill: RGBA(r: 1, g: 1, b: 1, a: 1))
        workspace.masks[id] = mask
        workspace.addLayer()
        workspace.masks = [:]
        workspace.undo()
        #expect(workspace.masks[id] == mask)
    }
}
