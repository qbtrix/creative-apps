// DesignPageCommandTests.swift: canDeletePage, which enables Page > Delete
// Page, and addPageHelp / deletePageHelp, the reasons the sidebar's Add Page
// and Delete Page show while they can't run. Runs on Linux and macOS.
import DesignModel
import Testing

@Test func deletePageIsUnavailableWithNoFileOrOnePage() {
    var workspace = DesignWorkspace()
    #expect(!workspace.canDeletePage)
    workspace.newFile()
    #expect(!workspace.canDeletePage)
}

@Test func deletePageIsAvailableUntilOnePageRemains() throws {
    var workspace = DesignWorkspace()
    workspace.newFile()
    workspace.addPage()
    #expect(workspace.canDeletePage)
    if let id = workspace.selectedPageID { try workspace.deletePage(id) }
    #expect(workspace.pages.map(\.id) == ["page-1"])
    #expect(!workspace.canDeletePage)
}

@Test func pageCommandsSayWhyWithNoFileOpen() {
    let workspace = DesignWorkspace()
    #expect(workspace.addPageHelp == "Create or open a file first.")
    #expect(workspace.deletePageHelp == "Create or open a file first.")
}

@Test func pageCommandHelpFollowsThePageCount() {
    var workspace = DesignWorkspace()
    workspace.newFile()
    #expect(workspace.addPageHelp == nil)
    #expect(workspace.deletePageHelp == "A file keeps at least one page.")
    workspace.addPage()
    #expect(workspace.addPageHelp == nil)
    #expect(workspace.deletePageHelp == nil)
}
