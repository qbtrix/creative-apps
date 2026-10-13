// DesignCollapseSelectionTests.swift: collapsing a Layers row that encloses
// the selection selects that row (#121), so the selection never hides inside
// a collapsed row. Runs on Linux and macOS.
import DesignModel
import Testing

/// Desktop (node-1) > group (node-2) > inner group (node-3) > rectangle (node-4); a sibling ellipse (node-5).
private func nested() throws -> DesignWorkspace {
    var workspace = openDesign()
    try workspace.addNode(.group, frame: rc(10, 10, 300, 300), in: "node-1")
    try workspace.addNode(.group, frame: rc(20, 20, 200, 200), in: "node-2")
    try workspace.addNode(.rectangle, frame: rc(30, 30, 50, 50), in: "node-3")
    try workspace.addNode(.ellipse, frame: rc(400, 400, 50, 50), in: "node-1")
    return workspace
}

@Test func collapsingTheParentOfTheSelectedLayerSelectsTheParent() throws {
    var workspace = try nested()
    workspace.selectItem("node-4")
    #expect(workspace.layerRows.map(\.id).contains("node-4"))
    try workspace.setExpanded("node-3", false)
    #expect(workspace.selectedNodeID == "node-3")
    #expect(!workspace.layerRows.map(\.id).contains("node-4"))
    #expect(workspace.layerRows.map(\.id).contains("node-3"))
}

@Test func collapsingAGrandparentSelectsTheCollapsedRow() throws {
    var workspace = try nested()
    workspace.selectItem("node-4")
    try workspace.toggleExpanded("node-2")
    #expect(workspace.selectedNodeID == "node-2")
    #expect(!workspace.isExpanded("node-2"))
}

@Test func collapsingARowThatDoesNotEncloseTheSelectionKeepsIt() throws {
    var workspace = try nested()
    workspace.selectItem("node-5")
    try workspace.setExpanded("node-2", false)
    #expect(workspace.selectedNodeID == "node-5")
    workspace.deselect()
    try workspace.setExpanded("node-3", false)
    #expect(workspace.selectedNodeID == nil)
}

@Test func collapsingTheSelectedRowItselfKeepsItSelected() throws {
    var workspace = try nested()
    workspace.selectItem("node-3")
    try workspace.setExpanded("node-3", false)
    #expect(workspace.selectedNodeID == "node-3")
}

@Test func expandingNeverChangesTheSelection() throws {
    var workspace = try nested()
    workspace.selectItem("node-4")
    try workspace.setExpanded("node-3", false)
    try workspace.setExpanded("node-3", true)
    #expect(workspace.selectedNodeID == "node-3")
    try workspace.setExpanded("node-1", true)
    #expect(workspace.selectedNodeID == "node-3")
}

@Test func collapsingARowOnAnotherPageLeavesTheSelectionAlone() throws {
    var workspace = try nested()
    workspace.selectItem("node-4")
    workspace.addPage()
    workspace.selectItem("node-4")
    workspace.addPage()
    let before = workspace.selectedNodeID
    try workspace.setExpanded("node-2", false)
    #expect(workspace.selectedNodeID == before)
    #expect(workspace.selectedPageID == "page-3")
}

@Test func theCollapseIsNotAnUndoStep() throws {
    var workspace = try nested()
    workspace.selectItem("node-4")
    let steps = workspace.undoActionName
    try workspace.setExpanded("node-3", false)
    #expect(workspace.undoActionName == steps)
}
