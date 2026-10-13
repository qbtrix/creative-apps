// DesignAddNodeAncestorFuzzTests.swift: adversarial and seeded-fuzz checks that
// addNode expands exactly the new node's enclosing rows: the selected node gets
// a Layers row at its nesting depth, and no other row's disclosure changes.
// Runs on Linux and macOS.
import DesignModel
import Testing

private let box = DesignRect(x: 0, y: 0, width: 10, height: 10)

/// A small deterministic generator, so a failing seed replays.
private struct SplitMix64: RandomNumberGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func next(below bound: Int) -> Int { Int.random(in: 0..<bound, using: &self) }
}

/// The ids enclosing `id` in `nodes`, outermost first; nil when `id` is not there.
private func chain(to id: String, in nodes: [DesignNode]) -> [String]? {
    for node in nodes {
        if node.id == id { return [] }
        if let path = chain(to: id, in: node.children) { return [node.id] + path }
    }
    return nil
}

/// Every node id on `nodes`, nested ones included.
private func ids(_ nodes: [DesignNode]) -> [String] { nodes.flatMap { [$0.id] + ids($0.children) } }

@Test func aDeepCollapsedChainFullyExpandsOnAdd() throws {
    var workspace = DesignWorkspace()
    workspace.newFile()
    var parent = "node-1"
    var path = [parent]
    for _ in 0..<64 {
        parent = try workspace.addNode(.group, frame: box, in: parent)
        path.append(parent)
    }
    for id in path { try workspace.setExpanded(id, false) }
    #expect(workspace.layerRows.map(\.id) == ["node-1"])
    let added = try workspace.addNode(.rectangle, frame: box, in: parent)
    #expect(workspace.expandedNodeIDs == Set(path))
    let row = workspace.layerRows.first { $0.id == added }
    #expect(row?.depth == path.count)
    #expect(workspace.layerRows.map(\.id) == path + [added])
}

@Test func aRefusedAddUnderACollapsedChainExpandsNothing() throws {
    var workspace = DesignWorkspace()
    workspace.newFile()
    let group = try workspace.addNode(.group, frame: box, in: "node-1")
    let leaf = try workspace.addNode(.rectangle, frame: box, in: group)
    try workspace.setExpanded("node-1", false)
    try workspace.setExpanded(group, false)
    let before = workspace
    #expect(throws: DesignTreeError.notAContainer(leaf)) { try workspace.addNode(.text, frame: box, in: leaf) }
    #expect(workspace == before)
    #expect(workspace.expandedNodeIDs.isEmpty)
}

@Test func addingOnOnePageLeavesAnotherPagesCollapsedRowsAlone() throws {
    var workspace = DesignWorkspace()
    workspace.newFile()
    let firstGroup = try workspace.addNode(.group, frame: box, in: "node-1")
    try workspace.setExpanded("node-1", false)
    workspace.addPage()
    let frame = try workspace.addNode(.frame, frame: box)
    let group = try workspace.addNode(.group, frame: box, in: frame)
    try workspace.setExpanded(frame, false)
    let added = try workspace.addNode(.ellipse, frame: box, in: group)
    #expect(workspace.expandedNodeIDs == [frame, group])
    #expect(!workspace.isExpanded("node-1"))
    #expect(!workspace.isExpanded(firstGroup))
    #expect(workspace.layerRows.map(\.id) == [frame, group, added, "node-3"])
}

@Test func addingUnderAHiddenCollapsedContainerStillShowsTheRow() throws {
    var workspace = DesignWorkspace()
    workspace.newFile()
    let group = try workspace.addNode(.group, frame: box, in: "node-1")
    try workspace.setNodeHidden(group, true)
    try workspace.setNodeLocked("node-1", true)
    try workspace.setExpanded("node-1", false)
    try workspace.setExpanded(group, false)
    let added = try workspace.addNode(.text, frame: box, in: group)
    #expect(workspace.selectedNode?.id == added)
    #expect(workspace.layerRows.map(\.id) == ["node-1", group, added])
}

@Test(arguments: [UInt64(3), 11, 99, 2026, 0xC0FF_EE00])
func fuzzedAddsExpandExactlyTheNewNodesChain(seed: UInt64) throws {
    var rng = SplitMix64(state: seed)
    var workspace = DesignWorkspace()
    workspace.newFile()
    for _ in 0..<400 {
        let roll = rng.next(below: 20)
        if roll == 0 {
            workspace.addPage()
            continue
        }
        if roll == 1, let page = workspace.pages.randomElement(using: &rng) {
            workspace.selectPage(page.id)
            continue
        }
        let all = workspace.pages.flatMap { ids($0.nodes) }
        if roll < 8, let id = all.randomElement(using: &rng) {
            try workspace.setExpanded(id, rng.next(below: 3) == 0)
            continue
        }
        let page = try #require(workspace.selectedPage)
        let candidates = ids(page.nodes)
        let parent = candidates.isEmpty || rng.next(below: 5) == 0 ? nil : candidates.randomElement(using: &rng)
        let kind = DesignNodeKind.allCases.randomElement(using: &rng) ?? .group
        let before = workspace
        guard let added = try? workspace.addNode(kind, frame: box, in: parent) else {
            #expect(workspace == before)
            continue
        }
        let nodes = try #require(workspace.selectedPage?.nodes)
        let path = try #require(chain(to: added, in: nodes))
        #expect(workspace.selectedNodeID == added)
        #expect(workspace.expandedNodeIDs == before.expandedNodeIDs.union(path))
        #expect(workspace.layerRows.first { $0.id == added }?.depth == path.count)
    }
}
