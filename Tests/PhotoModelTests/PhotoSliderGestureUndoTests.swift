// PhotoSliderGestureUndoTests.swift: each slider gesture is its own undo step
// (#539). The inspector's bar sliders send endAdjust when a drag, key step or
// typed value ends; a run of edits to one layer's opacity coalesces until then.
// (Adjustment runs are covered by PhotoCurvesTests.) Linux-safe.
import PhotoModel
import Testing

@Suite struct PhotoSliderGestureUndoTests {
    private func workspace() throws -> (PhotoWorkspace, PhotoLayer.ID) {
        var workspace = PhotoWorkspace()
        try workspace.newCanvas(width: 8, height: 8)
        return (workspace, try #require(workspace.selectedLayerID))
    }

    private func opacity(_ workspace: PhotoWorkspace, _ id: PhotoLayer.ID) -> Double? {
        workspace.layers.first { $0.id == id }?.opacityPercent
    }

    @Test func eachOpacityDragIsItsOwnUndoStep() throws {
        var (workspace, id) = try workspace()
        workspace.setOpacity(id, percent: 80)
        workspace.setOpacity(id, percent: 60)
        workspace.endAdjust()
        workspace.setOpacity(id, percent: 40)
        workspace.endAdjust()
        workspace.undo()
        #expect(opacity(workspace, id) == 60)
        #expect(workspace.undoActionName == "Undo Layer Opacity")
        workspace.undo()
        #expect(opacity(workspace, id) == 100)
    }

    @Test func oneDragWithoutAnEndIsStillOneStep() throws {
        var (workspace, id) = try workspace()
        workspace.setOpacity(id, percent: 80)
        workspace.setOpacity(id, percent: 40)
        workspace.undo()
        #expect(opacity(workspace, id) == 100)
        #expect(workspace.undoActionName == "Undo")
    }
}
