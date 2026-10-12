// DesignAddNodeExpansionTests.swift: addNode expands every collapsed row that
// encloses the new node, so the selected node always has a Layers row.
// Runs on Linux and macOS.
import DesignModel
import Testing

private let box = DesignRect(x: 0, y: 0, width: 10, height: 10)

/// A new file whose Desktop frame (node-1) holds a group (node-2) holding a group (node-3).
private func fileWithNestedGroups() throws -> DesignWorkspace {
    var workspace = DesignWorkspace()
    workspace.newFile()
    try workspace.addNode(.group, frame: box, in: "node-1")
    try workspace.addNode(.group, frame: box, in: "node-2")
    return workspace
}

@Test func addUnderCollapsedNestedContainerExpandsEveryAncestor() throws {
    var workspace = try fileWithNestedGroups()
    for id in ["node-1", "node-2", "node-3"] { try workspace.setExpanded(id, false) }
    let added = try workspace.addNode(.rectangle, frame: box, in: "node-3")
    #expect(workspace.selectedNodeID == added)
    #expect(workspace.isExpanded("node-1"))
    #expect(workspace.isExpanded("node-2"))
    #expect(workspace.isExpanded("node-3"))
    #expect(workspace.layerRows.contains { $0.id == added })
}

@Test func addUnderCollapsedGrandparentOnlyExpandsTheChain() throws {
    var workspace = try fileWithNestedGroups()
    let sibling = try workspace.addNode(.group, frame: box, in: "node-1")
    try workspace.setExpanded(sibling, false)
    try workspace.setExpanded("node-1", false)
    let added = try workspace.addNode(.ellipse, frame: box, in: "node-2")
    #expect(workspace.isExpanded("node-1"))
    #expect(workspace.isExpanded("node-2"))
    #expect(!workspace.isExpanded(sibling))
    #expect(!workspace.isExpanded(added))
    #expect(workspace.layerRows.contains { $0.id == added })
}

@Test func addAtTopLevelExpandsNothing() throws {
    var workspace = try fileWithNestedGroups()
    try workspace.setExpanded("node-1", false)
    let added = try workspace.addNode(.text, frame: box)
    #expect(!workspace.isExpanded("node-1"))
    #expect(workspace.layerRows.contains { $0.id == added })
}
