// DesignUndoGestureAvailabilityTests.swift: canUndo and canRedo agree with whether
// Undo and Redo actually run (#442). Mid-drag both are ignored, so the Edit menu
// must not offer them. Runs on Linux and macOS.
import DesignModel
import Testing

/// A workspace with one rectangle at (10, 10, 40, 40), one undone edit on Redo
/// and one done edit on Undo, the rectangle selected and the Move tool on.
private func editedWorkspace() throws -> (DesignWorkspace, String) {
    var workspace = openDesign()
    let rect = try workspace.addNode(.rectangle, frame: rc(10, 10, 40, 40))
    try workspace.addNode(.rectangle, frame: rc(200, 200, 20, 20))
    workspace.undo()
    workspace.selectItem(rect)
    workspace.selectTool(.move)
    return (workspace, rect)
}

@Test func anOpenMoveDragDisablesUndoAndRedo() throws {
    var (workspace, rect) = try editedWorkspace()
    #expect(workspace.canUndo && workspace.canRedo)
    workspace.drag(from: pt(30, 30), to: pt(60, 60))
    #expect(workspace.frame(rect) == rc(40, 40, 40, 40))
    #expect(!workspace.canUndo, "Undo is ignored mid-drag")
    #expect(!workspace.canRedo, "Redo is ignored mid-drag")
    workspace.endDrag()
    #expect(workspace.canUndo && !workspace.canRedo, "the finished move is undoable and cleared Redo")
}

@Test func anOpenResizeDragDisablesUndoAndRedo() throws {
    var (workspace, rect) = try editedWorkspace()
    workspace.drag(from: pt(50, 50), to: pt(70, 70))
    #expect(workspace.frame(rect) == rc(10, 10, 60, 60))
    #expect(!workspace.canUndo && !workspace.canRedo)
    workspace.endDrag()
    #expect(workspace.undoActionName == "Undo Resize" && workspace.canUndo)
}

@Test func aDragThatChangesNothingGivesUndoAndRedoBack() throws {
    var (workspace, _) = try editedWorkspace()
    workspace.drag(from: pt(30, 30), to: pt(30, 30))
    #expect(!workspace.canUndo && !workspace.canRedo)
    workspace.endDrag()
    #expect(workspace.canUndo && workspace.canRedo)
}
