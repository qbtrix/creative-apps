// DesignHiddenGroupResizeTests.swift: a hidden group hides its whole subtree from
// the pointer too (#449). The canvas draws no outline or handles for a selected
// layer inside a hidden group, so a press where a handle would sit is a press on
// blank canvas: no resize and no undo step. Runs on Linux and macOS.
import DesignModel
import Testing

/// A hidden group (node-2) over the Desktop frame's right edge holding a selected rectangle (node-3)
/// whose bottom-right handle sits at (1470, 170), on blank canvas.
private func hiddenGroup() throws -> DesignWorkspace {
    var workspace = openDesign()
    try workspace.addNode(.group, frame: rc(1400, 100, 300, 200), in: "node-1")
    try workspace.addNode(.rectangle, frame: rc(1420, 130, 50, 40), in: "node-2")
    try workspace.setNodeHidden("node-2", true)
    workspace.selectItem("node-3")
    return workspace
}

@Test func aLayerInsideAHiddenGroupShowsNoHandle() throws {
    let workspace = try hiddenGroup()
    #expect(workspace.isHiddenInTree("node-3"))
    #expect(workspace.handle(at: DesignPoint(x: 1470, y: 170)) == nil)
}

@Test func aPressOnAHiddenLayersHandleIsABlankCanvasPress() throws {
    var workspace = try hiddenGroup()
    let undoName = workspace.undoActionName
    workspace.gesture(.move, DesignPoint(x: 1470, y: 170), DesignPoint(x: 1510, y: 210))
    #expect(workspace.frame("node-3") == rc(1420, 130, 50, 40))
    #expect(workspace.undoActionName == undoName)
    #expect(workspace.selectedNodeID == nil)
}

@Test func showingTheGroupBringsTheHandleBack() throws {
    var workspace = try hiddenGroup()
    try workspace.setNodeHidden("node-2", false)
    workspace.selectItem("node-3")
    #expect(workspace.handle(at: DesignPoint(x: 1470, y: 170)) == .bottomRight)
}
