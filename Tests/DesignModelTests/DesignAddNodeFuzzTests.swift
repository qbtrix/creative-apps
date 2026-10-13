// DesignAddNodeFuzzTests.swift: adversarial and seeded-fuzz checks on
// DesignWorkspace.addNode. Every refused add leaves the workspace equal to
// before; every accepted add takes the next id, unique across pages. Runs on
// Linux and macOS.
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

/// Every node id on every page, nested ones included.
private func allIDs(_ workspace: DesignWorkspace) -> [String] {
    func walk(_ nodes: [DesignNode]) -> [String] { nodes.flatMap { [$0.id] + walk($0.children) } }
    return workspace.pages.flatMap { walk($0.nodes) }
}

@Test func addIntoAParentOnAnotherPageIsRefusedAndChangesNothing() throws {
    var workspace = DesignWorkspace()
    workspace.newFile()
    workspace.addPage()
    let before = workspace
    #expect(workspace.selectedPageID == "page-2")
    #expect(throws: DesignTreeError.unknownID("node-1")) { try workspace.addNode(.text, frame: box, in: "node-1") }
    #expect(workspace == before)
    #expect(try workspace.addNode(.text, frame: box) == "node-3")
}

@Test func aRefusedAddKeepsTheSelectionAndExpandedRows() throws {
    var workspace = DesignWorkspace()
    workspace.newFile()
    let group = try workspace.addNode(.group, frame: box, in: "node-1")
    let leaf = try workspace.addNode(.rectangle, frame: box, in: group)
    let before = workspace
    for parent in [leaf, "", "node-99", "page-1"] {
        #expect(throws: (any Error).self) { try workspace.addNode(.frame, frame: box, in: parent) }
    }
    #expect(workspace == before)
    #expect(workspace.selectedNodeID == leaf)
    #expect(workspace.expandedNodeIDs == ["node-1", group])
}

@Test func idsStayUniqueAfterRefusedAddsAndPageDeletion() throws {
    var workspace = DesignWorkspace()
    workspace.newFile()
    workspace.addPage()
    let onPage2 = try workspace.addNode(.frame, frame: box)
    _ = try? workspace.addNode(.text, frame: box, in: "node-1")
    try workspace.deletePage("page-2")
    let next = try workspace.addNode(.text, frame: box, in: "node-1")
    #expect(next != onPage2)
    #expect(next == "node-4")
}

@Test(arguments: [UInt64(1), 7, 42, 2026, 0xDEAD_BEEF])
func fuzzedAddsMatchASequentialCounter(seed: UInt64) throws {
    var rng = SplitMix64(state: seed)
    var workspace = DesignWorkspace()
    workspace.newFile()
    var accepted = 1  // the Desktop frame
    for _ in 0..<300 {
        switch rng.next(below: 10) {
        case 0:
            workspace.addPage()
            accepted += 1  // its Desktop frame
        case 1:
            if let page = workspace.pages.randomElement(using: &rng) { workspace.selectPage(page.id) }
        default:
            let ids = allIDs(workspace)
            let candidates: [String?] = [nil, "nope", "page-1", ""] + ids.map(Optional.some)
            let parent = candidates[rng.next(below: candidates.count)]
            let kind = DesignNodeKind.allCases[rng.next(below: DesignNodeKind.allCases.count)]
            let before = workspace
            do {
                let id = try workspace.addNode(kind, frame: box, in: parent)
                accepted += 1
                #expect(id == "node-\(accepted)", "seed \(seed)")
                #expect(workspace.selectedNodeID == id)
                #expect(workspace.selectedPage?.nodes.isEmpty == false)
            } catch {
                #expect(workspace == before, "seed \(seed): refused add into \(parent ?? "nil") changed the workspace")
            }
        }
    }
    let ids = allIDs(workspace)
    #expect(ids.count == accepted)
    #expect(Set(ids).count == ids.count)
}
