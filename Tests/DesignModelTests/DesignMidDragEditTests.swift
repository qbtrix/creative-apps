// DesignMidDragEditTests.swift: no edit or step while a canvas gesture is live (#542). Each
// pointer move rewinds to the gesture's start, so an edit that landed between two moves used to
// vanish while its undo step stayed. Now Delete, the arrow keys, `run` and the inspector's
// `setStyle` do nothing mid-gesture, like Undo and Redo, and the gesture's own service steps still
// apply. Runs on Linux and macOS.
@testable import DesignModel
import Testing

@Suite struct DesignMidDragEditTests {
    /// #542's repro with `edit` in place of the delete: a rectangle in Desktop, a Move drag that
    /// runs `edit` after its first pointer move, then two undos.
    func moveWith(_ edit: (inout DesignWorkspace) -> Void) throws {
        var w = openDesign()
        let r = try w.addNode(.rectangle, frame: rc(10, 10, 40, 40), in: "node-1")
        w.selectTool(.move)
        w.drag(from: pt(20, 20), to: pt(30, 30))
        let mid = w.history
        edit(&w)
        #expect(w.history == mid)
        w.drag(from: pt(20, 20), to: pt(40, 40))
        w.endDrag()
        #expect(w.frame(r) == rc(30, 30, 40, 40))
        #expect(w.undoActionName == "Undo Move")
        w.undo()
        #expect(w.frame(r) == rc(10, 10, 40, 40))
        #expect(w.undoActionName == "Undo Add Rectangle")
        w.undo()
        #expect(w.treeNode(r) == nil)
    }

    @Test func aDeleteMidMoveLeavesNoStep() throws {
        try moveWith { $0.deleteSelection() }
    }

    @Test func aNudgeMidMoveLeavesNoStep() throws {
        try moveWith { $0.nudge(.right, shift: true) }
    }

    @Test func anAlignMidMoveLeavesNoStep() throws {
        try moveWith { w in #expect(throws: DesignRefusal.unchanged) { try w.run(.align(.left)) } }
    }

    @Test func anInspectorFrameEditMidMoveLeavesNoStep() throws {
        try moveWith { w in #expect(throws: DesignRefusal.unchanged) { try w.setStyle(.frame(.x, 5)) } }
    }

    @Test func aCutOrAMoveLayerMidMoveLeavesNoStep() throws {
        try moveWith { w in #expect(throws: DesignRefusal.unchanged) { _ = try w.cutSelection() } }
        try moveWith { w in #expect(throws: DesignRefusal.unchanged) { try w.moveLayer("node-2", into: nil, at: 0) } }
    }

    @Test func aDeleteANudgeAndACutMidDragOfSeveralLeaveTheirMoveWorking() {
        var w = DesignGestureRouteTests.aAndB()
        w.drag(from: pt(150, 140), to: pt(160, 140))
        w.deleteSelection()
        w.nudge(.down, shift: false)
        #expect(throws: DesignRefusal.unchanged) { try w.run(.delete) }
        #expect(throws: DesignRefusal.unchanged) { _ = try w.cutSelection() }
        w.drag(from: pt(150, 140), to: pt(190, 140))
        w.endDrag()
        #expect(w.frame("node-2") == rc(140, 100, 100, 80))
        #expect(w.frame("node-3") == rc(340, 140, 200, 80))
        #expect(w.history.undo.count == 1)
        #expect(w.undoActionName == "Undo Move")
    }

    @Test func afterTheGestureTheSameEditsRecordAgain() throws {
        var w = openDesign()
        let r = try w.addNode(.rectangle, frame: rc(10, 10, 40, 40), in: "node-1")
        w.gesture(.move, pt(20, 20), pt(30, 30))
        w.nudge(.right, shift: false)
        #expect(w.undoActionName == "Undo Nudge")
        try w.setStyle(.frame(.x, 5))
        #expect(w.frame(r)?.x == 5)
        w.deleteSelection()
        #expect(w.undoActionName == "Undo Delete Rectangle")
    }
}
