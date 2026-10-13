// DesignTreeEdgeTests.swift: edge cases of the page list and node tree in
// DesignWorkspace: unknown ids, no file open, refused edits that must leave
// the workspace unchanged, deep moves and page deletion. Runs on Linux and macOS.
import DesignModel
import Testing

/// A new file whose Desktop frame (node-1) holds a group (node-2) of a rectangle (node-3) and an ellipse (node-4).
private func sampleFile() throws -> DesignWorkspace {
    var workspace = DesignWorkspace()
    workspace.newFile()
    let box = DesignRect(x: 40, y: 40, width: 200, height: 120)
    let group = try workspace.addNode(.group, frame: box, in: "node-1")
    try workspace.addNode(.rectangle, frame: box, in: group)
    try workspace.addNode(.ellipse, frame: box, in: group)
    return workspace
}

private let box = DesignRect(x: 0, y: 0, width: 10, height: 10)

@Test func editsWithNoFileOpenAreRefused() {
    var workspace = DesignWorkspace()
    #expect(throws: DesignTreeError.unknownID("")) { try workspace.addNode(.rectangle, frame: box) }
    #expect(throws: DesignTreeError.unknownID("page-1")) { try workspace.deletePage("page-1") }
    #expect(throws: DesignTreeError.unknownID("node-1")) { try workspace.moveNode("node-1", into: nil) }
    #expect(throws: DesignTreeError.unknownID("node-1")) { try workspace.setNodeHidden("node-1", true) }
    workspace.selectItem("node-1")
    #expect(workspace == DesignWorkspace())
    #expect(workspace.layerRows.isEmpty)
}

@Test func unknownIDsAreRefusedAndChangeNothing() throws {
    var workspace = try sampleFile()
    let before = workspace
    #expect(throws: DesignTreeError.unknownID("nope")) { try workspace.moveNode("nope", into: nil) }
    #expect(throws: DesignTreeError.unknownID("nope")) { try workspace.moveNode("node-3", into: "nope") }
    #expect(throws: DesignTreeError.unknownID("nope")) { try workspace.renameNode("nope", to: "X") }
    #expect(throws: DesignTreeError.unknownID("nope")) { try workspace.renamePage("nope", to: "X") }
    #expect(throws: DesignTreeError.unknownID("nope")) { try workspace.setNodeLocked("nope", true) }
    workspace.selectItem("nope")
    #expect(workspace == before)
}

@Test func addingIntoALeafIsRefusedAndKeepsTheNodeCount() throws {
    var workspace = try sampleFile()
    let before = workspace
    for kind in DesignNodeKind.allCases where !kind.holdsChildren {
        #expect(throws: DesignTreeError.notAContainer("node-3")) { try workspace.addNode(kind, frame: box, in: "node-3") }
    }
    #expect(workspace.pages == before.pages)
    #expect(workspace.selectedNodeID == before.selectedNodeID)
    #expect(throws: DesignTreeError.unknownID("nope")) { try workspace.addNode(.text, frame: box, in: "nope") }
    #expect(workspace.pages == before.pages)
}

@Test func whitespaceOnlyNamesAreRefused() throws {
    var workspace = try sampleFile()
    for name in ["", " ", "\t", "\n", " \u{00A0}\u{2003} "] {
        #expect(throws: DesignTreeError.emptyName) { try workspace.renamePage("page-1", to: name) }
        #expect(throws: DesignTreeError.emptyName) { try workspace.renameNode("node-2", to: name) }
    }
    #expect(workspace.pages.map(\.name) == ["Page 1"])
    #expect(workspace.selectedPage?.nodes.first?.children.first?.name == "Group")
}

@Test func aNodeMovesToTheTopAndBackIntoAnAncestor() throws {
    var workspace = try sampleFile()
    try workspace.moveNode("node-3", into: nil)
    #expect(workspace.layerRows.map(\.id) == ["node-3", "node-1", "node-2", "node-4"])
    #expect(workspace.layerRows.map(\.depth) == [0, 0, 1, 2])
    // A parent moves into a former child's old ancestor; its subtree comes with it.
    try workspace.moveNode("node-2", into: nil)
    try workspace.moveNode("node-1", into: "node-2")
    #expect(workspace.layerRows.map(\.id) == ["node-2", "node-1", "node-4", "node-3"])
    #expect(workspace.layerRows.map(\.depth) == [0, 1, 1, 0])
}

@Test func aNodeCannotMoveIntoANodeOnAnotherPage() throws {
    var workspace = try sampleFile()
    workspace.addPage()
    let other = try workspace.addNode(.frame, frame: box)
    let before = workspace
    #expect(throws: DesignTreeError.unknownID(other)) { try workspace.moveNode("node-3", into: other) }
    #expect(workspace == before)
}

@Test func aDeepChainRefusesEveryMoveIntoItsOwnSubtree() throws {
    var workspace = DesignWorkspace()
    workspace.newFile()
    var chain = ["node-1"]
    for _ in 0..<20 {
        let last = chain.last ?? "node-1"
        chain.append(try workspace.addNode(.group, frame: box, in: last))
    }
    #expect(workspace.layerRows.map(\.depth) == Array(0...20))
    let before = workspace
    for (index, id) in chain.enumerated() {
        for descendant in chain[index...] {
            #expect(throws: DesignTreeError.intoItself(descendant)) { try workspace.moveNode(id, into: descendant) }
        }
    }
    #expect(workspace == before)
}

@Test func nodeIDsStayUniqueAcrossPagesAndMoves() throws {
    var workspace = try sampleFile()
    workspace.addPage()
    try workspace.addNode(.text, frame: box)
    try workspace.deletePage("page-1")
    let id = try workspace.addNode(.instance, frame: box)
    #expect(id == "node-7")
    #expect(workspace.layerRows.map(\.id) == ["node-7", "node-6", "node-5"])
    // node-3 went with its page, so selecting it is ignored.
    workspace.selectItem("node-3")
    #expect(workspace.selectedPageID == "page-2")
    #expect(workspace.selectedNodeID == "node-7")
}

@Test func deletingTheSelectedPageSelectsItsNeighborAndClearsTheNode() throws {
    var workspace = try sampleFile()
    workspace.addPage()
    workspace.addPage()
    workspace.selectItem("node-3")
    try workspace.deletePage("page-1")
    #expect(workspace.selectedPageID == "page-2")
    #expect(workspace.selectedNodeID == nil)
    try workspace.deletePage("page-3")
    #expect(workspace.selectedPageID == "page-2")
    workspace.addPage()
    try workspace.deletePage("page-4")
    #expect(workspace.selectedPageID == "page-2")
    #expect(throws: DesignTreeError.lastPage) { try workspace.deletePage("page-2") }
}

@Test func deletingAnotherPageKeepsTheSelection() throws {
    var workspace = try sampleFile()
    workspace.addPage()
    workspace.selectItem("node-4")
    try workspace.deletePage("page-2")
    #expect(workspace.selectedPageID == "page-1")
    #expect(workspace.selectedNode?.name == "Ellipse")
}

@Test func hiddenAndLockedNodesKeepTheirFlagsThroughAMove() throws {
    var workspace = try sampleFile()
    try workspace.setNodeHidden("node-2", true)
    try workspace.setNodeLocked("node-2", true)
    try workspace.moveNode("node-2", into: nil)
    let group = try #require(workspace.selectedPage?.nodes.last)
    #expect(group.id == "node-2" && group.isHidden && group.isLocked)
    #expect(group.children.map(\.id) == ["node-3", "node-4"])
    try workspace.setNodeHidden("node-2", false)
    #expect(workspace.selectedPage?.nodes.last?.isHidden == false)
}

@Test func newFileResetsTheTreeAndSelection() throws {
    var workspace = try sampleFile()
    workspace.addPage()
    workspace.selectItem("node-3")
    workspace.newFile()
    #expect(workspace.pages.map(\.id) == ["page-1"])
    #expect(workspace.selectedNodeID == nil)
    #expect(workspace.expandedNodeIDs.isEmpty)
    #expect(workspace.layerRows.map(\.node.name) == ["Desktop"])
}
