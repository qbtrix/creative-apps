// FlareKernelUndoAdapterTests.swift (adopt-kernel-undo AU-f1): FlareWorkspace reads as SuiteKernel's HistoryReading
// over FlareCore's CommandEngine, so the shared Edit menu reads one protocol: step names without the "Undo "/"Redo "
// prefix, nothing to undo before a document opens, and one step per gesture.
import FlareCore
@testable import FlareModel
import SuiteKernel
import Testing

private func bounce() -> FlareWorkspace {
    var workspace = FlareWorkspace(services: .fake())
    workspace.load(FlareFixtures.bounce)
    return workspace
}

private func reading(_ history: some HistoryReading) -> (Bool, Bool, String?, String?) {
    (history.canUndo, history.canRedo, history.undoName, history.redoName)
}

@Test func aWorkspaceWithNoDocumentHasNothingToUndoOrRedo() {
    var w = FlareWorkspace(services: .fake())
    #expect(reading(w) == (false, false, nil, nil) && !w.isDirty)
    w.undo()
    w.redo()
    #expect(reading(w) == (false, false, nil, nil) && w.document == nil)
}

@Test func stepNamesComeWithoutTheMenuPrefix() {
    var w = bounce()
    #expect(reading(w) == (false, false, nil, nil))
    w.addScene()
    #expect(reading(w) == (true, false, "Add Scene", nil) && w.isDirty)
    w.undo()
    #expect(reading(w) == (false, true, nil, "Add Scene"))
    w.redo()
    #expect(reading(w) == (true, false, "Add Scene", nil))
}

@Test func theMenuTitlesAreTheProtocolNamesWithTheirPrefix() {
    var w = bounce()
    w.addScene()
    #expect(w.undoActionName == "Undo Add Scene" && w.redoActionName == nil)
    w.undo()
    #expect(w.undoActionName == nil && w.redoActionName == "Redo Add Scene")
}

@Test func endingAGestureEndsItsRunSoTheNextGestureIsItsOwnStep() {
    var w = bounce()
    w.addGuide(.horizontal, at: 300)
    for p in [310.0, 320] { w.moveGuide(at: 0, to: p, dragStart: 300) }
    w.endGuideDrag()
    for p in [330.0, 340] { w.moveGuide(at: 0, to: p, dragStart: 300) }
    w.endGuideDrag()
    w.undo()
    #expect(w.guides.first?.position == 320 && reading(w) == (true, true, "Move Guide", "Move Guide"))
    w.undo()
    #expect(w.guides.first?.position == 300 && w.undoName == "Add Guide")
}
