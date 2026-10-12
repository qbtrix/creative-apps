// DesignNewFileCommandTests.swift: newFile() as File > New File (⌘N) reaches
// it, including over a file that is already open. Runs on Linux and macOS.
import DesignModel
import Testing

@Test func newFileOverAnOpenFileStartsFresh() throws {
    var workspace = DesignWorkspace()
    workspace.newFile()
    let fresh = workspace
    let box = DesignRect(x: 10, y: 10, width: 50, height: 50)
    try workspace.addNode(.rectangle, frame: box, in: "node-1")
    workspace.addPage()
    workspace.newFile()
    // Compare the document, not the whole workspace: newFile() also bumps the file generation.
    #expect(workspace.pages == fresh.pages)
    #expect(workspace.layerRows == fresh.layerRows)
    #expect(workspace.pages.map(\.id) == ["page-1"])
    #expect(workspace.selectedPageID == "page-1")
    #expect(workspace.selectedNodeID == nil)
}
