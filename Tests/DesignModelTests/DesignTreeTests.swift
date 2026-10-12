// DesignTreeTests.swift: behavior of the page list and the per-page node tree
// in DesignWorkspace (rows, select, move, rename, delete, eye and lock).
// Runs on Linux and macOS.
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

@Test func newFileOpensWithAPageSizedDesktopFrame() {
    var workspace = DesignWorkspace()
    workspace.newFile()
    let desktop = DesignNode(id: "node-1", name: "Desktop", kind: .frame, frame: DesignRect(x: 0, y: 0, width: 1440, height: 1024))
    #expect(workspace.layerRows.map(\.node) == [desktop])
}

@Test func rowsFollowTheExpandedSet() throws {
    let workspace = try sampleFile()
    let page = try #require(workspace.selectedPage)
    #expect(page.visibleRows(expanded: []).map(\.id) == ["node-1"])
    #expect(page.visibleRows(expanded: ["node-1"]).map(\.id) == ["node-1", "node-2"])
    // Adding into a container expanded it, so the workspace shows the whole tree.
    #expect(workspace.layerRows == page.visibleRows(expanded: ["node-1", "node-2"]))
    #expect(workspace.layerRows.map(\.id) == ["node-1", "node-2", "node-3", "node-4"])
    #expect(workspace.layerRows.map(\.depth) == [0, 1, 2, 2])
    #expect(workspace.layerRows.map(\.node.kind.systemImage) == ["number", "square.dashed", "rectangle", "circle"])
}

@Test func movingIntoItsOwnDescendantIsRefusedAndElsewhereMoves() throws {
    var workspace = try sampleFile()
    let before = workspace
    #expect(throws: DesignTreeError.intoItself("node-2")) { try workspace.moveNode("node-1", into: "node-2") }
    #expect(throws: DesignTreeError.intoItself("node-2")) { try workspace.moveNode("node-2", into: "node-2") }
    #expect(throws: DesignTreeError.notAContainer("node-3")) { try workspace.moveNode("node-4", into: "node-3") }
    #expect(workspace == before)
    try workspace.moveNode("node-4", into: "node-1")
    #expect(workspace.layerRows.map(\.id) == ["node-1", "node-2", "node-3", "node-4"])
    #expect(workspace.layerRows.map(\.depth) == [0, 1, 2, 1])
}

@Test func deletingTheLastPageIsRefused() throws {
    var workspace = DesignWorkspace()
    workspace.newFile()
    #expect(throws: DesignTreeError.lastPage) { try workspace.deletePage("page-1") }
    workspace.addPage()
    try workspace.deletePage("page-2")
    #expect(workspace.pages.map(\.id) == ["page-1"])
    workspace.addPage()
    #expect(workspace.pages.map(\.id) == ["page-1", "page-3"])
}

@Test func anEmptyRenameIsRefused() throws {
    var workspace = try sampleFile()
    #expect(throws: DesignTreeError.emptyName) { try workspace.renamePage("page-1", to: "  ") }
    #expect(throws: DesignTreeError.emptyName) { try workspace.renameNode("node-3", to: "") }
    try workspace.renamePage("page-1", to: "Home")
    try workspace.renameNode("node-3", to: "Card")
    #expect(workspace.pages.map(\.name) == ["Home"])
    #expect(workspace.layerRows.map(\.node.name) == ["Desktop", "Group", "Card", "Ellipse"])
}

@Test func selectingANodeOnAnotherPageSwitchesPages() throws {
    var workspace = try sampleFile()
    workspace.addPage()
    workspace.selectItem("node-3")
    #expect(workspace.selectedPageID == "page-1")
    #expect(workspace.selectedNode?.name == "Rectangle")
}

@Test func eyeAndLockToggles() throws {
    var workspace = try sampleFile()
    try workspace.setNodeHidden("node-4", true)
    try workspace.setNodeLocked("node-1", true)
    #expect(workspace.layerRows.map { [$0.node.isHidden, $0.node.isLocked] } == [[false, true], [false, false], [false, false], [true, false]])
}
