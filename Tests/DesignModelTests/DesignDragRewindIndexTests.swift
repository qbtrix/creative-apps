// DesignDragRewindIndexTests.swift: a Move or Resize drag puts back the held-id
// index along with the pages on every pointer move, so an edit made mid-drag
// (Delete, Add Page) leaves `held` holding exactly the ids on the pages (#443).
// Runs on Linux and macOS.
@testable import DesignModel
import Testing

private func pageIDs(_ workspace: DesignWorkspace) -> Set<String> {
    func ids(_ nodes: [DesignNode]) -> [String] { nodes.flatMap { [$0.id] + ids($0.children) } }
    return Set(workspace.pages.map(\.id) + workspace.pages.flatMap { ids($0.nodes) })
}

@Test func deleteDuringAMoveDragKeepsTheIndexInStep() throws {
    var workspace = openDesign()
    let rect = try workspace.addNode(.rectangle, frame: rc(10, 10, 40, 40))
    workspace.selectTool(.move)
    workspace.drag(from: pt(20, 20), to: pt(30, 30))
    workspace.deleteSelection()
    workspace.drag(from: pt(20, 20), to: pt(40, 40))
    workspace.endDrag()
    #expect(workspace.treeNode(rect) != nil)
    #expect(workspace.held.ids.contains(rect))
    #expect(workspace.held.ids == pageIDs(workspace))
}

@Test func addPageDuringAMoveDragKeepsTheIndexInStep() throws {
    var workspace = openDesign()
    _ = try workspace.addNode(.rectangle, frame: rc(10, 10, 40, 40))
    workspace.selectTool(.move)
    workspace.drag(from: pt(20, 20), to: pt(30, 30))
    workspace.addPage()
    workspace.drag(from: pt(20, 20), to: pt(40, 40))
    workspace.endDrag()
    #expect(workspace.held.ids == ["page-1", "node-1", "node-2"])
    #expect(workspace.held.ids == pageIDs(workspace))
}

@Test func addPageDuringAResizeDragKeepsTheIndexInStep() throws {
    var workspace = openDesign()
    let rect = try workspace.addNode(.rectangle, frame: rc(10, 10, 40, 40))
    workspace.selectItem(rect)
    workspace.selectTool(.move)
    workspace.drag(from: pt(50, 50), to: pt(60, 60))
    workspace.addPage()
    workspace.drag(from: pt(50, 50), to: pt(70, 70))
    workspace.endDrag()
    #expect(workspace.frame(rect) == rc(10, 10, 60, 60))
    #expect(workspace.held.ids == pageIDs(workspace))
}

@Test func anIndexSyncedMidDragSurvivesUndoAndRedo() throws {
    var workspace = openDesign()
    let rect = try workspace.addNode(.rectangle, frame: rc(10, 10, 40, 40))
    workspace.selectTool(.move)
    workspace.drag(from: pt(20, 20), to: pt(30, 30))
    workspace.deleteSelection()
    workspace.drag(from: pt(20, 20), to: pt(40, 40))
    workspace.endDrag()
    workspace.undo()
    #expect(workspace.held.ids == pageIDs(workspace))
    workspace.redo()
    #expect(workspace.held.ids == pageIDs(workspace))
    #expect(workspace.held.ids.contains(rect))
}
