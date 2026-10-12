// DesignRestorePageTests.swift: restorePage, the undo of Page > Delete Page.
// A restored page comes back at its index with its nodes, ids and the selection
// from before the delete. Runs on Linux and macOS.
import DesignModel
import Testing

/// Three pages; page-2 holds a frame with a rectangle inside, and the rectangle is selected.
private func threePages() throws -> DesignWorkspace {
    var workspace = DesignWorkspace()
    workspace.newFile()
    workspace.addPage()
    let frame = try workspace.addNode(.frame, frame: DesignRect(x: 0, y: 0, width: 10, height: 10))
    try workspace.addNode(.rectangle, frame: DesignRect(x: 1, y: 1, width: 2, height: 2), in: frame)
    workspace.addPage()
    workspace.selectItem("node-3")
    return workspace
}

@Test func deleteThenRestoreGivesBackTheSameWorkspace() throws {
    let before = try threePages()
    var workspace = before
    let deleted = try workspace.deletePage("page-2")
    #expect(workspace.pages.map(\.id) == ["page-1", "page-3"])
    #expect(workspace.selectedPageID == "page-3")
    #expect(workspace.selectedNodeID == nil)
    try workspace.restorePage(deleted)
    #expect(workspace == before)
    #expect(workspace.pages.map(\.id) == ["page-1", "page-2", "page-3"])
    #expect(workspace.selectedNodeID == "node-3")
    #expect(workspace.layerRows.map(\.id) == ["node-2", "node-3"])
}

@Test func restoringAnUnselectedPageKeepsTheSelection() throws {
    var workspace = try threePages()
    workspace.selectPage("page-1")
    let before = workspace
    let deleted = try workspace.deletePage("page-3")
    #expect(workspace.selectedPageID == "page-1")
    try workspace.restorePage(deleted)
    #expect(workspace == before)
}

@Test func redoAfterRestoreDeletesAgainAndRestoresAgain() throws {
    let before = try threePages()
    var workspace = before
    try workspace.restorePage(try workspace.deletePage("page-2"))
    let deleted = try workspace.deletePage("page-2")
    try workspace.restorePage(deleted)
    #expect(workspace == before)
}

@Test func restoredIdsAreNotReused() throws {
    var workspace = try threePages()
    try workspace.restorePage(try workspace.deletePage("page-2"))
    workspace.addPage()
    let node = try workspace.addNode(.text, frame: DesignRect(x: 0, y: 0, width: 1, height: 1))
    #expect(workspace.pages.map(\.id) == ["page-1", "page-2", "page-3", "page-4"])
    #expect(node == "node-4")
}

@Test func restoringTwiceIsRefused() throws {
    var workspace = try threePages()
    let deleted = try workspace.deletePage("page-2")
    try workspace.restorePage(deleted)
    let restored = workspace
    #expect(throws: DesignTreeError.alreadyExists("page-2")) { try workspace.restorePage(deleted) }
    #expect(workspace == restored)
}

@Test func aPageFromAnEarlierFileIsRefused() throws {
    var workspace = try threePages()
    let deleted = try workspace.deletePage("page-2")
    workspace.newFile()
    workspace.addPage()
    let fresh = workspace
    #expect(throws: DesignTreeError.unknownID("page-2")) { try workspace.restorePage(deleted) }
    #expect(workspace == fresh)
}

@Test func restoreClampsItsIndexWhenPagesWereDeletedSince() throws {
    var workspace = try threePages()
    let deleted = try workspace.deletePage("page-3")
    try workspace.deletePage("page-2")
    try workspace.restorePage(deleted)
    #expect(workspace.pages.map(\.id) == ["page-1", "page-3"])
    #expect(workspace.selectedPageID == "page-1")
}
