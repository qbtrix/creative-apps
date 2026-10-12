// DesignPageSelectionEdgeTests.swift: adversarial and seeded-fuzz checks on
// the page-row selection path (#48). Selecting a page row only ever changes
// the selected page and clears the selected node; the tree, expanded rows and
// tool stay put. Runs on Linux and macOS.
import DesignModel
import Testing

private let box = DesignRect(x: 0, y: 0, width: 10, height: 10)

@Test func thePageRowClearsANestedLayerAndKeepsTheTreeRowsAndTool() throws {
    var workspace = DesignWorkspace()
    workspace.newFile()
    let group = try workspace.addNode(.group, frame: box, in: "node-1")
    let leaf = try workspace.addNode(.ellipse, frame: box, in: group)
    workspace.selectTool(.pen)
    let before = workspace
    #expect(workspace.selectedNodeID == leaf)
    workspace.selectItem("page-1")
    #expect(workspace.selectedPageID == "page-1")
    #expect(workspace.selectedNodeID == nil)
    #expect(workspace.pages == before.pages)
    #expect(workspace.expandedNodeIDs == before.expandedNodeIDs)
    #expect(workspace.layerRows == before.layerRows)
    #expect(workspace.tool == .pen)
}

@Test func clickingThePageRowAgainChangesNothing() {
    var workspace = DesignWorkspace()
    workspace.newFile()
    workspace.selectItem("node-1")
    workspace.selectItem("page-1")
    let once = workspace
    workspace.selectItem("page-1")
    workspace.selectPage("page-1")
    #expect(workspace == once)
}

@Test func thePageRowClearsALayerReachedFromAnotherPage() throws {
    var workspace = DesignWorkspace()
    workspace.newFile()
    workspace.addPage()
    let onPage2 = try workspace.addNode(.frame, frame: box)
    workspace.selectItem("node-1")
    #expect(workspace.selectedPageID == "page-1")
    workspace.selectItem(onPage2)
    #expect(workspace.selectedPageID == "page-2")
    workspace.selectItem("page-2")
    #expect(workspace.selectedPageID == "page-2")
    #expect(workspace.selectedNodeID == nil)
}

@Test func aDeletedPageRowKeepsTheLayer() throws {
    var workspace = DesignWorkspace()
    workspace.newFile()
    workspace.addPage()
    workspace.selectItem("node-1")
    try workspace.deletePage("page-2")
    let before = workspace
    workspace.selectItem("page-2")
    workspace.selectPage("page-2")
    #expect(workspace == before)
    #expect(workspace.selectedNodeID == "node-1")
}

@Test func pageRowsWithNoFileOpenChangeNothing() {
    var workspace = DesignWorkspace()
    let before = workspace
    for id in ["page-1", "node-1", ""] {
        workspace.selectItem(id)
        workspace.selectPage(id)
    }
    #expect(workspace == before)
    #expect(workspace.selectedPage == nil)
}

/// Every node id on every page, nested ones included.
private func nodeIDs(_ workspace: DesignWorkspace) -> [String] {
    func walk(_ nodes: [DesignNode]) -> [String] { nodes.flatMap { [$0.id] + walk($0.children) } }
    return workspace.pages.flatMap { walk($0.nodes) }
}

@Test(arguments: [UInt64(1), 7, 48, 2_026])
func seededClicksKeepTheSelectionConsistent(seed: UInt64) throws {
    // A linear congruential generator, so a failing seed replays.
    var state = seed
    func roll(_ bound: Int) -> Int {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Int((state >> 33) % UInt64(bound))
    }
    var workspace = DesignWorkspace()
    workspace.newFile()
    for _ in 0..<400 {
        let pageIDs = workspace.pages.map(\.id)
        let ids = pageIDs + nodeIDs(workspace) + ["page-0", "node-0", ""]
        switch roll(6) {
        case 0: workspace.addPage()
        case 1: _ = try? workspace.addNode(.group, frame: box, in: roll(2) == 0 ? nil : workspace.selectedNodeID)
        case 2: if let id = workspace.selectedPageID { try? workspace.deletePage(id) }
        default:
            let id = ids[roll(ids.count)]
            let before = workspace
            workspace.selectItem(id)
            if pageIDs.contains(id) {
                #expect(workspace.selectedPageID == id)
                #expect(workspace.selectedNodeID == nil)
                #expect(workspace.pages == before.pages)
                #expect(workspace.expandedNodeIDs == before.expandedNodeIDs)
            } else if !nodeIDs(workspace).contains(id) {
                #expect(workspace == before)
            }
        }
        // A selected node is always on the selected page.
        #expect(workspace.selectedPage != nil)
        #expect((workspace.selectedNodeID == nil) == (workspace.selectedNode == nil))
    }
}
