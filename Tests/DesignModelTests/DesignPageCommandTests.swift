// DesignPageCommandTests.swift: canDeletePage, which enables Page > Delete
// Page. Runs on Linux and macOS.
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
