// DesignKnobSeveralTests.swift (transform DT-u, #4224): with several layers selected the rotate knob sits
// above their box, as it sits above one layer's, and a drag from it turns every selected layer by the same
// angle about its own centre, one Rotate step, Shift snapping the sweep to 15°. The expected spots are worked
// out here by hand. Plans: Tests/mutations/DesignModel.DesignCanvasEditing.json and
// DesignModel.DesignCanvasHints.json. Runs on Linux and macOS.
@testable import DesignModel
import Testing

@Suite struct DesignKnobSeveralTests {
    /// Desktop (node-1) holding A, 100 × 50 at 100, 100 (node-2), turned `turnA`, and B, 50 × 100 at
    /// 300, 200 (node-3), both selected. Their box runs from 100, 100 to 350, 300, centred on 225, 200,
    /// so its knob sits two handles (2 × 6) above the top's middle, at 225, 88.
    static func pair(turnA: Double = 0) throws -> DesignWorkspace {
        var workspace = openDesign()
        try workspace.addNode(.rectangle, frame: rc(100, 100, 100, 50), in: "node-1")
        try workspace.addNode(.rectangle, frame: rc(300, 200, 50, 100), in: "node-1")
        workspace.selectItem("node-2")
        if turnA != 0 { workspace.runTransform(.rotate(by: turnA, drag: nil)) }
        workspace.toggleSelection("node-3")
        return workspace
    }

    static let knob = pt(225, 88)

    @Test func theKnobSitsAboveTheBoxOfSeveral() throws {
        let workspace = try Self.pair()
        #expect(workspace.selectedNodeIDs == ["node-2", "node-3"])
        #expect(workspace.boxHandle(at: Self.knob) == .rotate)
        #expect(workspace.boxHandle(at: pt(229, 84)) == .rotate)
        #expect(workspace.boxHandle(at: pt(225, 100)) == .top)
        #expect(workspace.hover(at: Self.knob, modifiers: []).pointer == .resize(.rotate))
        // Well above the knob it is no handle: the desktop under it takes the hover.
        #expect(workspace.hover(at: pt(225, 60), modifiers: []).pointer != .resize(.rotate))
    }

    @Test func aKnobDragTurnsEachLayerAboutItsOwnCentreInOneStep() throws {
        var workspace = try Self.pair(turnA: 30)
        let earlier = workspace.undoActionName
        workspace.drag(from: Self.knob, to: Self.knob)
        workspace.drag(from: Self.knob, to: pt(300, 120))
        // From straight up off the centre (225, 200) to straight right: a quarter turn clockwise.
        workspace.drag(from: Self.knob, to: pt(337, 200))
        workspace.endDrag()
        let a = try #require(workspace.treeNode("node-2")), b = try #require(workspace.treeNode("node-3"))
        #expect(abs(a.rotation - 120) < 1e-9 && abs(b.rotation - 90) < 1e-9)
        #expect(a.frame == rc(100, 100, 100, 50) && b.frame == rc(300, 200, 50, 100))
        #expect(workspace.selectedNodeIDs == ["node-2", "node-3"])
        #expect(workspace.undoActionName == "Undo Rotate")
        workspace.undo()
        #expect(workspace.treeNode("node-2")?.rotation == 30 && workspace.treeNode("node-3")?.rotation == 0)
        #expect(workspace.undoActionName == earlier)
    }

    @Test func shiftSnapsTheSeveralTurnToFifteenDegrees() throws {
        var workspace = try Self.pair()
        // From straight up to (265, 100): about 21.8° clockwise about (225, 200), 15° with Shift.
        workspace.drag(from: Self.knob, to: pt(265, 100), modifiers: .shift)
        #expect(workspace.treeNode("node-2")?.rotation == 15 && workspace.treeNode("node-3")?.rotation == 15)
        workspace.drag(from: Self.knob, to: pt(265, 100))
        let free = try #require(workspace.treeNode("node-3")?.rotation)
        #expect(abs(free - 21.801409) < 1e-5)
        workspace.endDrag()
    }

    @Test func aLockedLayerInTheSelectionTurnsNothing() throws {
        var workspace = try Self.pair()
        try workspace.setNodeLocked("node-3", true)
        try #require(workspace.selectedNodeIDs == ["node-2", "node-3"] && workspace.transformHelp != nil)
        workspace.drag(from: Self.knob, to: pt(337, 200))
        workspace.endDrag()
        #expect(workspace.treeNode("node-2")?.rotation == 0 && workspace.treeNode("node-3")?.rotation == 0)
    }
}
