// DesignLoadTests.swift: the internal load(_:) the file codec uses to open a
// document: it replaces everything, resets the transient state and the history,
// and starts the id counters past the highest id in the file. Reaches the
// internal method with @testable. Runs on Linux and macOS.
@testable import DesignModel
import Testing

private func page(_ id: String, _ nodes: [DesignNode] = []) -> DesignPage {
    DesignPage(id: id, name: id, frameWidth: 800, frameHeight: 600, nodes: nodes)
}

@Test func loadReplacesTheDocumentAndSelectsTheFirstPage() throws {
    var workspace = openDesign()
    workspace.gesture(.rectangle, pt(0, 0), pt(10, 10))
    workspace.gesture(.text, pt(50, 50), pt(50, 50))
    workspace.setTextDraft("Pending")
    workspace.selectTool(.move)
    workspace.selectItem("node-2")
    try workspace.setExpanded("node-1", true)
    workspace.drag(from: pt(5, 5), to: pt(6, 6))
    workspace.load([page("page-4"), page("page-9")])
    #expect(workspace.pages.map(\.id) == ["page-4", "page-9"])
    #expect(workspace.selectedPageID == "page-4" && workspace.selectedNodeID == nil)
    #expect(workspace.expandedNodeIDs.isEmpty && !workspace.canUndo && !workspace.canRedo)
    #expect(workspace.editingTextID == nil && workspace.textDraft == "")
    // No drag is left over: undo and a new gesture start clean.
    workspace.addPage()
    workspace.undo()
    #expect(workspace.pages.map(\.id) == ["page-4", "page-9"])
}

@Test func theCountersStartPastTheHighestIDsInTheFile() throws {
    let deep = DesignNode(id: "node-12", name: "Deep", kind: .rectangle, frame: rc(0, 0, 1, 1))
    let group = DesignNode(id: "node-3", name: "G", kind: .group, frame: rc(0, 0, 9, 9), children: [deep])
    var workspace = DesignWorkspace()
    workspace.load([page("page-7", [group]), page("page-2"), page("custom"), page("page-x")])
    workspace.addPage()
    #expect(workspace.pages.last?.id == "page-8")
    workspace.selectPage("page-7")
    #expect(try workspace.addNode(.ellipse, frame: rc(0, 0, 1, 1)) == "node-13")
}

@Test func absurdlyLargeIDsDoNotOverflowTheCounters() throws {
    var workspace = DesignWorkspace()
    let huge = DesignNode(id: "node-9223372036854775807", name: "H", kind: .rectangle, frame: rc(0, 0, 1, 1))
    workspace.load([page("page-9223372036854775807", [huge])])
    workspace.addPage()
    #expect(try workspace.addNode(.ellipse, frame: rc(0, 0, 1, 1)) == "node-1")
    #expect(workspace.pages.count == 2)
}

@Test func loadingNothingLeavesNoFileOpen() {
    var workspace = openDesign()
    workspace.load([])
    #expect(!workspace.isOpen && workspace.selectedPageID == nil)
}
