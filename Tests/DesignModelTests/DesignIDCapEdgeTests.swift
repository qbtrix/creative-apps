// DesignIDCapEdgeTests.swift: more ways to reach #296's duplicate id after
// opening a file whose ids sit at the 1e9 cap: a drawing tool, a node nested
// deep in a frame holding the next id, undo and redo between adds, and seeded
// random sessions. After every step the ids stay unique and Save works. Runs
// on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
@testable import DesignModel
import Testing

private func nodeIDs(_ workspace: DesignWorkspace) -> [String] {
    func ids(_ nodes: [DesignNode]) -> [String] { nodes.flatMap { [$0.id] + ids($0.children) } }
    return workspace.pages.flatMap { ids($0.nodes) }
}

/// Every page and node id is unique and the document saves.
private func expectSaves(_ workspace: DesignWorkspace) {
    let all = workspace.pages.map(\.id) + nodeIDs(workspace)
    #expect(Set(all).count == all.count, "duplicate ids: \(all)")
    #expect(throws: Never.self) { _ = try workspace.fileData() }
}

private func node(_ id: String, _ kind: DesignNodeKind = .frame, _ children: [DesignNode] = []) -> DesignNode {
    var node = DesignNode(id: id, name: id, kind: kind, frame: rc(0, 0, 100, 100))
    node.children = children
    return node
}

/// page-999999999 and page-1000000000; node-999999999 holds node-1000000000, which holds node-1000000001.
private func nearTheCap() -> DesignWorkspace {
    var first = DesignPage(id: "page-999999999", name: "A", frameWidth: 1440, frameHeight: 1024)
    first.nodes = [node("node-999999999", .frame, [node("node-1000000000", .frame, [node("node-1000000001", .rectangle)])])]
    var second = DesignPage(id: "page-1000000000", name: "B", frameWidth: 1440, frameHeight: 1024)
    second.nodes = [node("node-1000000002")]
    var workspace = DesignWorkspace()
    workspace.load([first, second])
    return workspace
}

@Test func aDrawingToolNearTheCapSkipsNestedIdsAndSaves() {
    var workspace = nearTheCap()
    workspace.gesture(.rectangle, pt(500, 500), pt(600, 600))
    #expect(workspace.selectedNodeID == "node-1000000003")
    expectSaves(workspace)
    workspace.undo()
    workspace.redo()
    #expect(workspace.selectedNodeID == "node-1000000003")
    expectSaves(workspace)
}

@Test func addPageAfterUndoNearTheCapNeverRepeatsAnId() {
    var workspace = nearTheCap()
    workspace.addPage()
    workspace.undo()
    workspace.addPage()
    workspace.undo()
    workspace.redo()
    expectSaves(workspace)
    workspace.addPage()
    expectSaves(workspace)
    #expect(workspace.pages.count == 4)
}

private struct SplitMix64: RandomNumberGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func next(below bound: Int) -> Int { Int(next() % UInt64(Swift.max(bound, 1))) }
}

@Test(arguments: 0..<20 as Range<UInt64>)
func randomSessionsNearTheCapAlwaysSave(seed: UInt64) {
    var rng = SplitMix64(state: seed)
    var workspace = nearTheCap()
    let tools: [DesignTool] = [.frame, .rectangle, .ellipse]
    for _ in 0..<40 {
        switch rng.next(below: 6) {
        case 0: workspace.addPage()
        case 1: _ = try? workspace.addNode(.rectangle, frame: rc(10, 10, 20, 20))
        case 2: workspace.undo()
        case 3: workspace.redo()
        case 4:
            let x = Double(rng.next(below: 1200))
            workspace.gesture(tools[rng.next(below: tools.count)], pt(x, x / 2), pt(x + 40, x / 2 + 30))
        default:
            if let page = workspace.pages.randomElement(using: &rng) { workspace.selectPage(page.id) }
        }
        expectSaves(workspace)
    }
}
