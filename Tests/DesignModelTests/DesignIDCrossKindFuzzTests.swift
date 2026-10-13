// DesignIDCrossKindFuzzTests.swift: seeded fuzz on #303. A file whose page ids
// look like "node-N" and node ids look like "page-N" (in any mix, nested, near
// the counters and past the cap) goes through random Add Page, Add Node, drawing,
// Delete Page, New File, Undo and Redo, and Save validates after every step.
// Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
@testable import DesignModel
import Testing

/// SplitMix64, so a failing seed replays exactly.
private struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// Ids a counter would reach soon, of both kinds, plus ones past the cap.
private let pool: [String] =
    (1...8).flatMap { ["page-\($0)", "node-\($0)"] } + ["page-999999999", "node-999999999", "node-1000000000", "page-x"]

/// A valid document: every page and node id unique across both kinds, ids drawn from `pool`.
private func randomPages(_ rng: inout SeededGenerator) -> [DesignPage] {
    var free = pool.shuffled(using: &rng)
    func take() -> String? { free.popLast() }
    var pages: [DesignPage] = []
    for _ in 0..<Int.random(in: 1...3, using: &rng) {
        guard let id = take() else { break }
        var page = DesignPage(id: id, name: "P", frameWidth: 800, frameHeight: 600)
        for _ in 0..<Int.random(in: 0...3, using: &rng) {
            guard let nodeID = take() else { break }
            var node = DesignNode(id: nodeID, name: "F", kind: .frame, frame: rc(0, 0, 400, 400))
            if Bool.random(using: &rng), let childID = take() {
                node.children = [DesignNode(id: childID, name: "R", kind: .rectangle, frame: rc(10, 10, 20, 20))]
            }
            page.nodes.append(node)
        }
        pages.append(page)
    }
    return pages
}

/// Every page and node id in the document, children included.
private func allIDs(_ workspace: DesignWorkspace) -> [String] {
    func ids(_ nodes: [DesignNode]) -> [String] { nodes.flatMap { [$0.id] + ids($0.children) } }
    return workspace.pages.flatMap { [$0.id] + ids($0.nodes) }
}

@Test(arguments: 0..<200)
func crossKindIDsSurviveRandomEditsAndSave(seed: UInt64) throws {
    var rng = SeededGenerator(state: seed)
    var source = DesignWorkspace()
    source.load(randomPages(&rng))
    var workspace = DesignWorkspace()
    // Through the real codec, as File > Open reads it.
    try workspace.open(try source.fileData())
    for _ in 0..<40 {
        switch Int.random(in: 0..<9, using: &rng) {
        case 0: workspace.addPage()
        case 1, 2:
            let parent = Bool.random(using: &rng) ? workspace.selectedPage?.nodes.first(where: { $0.kind == .frame })?.id : nil
            _ = try? workspace.addNode(.rectangle, frame: rc(1, 1, 5, 5), in: parent)
        case 3: workspace.gesture(.ellipse, pt(5, 5), pt(50, 50))
        case 4: if let id = workspace.selectedPageID { try? workspace.deletePage(id) }
        case 5, 6: workspace.undo()
        case 7: workspace.redo()
        default:
            if let id = workspace.pages.randomElement(using: &rng)?.id { workspace.selectPage(id) }
        }
        let ids = allIDs(workspace)
        #expect(Set(ids).count == ids.count, "seed \(seed): \(ids)")
        let data = try workspace.fileData()
        var reopened = DesignWorkspace()
        try reopened.open(data)
    }
}

/// Every cross-kind id a counter could hit next, at once: Add Page and Add Node walk past all of them.
@Test func mintingWalksPastARunOfCrossKindIDs() throws {
    var page = DesignPage(id: "node-2", name: "A", frameWidth: 800, frameHeight: 600)
    page.nodes = [
        DesignNode(id: "page-1", name: "E", kind: .frame, frame: rc(0, 0, 100, 100)),
        DesignNode(id: "page-2", name: "F", kind: .frame, frame: rc(0, 0, 100, 100)),
        DesignNode(id: "page-3", name: "G", kind: .frame, frame: rc(0, 0, 100, 100)),
    ]
    var other = DesignPage(id: "node-3", name: "B", frameWidth: 800, frameHeight: 600)
    other.nodes = [DesignNode(id: "node-1", name: "H", kind: .frame, frame: rc(0, 0, 100, 100))]
    var workspace = DesignWorkspace()
    workspace.load([page, other])
    workspace.addPage()
    #expect(workspace.pages.last?.id == "page-4")
    #expect(workspace.pages.last?.nodes.map(\.id) == ["node-4"])
    let id = try workspace.addNode(.rectangle, frame: rc(0, 0, 5, 5))
    #expect(id == "node-5")
    _ = try workspace.fileData()
}

/// Undoing Delete Page brings back a page whose id Add Node could have taken while it was gone.
@Test func undoingDeletePageNeverCollidesWithANodeAddedSince() throws {
    var page = DesignPage(id: "node-2", name: "A", frameWidth: 800, frameHeight: 600)
    page.nodes = [DesignNode(id: "node-1", name: "F", kind: .frame, frame: rc(0, 0, 100, 100))]
    let keep = DesignPage(id: "page-1", name: "B", frameWidth: 800, frameHeight: 600)
    var workspace = DesignWorkspace()
    workspace.load([page, keep])
    try workspace.deletePage("node-2")
    _ = try workspace.addNode(.rectangle, frame: rc(0, 0, 5, 5))
    workspace.undo()
    workspace.undo()
    #expect(workspace.pages.map(\.id) == ["node-2", "page-1"])
    _ = try workspace.fileData()
    let id = try workspace.addNode(.rectangle, frame: rc(0, 0, 5, 5))
    #expect(id != "node-2")
    _ = try workspace.fileData()
    workspace.redo()
    _ = try workspace.fileData()
}
