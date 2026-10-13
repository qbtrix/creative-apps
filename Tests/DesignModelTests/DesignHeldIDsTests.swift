// DesignHeldIDsTests.swift: the held-id index stays equal to the ids on the
// pages through add, delete, undo, redo, New File and open, so minted ids stay
// unique; and a drawing stroke mints from the index without rescanning the
// tree (#433). Runs on Linux and macOS.
@testable import DesignModel
import Testing

private func allIDs(_ workspace: DesignWorkspace) -> [String] {
    func ids(_ nodes: [DesignNode]) -> [String] { nodes.flatMap { [$0.id] + ids($0.children) } }
    return workspace.pages.map(\.id) + workspace.pages.flatMap { ids($0.nodes) }
}

/// The index matches a fresh scan of the pages, and no id is held twice.
private func expectConsistent(_ workspace: DesignWorkspace, _ comment: Comment) {
    let ids = allIDs(workspace)
    #expect(Set(ids).count == ids.count, comment)
    #expect(workspace.held.ids == Set(ids), comment)
}

@Test func theIndexFollowsAddDeleteUndoRedoNewFileAndOpen() throws {
    var workspace = openDesign()
    expectConsistent(workspace, "new file")
    let frame = try workspace.addNode(.frame, frame: rc(0, 0, 200, 200))
    try workspace.addNode(.rectangle, frame: rc(10, 10, 20, 20), in: frame)
    workspace.addPage()
    expectConsistent(workspace, "after adds")
    workspace.selectItem(frame)
    workspace.deleteSelection()
    expectConsistent(workspace, "after deleting a subtree")
    let doomed = try #require(workspace.selectedPageID)
    try workspace.deletePage(doomed)
    expectConsistent(workspace, "after deleting a page")
    for step in 0..<4 {
        workspace.undo()
        expectConsistent(workspace, "after undo \(step)")
    }
    let id = try workspace.addNode(.ellipse, frame: rc(0, 0, 5, 5))
    #expect(allIDs(workspace).filter { $0 == id }.count == 1)
    workspace.undo()
    workspace.redo()
    expectConsistent(workspace, "after redo")
    workspace.newFile()
    expectConsistent(workspace, "after New File")
    workspace.undo()
    expectConsistent(workspace, "after undoing New File")
    let data = try workspace.fileData()
    var reopened = DesignWorkspace()
    try reopened.open(data)
    expectConsistent(reopened, "after open")
    try reopened.addNode(.rectangle, frame: rc(0, 0, 5, 5))
    expectConsistent(reopened, "after adding to the opened file")
}

@Test func aTextEditCancelAndADrawingStrokeLeaveTheIndexExact() {
    var workspace = openDesign()
    workspace.gesture(.text, pt(50, 50), pt(50, 50))
    workspace.cancelTextEdit()
    expectConsistent(workspace, "after cancelling a placed text")
    workspace.selectTool(.rectangle)
    for step in 1...10 { workspace.drag(from: pt(100, 100), to: pt(100 + Double(step), 140)) }
    expectConsistent(workspace, "mid-stroke")
    workspace.endDrag()
    expectConsistent(workspace, "after the stroke")
}

@Test func strokeFramesOnALargeFileMintWithoutRescanning() {
    var page = DesignPage(id: "page-1", name: "Big", frameWidth: 1440, frameHeight: 1024)
    page.nodes = (1...50_000).map {
        DesignNode(id: "node-\($0)", name: "R", kind: .rectangle, frame: rc(2000, 2000, 1, 1))
    }
    var workspace = DesignWorkspace()
    workspace.load([page])
    let scans = workspace.held.scans
    workspace.selectTool(.rectangle)
    for step in 1...50 { workspace.drag(from: pt(10, 10), to: pt(10 + Double(step), 60)) }
    workspace.endDrag()
    workspace.addPage()
    workspace.undo()
    #expect(workspace.held.scans == scans)
    #expect(workspace.pages.first?.nodes.last?.id == "node-50001")
    expectConsistent(workspace, "after the stroke")
}
