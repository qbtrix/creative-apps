// DesignLayersExpansionFuzzTests.swift: adversarial and seeded-fuzz checks on
// Layers expand and collapse. layerRows always matches a reference walk over
// isExpanded, a refused setExpanded changes nothing, two toggles undo each
// other, and a selected node always has a row. Runs on Linux and macOS.
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

/// Every node on every page, nested ones included.
private func allNodes(_ workspace: DesignWorkspace) -> [DesignNode] {
    func walk(_ nodes: [DesignNode]) -> [DesignNode] { nodes.flatMap { [$0] + walk($0.children) } }
    return workspace.pages.flatMap { walk($0.nodes) }
}

/// The rows the selected page should show, rebuilt from isExpanded alone.
private func expectedRows(_ workspace: DesignWorkspace) -> [String] {
    func walk(_ nodes: [DesignNode], _ depth: Int) -> [String] {
        nodes.flatMap { node in
            ["\(node.id)@\(depth)"] + (workspace.isExpanded(node.id) ? walk(node.children, depth + 1) : [])
        }
    }
    return walk(workspace.selectedPage?.nodes ?? [], 0)
}

private func rows(_ workspace: DesignWorkspace) -> [String] { workspace.layerRows.map { "\($0.id)@\($0.depth)" } }

@Test func expansionIsKeptPerNodeAcrossPageSwitches() throws {
    var workspace = DesignWorkspace()
    workspace.newFile()
    try workspace.addNode(.rectangle, frame: box, in: "node-1")
    try workspace.setExpanded("node-1", false)
    workspace.addPage()
    #expect(workspace.layerRows.isEmpty)
    // A node on another page can still be collapsed or expanded by id.
    try workspace.setExpanded("node-1", true)
    workspace.selectPage("page-1")
    #expect(workspace.layerRows.map(\.id) == ["node-1", "node-2"])
}

@Test func newFileForgetsTheExpandedSet() throws {
    var workspace = DesignWorkspace()
    workspace.newFile()
    try workspace.addNode(.group, frame: box, in: "node-1")
    #expect(workspace.isExpanded("node-1"))
    workspace.newFile()
    #expect(workspace.expandedNodeIDs.isEmpty)
    #expect(!workspace.isExpanded("node-1"))
    // A container in the new file is collapsed until something expands it.
    let group = try workspace.addNode(.group, frame: box)
    try workspace.addNode(.text, frame: box)
    #expect(workspace.layerRows.map(\.id) == ["node-1", group, "node-3"])
}

@Test func expandingIsRefusedWithNoFileOpenAndAfterAPageIsDeleted() throws {
    var closed = DesignWorkspace()
    #expect(throws: DesignTreeError.unknownID("")) { try closed.toggleExpanded("") }
    #expect(closed == DesignWorkspace())

    var workspace = DesignWorkspace()
    workspace.newFile()
    workspace.addPage()
    let frame = try workspace.addNode(.frame, frame: box)
    try workspace.deletePage("page-2")
    let before = workspace
    #expect(throws: DesignTreeError.unknownID(frame)) { try workspace.setExpanded(frame, true) }
    #expect(workspace == before)
}

@Test func collapsingAParentKeepsItsChildsOwnState() throws {
    var workspace = DesignWorkspace()
    workspace.newFile()
    let group = try workspace.addNode(.group, frame: box, in: "node-1")
    try workspace.addNode(.ellipse, frame: box, in: group)
    try workspace.setExpanded("node-1", false)
    #expect(workspace.isExpanded(group))
    #expect(workspace.layerRows.map(\.id) == ["node-1"])
    try workspace.setExpanded("node-1", true)
    #expect(workspace.layerRows.map(\.depth) == [0, 1, 2])
}

@Test(arguments: [UInt64(1), 7, 42, 2026, 0xDEAD_BEEF])
func seededFuzzRowsFollowTheExpandedSet(seed: UInt64) throws {
    var rng = SplitMix64(state: seed)
    var workspace = DesignWorkspace()
    workspace.newFile()
    for _ in 0..<400 {
        let nodes = allNodes(workspace)
        let pick = nodes.isEmpty ? "missing" : nodes[rng.next(below: nodes.count)].id
        switch rng.next(below: 7) {
        case 0:
            let containers = (workspace.selectedPage?.nodes ?? []).flatMap { [$0] + $0.children }
                .filter(\.kind.holdsChildren)
            let parent = containers.isEmpty || rng.next(below: 3) == 0 ? nil : containers[rng.next(below: containers.count)].id
            let kind = DesignNodeKind.allCases[rng.next(below: DesignNodeKind.allCases.count)]
            _ = try? workspace.addNode(kind, frame: box, in: parent)
        case 1:
            let wasExpanded = workspace.isExpanded(pick)
            try workspace.setExpanded(pick, !wasExpanded)
            #expect(workspace.isExpanded(pick) == !wasExpanded)
        case 2:
            // Two toggles put the workspace back exactly.
            let before = workspace
            try workspace.toggleExpanded(pick)
            try workspace.toggleExpanded(pick)
            #expect(workspace == before)
        case 3:
            let before = workspace
            #expect(throws: DesignTreeError.unknownID("ghost")) { try workspace.setExpanded("ghost", true) }
            #expect(workspace == before)
        case 4:
            workspace.selectItem(pick)
            #expect(workspace.selectedNodeID == pick)
            #expect(workspace.layerRows.contains { $0.id == pick })
        case 5:
            if rng.next(below: 4) == 0 { workspace.addPage() } else if let page = workspace.pages.randomElement(using: &rng) {
                workspace.selectPage(page.id)
            }
        default:
            let target = nodes.filter(\.kind.holdsChildren).randomElement(using: &rng)?.id
            _ = try? workspace.moveNode(pick, into: target)
        }
        #expect(rows(workspace) == expectedRows(workspace))
        #expect(Set(workspace.layerRows.map(\.id)).count == workspace.layerRows.count)
    }
}
