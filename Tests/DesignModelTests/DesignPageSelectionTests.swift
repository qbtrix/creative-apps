// DesignPageSelectionTests.swift: selecting a page row clears the selected
// layer, whether or not that page was already selected (#48). Runs on Linux and macOS.
import DesignModel
import Testing

private let box = DesignRect(x: 0, y: 0, width: 10, height: 10)

@Test func selectingTheSelectedPageClearsTheLayer() throws {
    var workspace = DesignWorkspace()
    workspace.newFile()
    workspace.selectItem("node-1")
    #expect(workspace.selectedNodeID == "node-1")
    workspace.selectPage("page-1")
    #expect(workspace.selectedPageID == "page-1")
    #expect(workspace.selectedNodeID == nil)
    #expect(workspace.selectedNode == nil)
}

@Test func selectItemOnTheSelectedPageRowClearsTheLayer() throws {
    var workspace = DesignWorkspace()
    workspace.newFile()
    try workspace.addNode(.rectangle, frame: box, in: "node-1")
    workspace.selectItem("page-1")
    #expect(workspace.selectedPageID == "page-1")
    #expect(workspace.selectedNodeID == nil)
}

@Test func selectingAnotherPageClearsTheLayer() throws {
    var workspace = DesignWorkspace()
    workspace.newFile()
    workspace.addPage()
    try workspace.addNode(.frame, frame: box)
    #expect(workspace.selectedNodeID != nil)
    workspace.selectItem("page-1")
    #expect(workspace.selectedPageID == "page-1")
    #expect(workspace.selectedNodeID == nil)
}

@Test func unknownPageKeepsTheLayer() {
    var workspace = DesignWorkspace()
    workspace.newFile()
    workspace.selectItem("node-1")
    let before = workspace
    workspace.selectPage("nope")
    #expect(workspace == before)
}
