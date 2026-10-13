// DesignMoveNodeExpansionEdgeTests.swift: adversarial and seeded-fuzz checks on
// moveNode's expansion. A successful move adds exactly the moved node's
// ancestors to the expanded set and leaves every other row's state alone; a
// refused move changes nothing; a selected node inside a moved container keeps
// its row. Runs on Linux and macOS.
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

private func walk(_ nodes: [DesignNode]) -> [DesignNode] { nodes.flatMap { [$0] + walk($0.children) } }

/// The ids enclosing `id` on whichever page holds it; nil when no page does.
private func ancestors(of id: String, in workspace: DesignWorkspace) -> [String]? {
    func path(_ nodes: [DesignNode]) -> [String]? {
        for node in nodes {
            if node.id == id { return [] }
            if let rest = path(node.children) { return [node.id] + rest }
        }
        return nil
    }
    return workspace.pages.lazy.compactMap { path($0.nodes) }.first
}

@Test func movingAContainerKeepsTheSelectedDescendantsRow() throws {
    var workspace = DesignWorkspace()
    workspace.newFile()
    let outer = try workspace.addNode(.group, frame: box, in: "node-1")
    let inner = try workspace.addNode(.group, frame: box, in: outer)
    let carried = try workspace.addNode(.group, frame: box)
    let selected = try workspace.addNode(.ellipse, frame: box, in: carried)
    for id in ["node-1", outer, inner] { try workspace.setExpanded(id, false) }
    try workspace.moveNode(carried, into: inner)
    #expect(workspace.selectedNodeID == selected)
    #expect(workspace.layerRows.map(\.id) == ["node-1", outer, inner, carried, selected])
    #expect(workspace.layerRows.map(\.depth) == [0, 1, 2, 3, 4])
}

@Test func movingKeepsTheMovedContainersOwnCollapsedState() throws {
    var workspace = DesignWorkspace()
    workspace.newFile()
    let group = try workspace.addNode(.group, frame: box)
    try workspace.addNode(.text, frame: box, in: group)
    try workspace.setExpanded(group, false)
    try workspace.setExpanded("node-1", false)
    try workspace.moveNode(group, into: "node-1")
    #expect(workspace.isExpanded("node-1"))
    #expect(!workspace.isExpanded(group))
    #expect(workspace.layerRows.map(\.id) == ["node-1", group])
}

@Test func reMovingIntoTheSameCollapsedParentExpandsIt() throws {
    var workspace = DesignWorkspace()
    workspace.newFile()
    let first = try workspace.addNode(.rectangle, frame: box, in: "node-1")
    let second = try workspace.addNode(.rectangle, frame: box, in: "node-1")
    try workspace.setExpanded("node-1", false)
    try workspace.moveNode(first, into: "node-1")
    #expect(workspace.layerRows.map(\.id) == ["node-1", first, second])
}

@Test func movingOnAnotherPageExpandsThereAndLeavesTheSelectionAlone() throws {
    var workspace = DesignWorkspace()
    workspace.newFile()
    let group = try workspace.addNode(.group, frame: box, in: "node-1")
    let loose = try workspace.addNode(.rectangle, frame: box)
    for id in ["node-1", group] { try workspace.setExpanded(id, false) }
    workspace.addPage()
    let other = try workspace.addNode(.text, frame: box)
    try workspace.moveNode(loose, into: group)
    #expect(workspace.selectedPageID == "page-2")
    #expect(workspace.selectedNodeID == other)
    #expect(workspace.layerRows.map(\.id) == [other, "node-4"])
    workspace.selectPage("page-1")
    #expect(workspace.layerRows.map(\.id) == ["node-1", group, loose])
}

@Test func refusedMovesChangeNothing() throws {
    var workspace = DesignWorkspace()
    workspace.newFile()
    let group = try workspace.addNode(.group, frame: box, in: "node-1")
    let rect = try workspace.addNode(.rectangle, frame: box, in: group)
    let label = try workspace.addNode(.text, frame: box)
    workspace.addPage()
    let farFrame = try workspace.addNode(.frame, frame: box)
    workspace.selectItem(rect)
    for id in ["node-1", group, farFrame] { try workspace.setExpanded(id, false) }
    let before = workspace
    // A container on another page, a non-container, an unknown parent, an unknown node, itself.
    #expect(throws: DesignTreeError.unknownID(farFrame)) { try workspace.moveNode(rect, into: farFrame) }
    #expect(throws: DesignTreeError.notAContainer(label)) { try workspace.moveNode(rect, into: label) }
    #expect(throws: DesignTreeError.unknownID("ghost")) { try workspace.moveNode(rect, into: "ghost") }
    #expect(throws: DesignTreeError.unknownID("ghost")) { try workspace.moveNode("ghost", into: group) }
    #expect(throws: DesignTreeError.intoItself(group)) { try workspace.moveNode(group, into: group) }
    #expect(workspace == before)
}

@Test(arguments: [UInt64(3), 11, 99, 2026, 0xC0FF_EE00])
func seededFuzzAMoveExpandsExactlyTheMovedNodesAncestors(seed: UInt64) throws {
    var rng = SplitMix64(state: seed)
    var workspace = DesignWorkspace()
    workspace.newFile()
    for _ in 0..<500 {
        let nodes = workspace.pages.flatMap { walk($0.nodes) }
        guard !nodes.isEmpty else { break }
        let pick = nodes[rng.next(below: nodes.count)].id
        switch rng.next(below: 5) {
        case 0:
            let containers = walk(workspace.selectedPage?.nodes ?? []).filter(\.kind.holdsChildren)
            let parent = containers.isEmpty || rng.next(below: 4) == 0 ? nil : containers[rng.next(below: containers.count)].id
            let kind = DesignNodeKind.allCases[rng.next(below: DesignNodeKind.allCases.count)]
            _ = try? workspace.addNode(kind, frame: box, in: parent)
        case 1:
            try workspace.setExpanded(pick, rng.next(below: 4) != 0 ? false : true)
        case 2:
            if rng.next(below: 5) == 0 { workspace.addPage() } else { workspace.selectItem(pick) }
        default:
            let target = rng.next(below: 5) == 0 ? nil : nodes[rng.next(below: nodes.count)].id
            let before = workspace
            do {
                try workspace.moveNode(pick, into: target)
            } catch {
                #expect(workspace == before)
                continue
            }
            let path = ancestors(of: pick, in: workspace) ?? []
            #expect(path.last == target)
            #expect(workspace.expandedNodeIDs == before.expandedNodeIDs.union(path))
            #expect(workspace.selectedPageID == before.selectedPageID)
            #expect(workspace.selectedNodeID == before.selectedNodeID)
            if workspace.selectedPage.map({ walk($0.nodes).contains { $0.id == pick } }) == true {
                #expect(workspace.layerRows.contains { $0.id == pick })
            }
        }
    }
}
