// DesignIDRunEdgeTests.swift: adversarial cases for one-pass id minting past a long
// run of held ids (#304): runs nested in children, runs a page's ids continue,
// repeated adds, undo and redo, a drawing stroke, save and reopen. Every minted id
// stays unique and the first free one. Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
@testable import DesignModel
import Testing

private let cap = 999_999_999
private let run = 5_000

private func everyID(_ workspace: DesignWorkspace) -> [String] {
    func ids(_ nodes: [DesignNode]) -> [String] { nodes.flatMap { [$0.id] + ids($0.children) } }
    return workspace.pages.map(\.id) + workspace.pages.flatMap { ids($0.nodes) }
}

private func rect(_ id: String) -> DesignNode {
    DesignNode(id: id, name: "R", kind: .rectangle, frame: rc(0, 0, 10, 10))
}

/// One page whose node ids run from "node-999999999" for `run` numbers, the second half
/// nested as children of a frame, and a second page whose id is node-shaped and ends the run.
private func openNestedRun() -> DesignWorkspace {
    var frame = DesignNode(id: "node-\(cap)", name: "F", kind: .frame, frame: rc(0, 0, 800, 600))
    frame.children = (run / 2..<run).map { rect("node-\(cap + $0)") }
    var page = DesignPage(id: "page-1", name: "A", frameWidth: 800, frameHeight: 600)
    page.nodes = [frame] + (1..<run / 2).map { rect("node-\(cap + $0)") }
    let tail = DesignPage(id: "node-\(cap + run)", name: "B", frameWidth: 800, frameHeight: 600)
    var workspace = DesignWorkspace()
    workspace.load([page, tail])
    return workspace
}

private func expectUnique(_ workspace: DesignWorkspace) {
    let ids = everyID(workspace)
    #expect(Set(ids).count == ids.count)
}

@Test func addNodeSkipsARunNestedInChildrenAndEndingOnAPageID() throws {
    var workspace = openNestedRun()
    let id = try workspace.addNode(.rectangle, frame: rc(0, 0, 10, 10))
    #expect(id == "node-\(cap + run + 1)")
    expectUnique(workspace)
}

@Test func repeatedAddsPastARunStayUniqueSequentialAndQuick() throws {
    var workspace = openNestedRun()
    let start = ContinuousClock.now
    var minted: [String] = []
    for _ in 0..<50 { minted.append(try workspace.addNode(.ellipse, frame: rc(0, 0, 4, 4))) }
    workspace.addPage()
    let elapsed = ContinuousClock.now - start
    #expect(elapsed < .seconds(5))
    #expect(minted == (1...50).map { "node-\(cap + run + $0)" })
    #expect(workspace.pages.last?.id == "page-2")
    #expect(workspace.pages.last?.nodes.map(\.id) == ["node-\(cap + run + 51)"])
    expectUnique(workspace)
}

@Test func undoneAddsPastARunNeverHandTheirIDsOutAgain() throws {
    var workspace = openNestedRun()
    let first = try workspace.addNode(.rectangle, frame: rc(0, 0, 10, 10))
    workspace.addPage()
    let page = workspace.pages.last?.id
    workspace.undo()
    workspace.undo()
    #expect(everyID(workspace).contains(first) == false)
    workspace.addPage()
    let second = try workspace.addNode(.rectangle, frame: rc(0, 0, 10, 10))
    #expect(workspace.pages.last?.id != page)
    #expect(second != first)
    #expect(second == "node-\(cap + run + 4)")
    workspace.undo()
    workspace.redo()
    expectUnique(workspace)
}

@Test func aDrawingStrokePastARunKeepsOneUnusedIDAcrossItsMoves() throws {
    var workspace = openNestedRun()
    workspace.selectTool(.rectangle)
    let start = ContinuousClock.now
    for step in 1...20 {
        workspace.drag(from: DesignPoint(x: 900, y: 700), to: DesignPoint(x: 900 + Double(step), y: 700 + Double(step)))
    }
    workspace.endDrag()
    let elapsed = ContinuousClock.now - start
    #expect(elapsed < .seconds(5))
    #expect(workspace.selectedNodeID == "node-\(cap + run + 1)")
    expectUnique(workspace)
}

@Test func idsMintedPastARunSurviveSaveAndReopen() throws {
    var workspace = openNestedRun()
    _ = try workspace.addNode(.rectangle, frame: rc(0, 0, 10, 10))
    workspace.addPage()
    var reopened = DesignWorkspace()
    try reopened.open(try workspace.fileData())
    let id = try reopened.addNode(.rectangle, frame: rc(0, 0, 10, 10))
    #expect(id == "node-\(cap + run + 3)")
    expectUnique(reopened)
    _ = try reopened.fileData()
}

@Test func nonCanonicalHeldIDsNeverBlockOrCollideWithAMint() throws {
    var page = DesignPage(id: "page-1", name: "A", frameWidth: 800, frameHeight: 600)
    page.nodes = ["node-01", "node-+2", "node-3", "node- 4", "node-", "node-x"].map(rect)
    var workspace = DesignWorkspace()
    workspace.load([page])
    let ids = try (0..<3).map { _ in try workspace.addNode(.rectangle, frame: rc(0, 0, 10, 10)) }
    #expect(ids == ["node-4", "node-5", "node-6"])
    expectUnique(workspace)
}
