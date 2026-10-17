// FlarePenFinishTests.swift: Return finishes an open pen path (packet draw-key-save, DK-9). Two pen clicks then
// `finishPath` add one open "Path 1" layer as one "Undo Add Path" step; one anchor refuses and changes nothing; with no
// draft it is a no-op. Runs on Linux and macOS.
import FlareCore
import FlareModel
import Testing

@Suite struct FlarePenFinishTests {
    private func penWorkspace(clicks: [(Double, Double)]) -> FlareWorkspace {
        var workspace = FlareWorkspace(services: .fake())
        workspace.newDocument()
        workspace.selectTool(.pen)
        for (x, y) in clicks { workspace.drag(from: Point(x: x, y: y), to: Point(x: x, y: y)) }
        return workspace
    }

    @Test func twoClicksThenFinishAddOneOpenPathAsOneUndoStep() throws {
        var workspace = penWorkspace(clicks: [(20, 20), (120, 80)])
        #expect(workspace.layers.isEmpty && !workspace.canUndo && workspace.finishPathHelp == nil)
        workspace.finishPath()
        let layer = try #require(workspace.layers.first)
        #expect(workspace.layers.count == 1 && layer.name == "Path 1")
        let shape = try #require(layer.shapes.first)
        #expect(!shape.closed && shape.points == [Point(x: 20, y: 20), Point(x: 120, y: 80)])
        #expect(workspace.draft == nil && workspace.layerError == nil && workspace.selectedLayerID == layer.id)
        #expect(workspace.undoActionName == "Undo Add Path")
        workspace.undo()
        #expect(workspace.layers.isEmpty && !workspace.canUndo && workspace.redoActionName == "Redo Add Path")
    }

    @Test func oneAnchorRefusesAndChangesNothing() {
        var workspace = penWorkspace(clicks: [(20, 20)])
        let before = workspace
        #expect(workspace.finishPathHelp == "Click a second point to finish the path.")
        workspace.finishPath()
        #expect(workspace == before)
        #expect(workspace.layers.isEmpty && !workspace.canUndo && workspace.draft?.anchors == [Point(x: 20, y: 20)])
    }

    @Test func noDraftIsANoOp() {
        var workspace = penWorkspace(clicks: [])
        let before = workspace
        #expect(workspace.finishPathHelp == "Click with the Pen to start a path.")
        workspace.finishPath()
        #expect(workspace == before && workspace.layers.isEmpty && !workspace.canUndo)
    }

    @Test func aClosedPathIsCommittedByItsClickNotFinishedAgain() {
        var workspace = penWorkspace(clicks: [(0, 0), (100, 0), (100, 100), (0, 0)])
        #expect(workspace.layers.count == 1 && workspace.draft == nil)
        let before = workspace
        workspace.finishPath()
        #expect(workspace == before)
    }
}
