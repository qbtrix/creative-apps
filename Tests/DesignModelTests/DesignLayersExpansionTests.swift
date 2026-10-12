// DesignLayersExpansionTests.swift: Layers rows follow the expanded set both
// ways: setExpanded and toggleExpanded grow and shrink it, and selecting a
// nested node expands its ancestors. Runs on Linux and macOS.
import DesignModel
import Testing

private let box = DesignRect(x: 0, y: 0, width: 10, height: 10)

/// A file whose Desktop frame (node-1) holds a group (node-2) holding a rectangle (node-3).
private func nestedFile() throws -> DesignWorkspace {
    var workspace = DesignWorkspace()
    workspace.newFile()
    let group = try workspace.addNode(.group, frame: box, in: "node-1")
    try workspace.addNode(.rectangle, frame: box, in: group)
    return workspace
}

@Test func aContainerCollapsesAndExpandsAgain() throws {
    var workspace = DesignWorkspace()
    workspace.newFile()
    try workspace.addNode(.rectangle, frame: box, in: "node-1")
    #expect(workspace.layerRows.map(\.id) == ["node-1", "node-2"])

    try workspace.setExpanded("node-1", false)
    #expect(workspace.layerRows.map(\.id) == ["node-1"])
    #expect(!workspace.isExpanded("node-1"))

    try workspace.setExpanded("node-1", true)
    #expect(workspace.layerRows.map(\.id) == ["node-1", "node-2"])
    #expect(workspace.layerRows.map(\.depth) == [0, 1])
}

@Test func toggleExpandedFlipsOneRow() throws {
    var workspace = try nestedFile()
    #expect(workspace.layerRows.map(\.id) == ["node-1", "node-2", "node-3"])

    try workspace.toggleExpanded("node-2")
    #expect(workspace.layerRows.map(\.id) == ["node-1", "node-2"])
    try workspace.toggleExpanded("node-1")
    #expect(workspace.layerRows.map(\.id) == ["node-1"])

    // Re-expanding the frame shows the group still collapsed.
    try workspace.toggleExpanded("node-1")
    #expect(workspace.layerRows.map(\.id) == ["node-1", "node-2"])
    try workspace.toggleExpanded("node-2")
    #expect(workspace.layerRows.map(\.id) == ["node-1", "node-2", "node-3"])
}

@Test func expandingIsIdempotent() throws {
    var workspace = try nestedFile()
    try workspace.setExpanded("node-2", true)
    #expect(workspace.layerRows.count == 3)
    try workspace.setExpanded("node-2", false)
    try workspace.setExpanded("node-2", false)
    #expect(workspace.layerRows.count == 2)
}

@Test func expandingAnUnknownIDIsRefused() throws {
    var workspace = try nestedFile()
    let before = workspace
    #expect(throws: DesignTreeError.unknownID("missing")) { try workspace.setExpanded("missing", false) }
    #expect(throws: DesignTreeError.unknownID("page-1")) { try workspace.toggleExpanded("page-1") }
    #expect(workspace == before)

    var empty = DesignWorkspace()
    #expect(throws: DesignTreeError.unknownID("node-1")) { try empty.setExpanded("node-1", true) }
}

@Test func selectingANestedNodeRevealsItsRow() throws {
    var workspace = try nestedFile()
    try workspace.setExpanded("node-2", false)
    try workspace.setExpanded("node-1", false)
    #expect(workspace.layerRows.map(\.id) == ["node-1"])

    workspace.selectItem("node-3")
    #expect(workspace.selectedNodeID == "node-3")
    #expect(workspace.layerRows.map(\.id) == ["node-1", "node-2", "node-3"])
    // The selected node itself stays collapsed-or-not as it was; only its ancestors open.
    #expect(!workspace.isExpanded("node-3"))
}

@Test func selectingATopLevelNodeExpandsNothing() throws {
    var workspace = try nestedFile()
    try workspace.setExpanded("node-1", false)
    workspace.selectItem("node-1")
    #expect(workspace.layerRows.map(\.id) == ["node-1"])
}
