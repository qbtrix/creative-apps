// DesignIDRunTests.swift: a file holding a long contiguous run of page and node
// ids at and past the 1e9 cap. Add Page and Add Node skip the whole run in one
// pass over the held ids, so the first add is instant, not quadratic (#304).
// Runs on Linux and macOS.
@testable import DesignModel
import Testing

private let runLength = 20_000

private func allIDs(_ workspace: DesignWorkspace) -> [String] {
    func ids(_ nodes: [DesignNode]) -> [String] { nodes.flatMap { [$0.id] + ids($0.children) } }
    return workspace.pages.map(\.id) + workspace.pages.flatMap { ids($0.nodes) }
}

/// A page "page-999999999" holding nodes "node-999999999" through the run's end, and a
/// second page whose id starts a run of page ids, all at or past the cap.
private func openLongRun() -> DesignWorkspace {
    let cap = 999_999_999
    var first = DesignPage(id: "page-\(cap)", name: "A", frameWidth: 800, frameHeight: 600)
    first.nodes = (0..<runLength).map {
        DesignNode(id: "node-\(cap + $0)", name: "R", kind: .rectangle, frame: rc(0, 0, 10, 10))
    }
    let pages = [first] + (1..<runLength / 10).map {
        DesignPage(id: "page-\(cap + $0)", name: "P", frameWidth: 800, frameHeight: 600)
    }
    var workspace = DesignWorkspace()
    workspace.load(pages)
    return workspace
}

@Test func addPagePastALongRunMintsUnusedIDsQuickly() throws {
    var workspace = openLongRun()
    let start = ContinuousClock.now
    workspace.addPage()
    let elapsed = ContinuousClock.now - start
    #expect(elapsed < .seconds(1))
    let ids = allIDs(workspace)
    #expect(Set(ids).count == ids.count)
    #expect(workspace.pages.last?.id == "page-\(999_999_999 + runLength / 10)")
    #expect(workspace.pages.last?.nodes.map(\.id) == ["node-\(999_999_999 + runLength)"])
}

@Test func addNodePastALongRunMintsAnUnusedIDQuickly() throws {
    var workspace = openLongRun()
    let start = ContinuousClock.now
    let id = try workspace.addNode(.rectangle, frame: rc(0, 0, 10, 10))
    let elapsed = ContinuousClock.now - start
    #expect(elapsed < .seconds(1))
    #expect(id == "node-\(999_999_999 + runLength)")
    let ids = allIDs(workspace)
    #expect(Set(ids).count == ids.count)
}
