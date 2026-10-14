// GuideDragUndoTests.swift: #628, QB-F3. Each guide drag is its own "Move Guide" step, even when the previous drag
// ended where it started.
import FlareCore
@testable import FlareModel
import Testing

@Test func aGuideDragThatEndsWhereItStartedDoesNotSwallowTheNextDrag() {
    var w = FlareWorkspace(services: .fake())
    w.load(FlareFixtures.bounce)
    w.addGuide(.horizontal, at: 300)
    // Drag 1: out and back to where it began.
    for p in [310.0, 320, 310, 300] { w.moveGuide(at: 0, to: p, dragStart: 300) }
    w.endGuideDrag()
    let afterFirst = w.document
    // Drag 2: a new gesture from the same position.
    for p in [320.0, 340] { w.moveGuide(at: 0, to: p, dragStart: 300) }
    w.endGuideDrag()
    #expect(w.guides.first?.position == 340)

    w.undo()
    #expect(w.document == afterFirst && w.guides.first?.position == 300)
    #expect(w.undoActionName == "Undo Move Guide")
    w.undo()
    #expect(w.guides.first?.position == 300 && w.undoActionName == "Undo Add Guide")
}
