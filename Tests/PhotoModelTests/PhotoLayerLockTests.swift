// PhotoLayerLockTests.swift: a Photo layer can be locked. Lock and unlock
// are one undo step each ("Lock Layer", "Unlock Layer"); the kernel rows read
// the lock; a locked layer refuses paint, a move, Fill, Delete and Cut with
// the same reason on the status line, and the edits that ask first say it;
// `layer.toggle-lock` runs it through the catalog, titled by the layer's
// state; the archive keeps it. Linux-safe.
import CoreRaster
import SuiteKernel
import Testing
@testable import PhotoModel

struct PhotoLayerLockTests {
    private func locked() throws -> (PhotoWorkspace, PhotoLayer.ID) {
        var model = PhotoWorkspace()
        try model.newCanvas(width: 64, height: 64)
        let id = try #require(model.selectedLayerID)
        model.toggleLock(id)
        return (model, id)
    }

    @Test func lockIsOneStepTheRowsRead() throws {
        var (model, id) = try locked()
        #expect(model.layers.first?.isLocked == true && model.layerRows.first?.isLocked == true)
        #expect(model.menuTitle("layer.toggle-lock") == "Unlock Layer")
        #expect(model.undoActionName == "Undo Lock Layer")
        model.undo()
        #expect(model.layers.first?.isLocked == false && model.menuTitle("layer.toggle-lock") == "Lock Layer")
        model.redo()
        model.toggleLock(id)
        #expect(model.undoActionName == "Undo Unlock Layer" && model.layers.first?.isLocked == false)
    }

    @Test func aLockedLayerRefusesEdits() throws {
        var (model, _) = try locked()
        let before = model.layers, steps = model.historySteps
        for tool in [PhotoTool.brush, .eraser, .move] {
            model.selectTool(tool)
            model.drag(from: Mask.Point(x: 4, y: 4), to: Mask.Point(x: 40, y: 40))
            model.endDrag()
            #expect(model.layers == before && model.historySteps == steps, "\(tool) changed a locked layer")
            #expect(model.statusMessage == PhotoWorkspace.lockedRefusal, "\(tool)")
        }
        model.selectAll()
        #expect(PhotoWorkspace.catalog.availability("edit.fill-selection", on: model).why == PhotoWorkspace.lockedRefusal)
        model.fillSelection()
        model.deleteSelection()
        #expect(model.cutSelection() == nil)
        #expect(model.layers == before && model.historySteps == steps)
    }

    @Test func toggleLockRunsThroughTheCatalog() throws {
        var model = PhotoWorkspace()
        try model.newCanvas(width: 64, height: 64)
        #expect(PhotoWorkspace.catalog.spec("layer.toggle-lock")?.title == "Lock Layer")
        _ = try PhotoWorkspace.catalog.run("layer.toggle-lock", params: .object([:]), on: &model)
        #expect(model.selectedLayer?.isLocked == true)
    }

    @Test func theArchiveKeepsTheLock() throws {
        let (model, _) = try locked()
        let layer = try #require(model.layers.first)
        #expect(LayerEntry(layer, src: nil, mask: nil).layer.isLocked)
        var open = layer
        open.isLocked = false
        #expect(LayerEntry(open, src: nil, mask: nil).locked == nil)
    }
}
