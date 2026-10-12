// DesignAddNodeTests.swift: DesignWorkspace.addNode. A refused add leaves the
// workspace unchanged, the node id counter included; an accepted add takes the
// next id. Runs on Linux and macOS.
import DesignModel
import Testing

private let box = DesignRect(x: 0, y: 0, width: 10, height: 10)

/// A new file whose Desktop frame (node-1) holds a rectangle (node-2).
private func fileWithRectangle() throws -> DesignWorkspace {
    var workspace = DesignWorkspace()
    workspace.newFile()
    try workspace.addNode(.rectangle, frame: box, in: "node-1")
    return workspace
}

@Test func addIntoUnknownParentChangesNothing() throws {
    var workspace = try fileWithRectangle()
    let before = workspace
    #expect(throws: DesignTreeError.unknownID("nope")) { try workspace.addNode(.ellipse, frame: box, in: "nope") }
    #expect(workspace == before)
}

@Test func addIntoNonContainerChangesNothing() throws {
    var workspace = try fileWithRectangle()
    let before = workspace
    #expect(throws: DesignTreeError.notAContainer("node-2")) {
        try workspace.addNode(.ellipse, frame: box, in: "node-2")
    }
    #expect(workspace == before)
}

@Test func refusedAddsDoNotConsumeNodeIDs() throws {
    var workspace = try fileWithRectangle()
    for _ in 0..<3 { _ = try? workspace.addNode(.ellipse, frame: box, in: "nope") }
    _ = try? workspace.addNode(.ellipse, frame: box, in: "node-2")
    let id = try workspace.addNode(.ellipse, frame: box, in: "node-1")
    #expect(id == "node-3")
    #expect(workspace.selectedNodeID == "node-3")
}

@Test func acceptedAddsTakeSequentialIDsAndSelect() throws {
    var workspace = try fileWithRectangle()
    let group = try workspace.addNode(.group, frame: box)
    let child = try workspace.addNode(.text, frame: box, in: group)
    #expect((group, child) == ("node-3", "node-4"))
    #expect(workspace.selectedNodeID == child)
    #expect(workspace.expandedNodeIDs.contains(group))
    #expect(workspace.layerRows.map(\.node.id) == ["node-1", "node-2", "node-3", "node-4"])
}
