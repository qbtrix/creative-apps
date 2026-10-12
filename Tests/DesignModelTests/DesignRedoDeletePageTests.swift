// DesignRedoDeletePageTests.swift: redoDeletePage, the redo of Page > Delete
// Page. It deletes the page again in the same file and is refused once New File
// opened another file, even when that file reuses the page's id (#124). Runs on
// Linux and macOS.
import DesignModel
import Testing

@Test func redoDeletesThePageAgainInTheSameFile() throws {
    var workspace = DesignWorkspace()
    workspace.newFile()
    workspace.addPage()
    let deleted = try workspace.deletePage("page-2")
    let afterDelete = workspace
    try workspace.restorePage(deleted)
    let again = try workspace.redoDeletePage(deleted)
    #expect(workspace == afterDelete)
    try workspace.restorePage(again)
    #expect(workspace.pages.map(\.id) == ["page-1", "page-2"])
}

@Test func redoFromAnEarlierFileLeavesTheNewFileAlone() throws {
    var workspace = DesignWorkspace()
    workspace.newFile()
    workspace.addPage()
    let deleted = try workspace.deletePage("page-2")
    try workspace.restorePage(deleted)
    workspace.newFile()
    workspace.addPage()
    _ = try workspace.addNode(.frame, frame: DesignRect(x: 0, y: 0, width: 10, height: 10))
    let before = workspace
    #expect(throws: DesignTreeError.unknownID("page-2")) { try workspace.redoDeletePage(deleted) }
    #expect(workspace == before)
    #expect(workspace.pages.map(\.id) == ["page-1", "page-2"])
    #expect(workspace.layerRows.map(\.id) == ["node-2"])
}
