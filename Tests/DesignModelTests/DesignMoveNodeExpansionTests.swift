// DesignMoveNodeExpansionTests.swift: moveNode expands every collapsed row that
// encloses the moved node, so a selected node always keeps a Layers row.
// Runs on Linux and macOS.
import DesignModel
import Testing

private let box = DesignRect(x: 0, y: 0, width: 10, height: 10)

/// A new file whose Desktop frame (node-1) holds a group (node-2) holding a group (node-3),
/// plus a top-level rectangle (node-4) that is selected.
private func fileWithNestedGroupsAndLooseNode() throws -> DesignWorkspace {
    var workspace = DesignWorkspace()
    workspace.newFile()
    try workspace.addNode(.group, frame: box, in: "node-1")
    try workspace.addNode(.group, frame: box, in: "node-2")
    try workspace.addNode(.rectangle, frame: box)
    return workspace
}

@Test func moveUnderCollapsedNestedContainerExpandsEveryAncestor() throws {
    var workspace = try fileWithNestedGroupsAndLooseNode()
    for id in ["node-1", "node-2", "node-3"] { try workspace.setExpanded(id, false) }
    try workspace.moveNode("node-4", into: "node-3")
    #expect(workspace.selectedNodeID == "node-4")
    #expect(workspace.isExpanded("node-1"))
    #expect(workspace.isExpanded("node-2"))
    #expect(workspace.isExpanded("node-3"))
    #expect(workspace.layerRows.contains { $0.id == "node-4" })
}

@Test func moveUnderCollapsedGrandparentOnlyExpandsTheChain() throws {
    var workspace = try fileWithNestedGroupsAndLooseNode()
    let sibling = try workspace.addNode(.group, frame: box, in: "node-1")
    workspace.selectItem("node-4")
    for id in ["node-1", "node-3", sibling] { try workspace.setExpanded(id, false) }
    try workspace.moveNode("node-4", into: "node-2")
    #expect(workspace.isExpanded("node-1"))
    #expect(workspace.isExpanded("node-2"))
    #expect(!workspace.isExpanded("node-3"))
    #expect(!workspace.isExpanded(sibling))
    #expect(!workspace.isExpanded("node-4"))
    #expect(workspace.layerRows.contains { $0.id == "node-4" })
}

@Test func moveToTopLevelExpandsNothing() throws {
    var workspace = try fileWithNestedGroupsAndLooseNode()
    try workspace.moveNode("node-3", into: "node-1")
    try workspace.setExpanded("node-1", false)
    try workspace.setExpanded("node-2", false)
    try workspace.moveNode("node-3", into: nil)
    #expect(!workspace.isExpanded("node-1"))
    #expect(!workspace.isExpanded("node-2"))
    #expect(workspace.layerRows.contains { $0.id == "node-3" })
}

@Test func refusedMoveExpandsNothing() throws {
    var workspace = try fileWithNestedGroupsAndLooseNode()
    for id in ["node-1", "node-2", "node-3"] { try workspace.setExpanded(id, false) }
    #expect(throws: DesignTreeError.self) { try workspace.moveNode("node-1", into: "node-3") }
    #expect(!workspace.isExpanded("node-1"))
    #expect(!workspace.isExpanded("node-2"))
    #expect(!workspace.isExpanded("node-3"))
}
