// DesignWorkspaceTests.swift: behavior of DesignWorkspace, the state behind
// Design's window. Runs on Linux and macOS.
import DesignModel
import Testing

@Test func newFileHasOneSelectedPage() {
    var workspace = DesignWorkspace()
    #expect(!workspace.isOpen)
    workspace.newFile()
    #expect(workspace.pages.map(\.name) == ["Page 1"])
    #expect(workspace.selectedPage?.frameWidth == 1440)
}

@Test func addPageNumbersAndSelectsIt() {
    var workspace = DesignWorkspace()
    workspace.newFile()
    workspace.addPage()
    #expect(workspace.pages.map(\.id) == ["page-1", "page-2"])
    #expect(workspace.selectedPageID == "page-2")
    workspace.selectPage("page-1")
    #expect(workspace.selectedPageID == "page-1")
}

@Test func addPageWithNoFileDoesNothing() {
    var workspace = DesignWorkspace()
    workspace.addPage()
    #expect(workspace.pages.isEmpty)
}

@Test func unknownPageAndToolSelection() {
    var workspace = DesignWorkspace()
    workspace.newFile()
    workspace.selectPage("missing")
    workspace.selectTool(.text)
    #expect(workspace.selectedPageID == "page-1")
    #expect(workspace.tool == .text)
}
