// DesignHiddenNudgeTests.swift: the arrow keys don't move a layer that is hidden or sits inside
// a hidden group (#607), as a press on its handles doesn't (#449, #604): its frame stays and no
// "Nudge" step records. Runs on Linux and macOS.
import DesignModel
import Testing

/// #607's setup: a hidden group (node-2) in Desktop holding a rectangle (node-3), selected as
/// from the Layers list.
private func hiddenGroup() throws -> DesignWorkspace {
    var w = openDesign()
    try w.addNode(.group, frame: rc(1400, 100, 300, 200), in: "node-1")
    try w.addNode(.rectangle, frame: rc(1420, 130, 50, 40), in: "node-2")
    try w.setNodeHidden("node-2", true)
    w.selectItem("node-3")
    return w
}

@Test func anArrowKeyLeavesALayerInAHiddenGroupWhereItIs() throws {
    var w = try hiddenGroup()
    w.nudge(.right, shift: true)
    #expect(w.frame("node-3") == rc(1420, 130, 50, 40))
    #expect(w.undoActionName == "Undo Hide Layer")
}

@Test func anArrowKeyLeavesAHiddenLayerWhereItIs() throws {
    var w = openDesign()
    try w.addNode(.rectangle, frame: rc(20, 30, 50, 40), in: "node-1")
    try w.setNodeHidden("node-2", true)
    w.selectItem("node-2")
    w.nudge(.down, shift: false)
    #expect(w.frame("node-2") == rc(20, 30, 50, 40))
    #expect(w.undoActionName == "Undo Hide Layer")
}

@Test func theNudgeCommandOnAHiddenLayerSaysWhyAndRefuses() throws {
    var w = try hiddenGroup()
    #expect(w.help(.nudge(.left, large: false)) == "Show Rectangle to change it.")
    #expect(throws: DesignRefusal.hidden("Rectangle")) { try w.run(.nudge(.left, large: false)) }
    #expect(w.frame("node-3") == rc(1420, 130, 50, 40))
}

@Test func showingTheGroupLetsTheArrowKeysMoveItAgain() throws {
    var w = try hiddenGroup()
    try w.setNodeHidden("node-2", false)
    w.selectItem("node-3")
    w.nudge(.right, shift: false)
    #expect(w.frame("node-3") == rc(1421, 130, 50, 40))
    #expect(w.undoActionName == "Undo Nudge")
}
