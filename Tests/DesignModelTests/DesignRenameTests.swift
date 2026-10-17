// DesignRenameTests.swift: renameNode and renamePage keep a name without its
// surrounding whitespace, refuse a blank one, and record nothing for the same
// name. Runs on Linux and macOS.
import DesignModel
import Testing

@Test func aLayerRenameTrimsTheName() throws {
    var workspace = openDesign()
    try workspace.renameNode("node-1", to: "  Avatar \n")
    #expect(workspace.treeNode("node-1")?.name == "Avatar")
    #expect(workspace.undoActionName == "Undo Rename Layer")
}

@Test func aPageRenameTrimsTheName() throws {
    var workspace = openDesign()
    try workspace.renamePage("page-1", to: "  Avatar ")
    #expect(workspace.pages.first?.name == "Avatar")
    #expect(workspace.undoActionName == "Undo Rename Page")
}

@Test func aRenameToTheSameTrimmedNameRecordsNothing() throws {
    var workspace = openDesign()
    try workspace.renameNode("node-1", to: "Avatar")
    try workspace.renamePage("page-1", to: "Cover")
    let before = workspace
    try workspace.renameNode("node-1", to: " Avatar  ")
    try workspace.renamePage("page-1", to: "\tCover ")
    #expect(workspace == before)
    #expect(workspace.undoActionName == "Undo Rename Page")
}

@Test(arguments: ["", "   ", "\n\t "])
func aBlankNameIsStillRefused(_ name: String) throws {
    var workspace = openDesign()
    let before = workspace
    #expect(throws: DesignTreeError.emptyName) { try workspace.renameNode("node-1", to: name) }
    #expect(throws: DesignTreeError.emptyName) { try workspace.renamePage("page-1", to: name) }
    #expect(workspace == before)
}

@Test func anInnerSpaceStays() throws {
    var workspace = openDesign()
    try workspace.renameNode("node-1", to: " Hero  Card ")
    #expect(workspace.treeNode("node-1")?.name == "Hero  Card")
}
