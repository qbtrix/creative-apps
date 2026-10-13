// DesignHeldIDsFuzzTests.swift: seeded random edit runs against the held-id
// index (#433). After every step the index must equal a fresh scan of the pages
// and no id may appear twice, whatever order adds, deletes, undo, redo, New
// File, reopen, reparenting, Move strokes and drawing strokes (also interrupted
// mid-stroke by other edits, Move strokes included since #443) come in.
// Runs on Linux and macOS.
@testable import DesignModel
import Testing

/// A small deterministic generator, so a failing seed replays exactly.
private struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return state
    }
}

private func everyID(_ workspace: DesignWorkspace) -> [String] {
    func ids(_ nodes: [DesignNode]) -> [String] { nodes.flatMap { [$0.id] + ids($0.children) } }
    return workspace.pages.map(\.id) + workspace.pages.flatMap { ids($0.nodes) }
}

private func nodeIDs(_ workspace: DesignWorkspace) -> [String] {
    func ids(_ nodes: [DesignNode]) -> [String] { nodes.flatMap { [$0.id] + ids($0.children) } }
    return workspace.selectedPage.map { ids($0.nodes) } ?? []
}

private func expectExact(_ workspace: DesignWorkspace, _ comment: Comment) {
    let ids = everyID(workspace)
    #expect(Set(ids).count == ids.count, comment)
    #expect(workspace.held.ids == Set(ids), comment)
}

/// One random edit; returns its name for the failure message.
private func step(_ workspace: inout DesignWorkspace, _ random: inout SeededGenerator) throws -> String {
    func point() -> DesignPoint { pt(Double.random(in: -50...1500, using: &random), Double.random(in: -50...1100, using: &random)) }
    let nodes = nodeIDs(workspace)
    switch Int.random(in: 0..<14, using: &random) {
    case 0, 1:
        let kind = [DesignNodeKind.frame, .rectangle, .ellipse, .text].randomElement(using: &random) ?? .frame
        let parent = nodes.filter { workspace.treeNode($0)?.kind == .frame }.randomElement(using: &random)
        _ = try? workspace.addNode(kind, frame: rc(10, 10, 40, 40), in: parent)
        return "add"
    case 2:
        workspace.addPage()
        return "add page"
    case 3:
        if let id = nodes.randomElement(using: &random) { workspace.selectItem(id) }
        workspace.deleteSelection()
        return "delete"
    case 4:
        if let id = workspace.pages.randomElement(using: &random)?.id { try? workspace.deletePage(id) }
        return "delete page"
    case 5, 6:
        workspace.undo()
        return "undo"
    case 7:
        workspace.redo()
        return "redo"
    case 8:
        workspace.newFile()
        return "new file"
    case 9:
        let data = try workspace.fileData()
        var reopened = DesignWorkspace()
        try reopened.open(data)
        workspace = reopened
        return "reopen"
    case 10:
        if let id = nodes.randomElement(using: &random) {
            let into = nodes.filter { workspace.treeNode($0)?.kind == .frame }.randomElement(using: &random)
            try? workspace.moveNode(id, into: into)
        }
        return "reparent"
    case 11:
        workspace.gesture(.text, point(), point())
        if Bool.random(using: &random) { workspace.cancelTextEdit() } else { workspace.commitTextEdit() }
        return "text"
    default:
        let tool = [DesignTool.frame, .rectangle, .ellipse, .move].randomElement(using: &random) ?? .move
        workspace.selectTool(tool)
        let start = point()
        for _ in 0..<Int.random(in: 1...6, using: &random) {
            workspace.drag(from: start, to: point())
            expectExact(workspace, "mid-stroke")
            // An edit that lands while a stroke is still going, Move included (#443).
            switch Int.random(in: 0..<8, using: &random) {
            case 0: workspace.addPage()
            case 1: workspace.deleteSelection()
            case 2: workspace.undo()
            case 3: _ = try? workspace.addNode(.rectangle, frame: rc(0, 0, 5, 5))
            default: break
            }
        }
        workspace.endDrag()
        return "stroke \(tool)"
    }
}

@Test(arguments: 1...8)
func randomEditRunsKeepTheIndexExact(seed: Int) throws {
    var random = SeededGenerator(state: UInt64(seed))
    var workspace = openDesign()
    for index in 0..<400 {
        let name = try step(&workspace, &random)
        expectExact(workspace, "seed \(seed), step \(index): \(name)")
    }
}

@Test func anAddPageInTheMiddleOfADrawingStrokeLeavesTheIndexExact() {
    var workspace = openDesign()
    workspace.selectTool(.rectangle)
    workspace.drag(from: pt(100, 100), to: pt(150, 150))
    workspace.addPage()
    expectExact(workspace, "after Add Page mid-stroke")
    workspace.drag(from: pt(100, 100), to: pt(160, 160))
    expectExact(workspace, "after the next move")
    workspace.endDrag()
    expectExact(workspace, "after the stroke")
    workspace.undo()
    expectExact(workspace, "after undo")
    workspace.addPage()
    expectExact(workspace, "after a later Add Page")
}

@Test func aDeleteInTheMiddleOfAMoveDragKeepsTheIndexExact() throws {
    var workspace = openDesign()
    let id = try workspace.addNode(.rectangle, frame: rc(10, 10, 40, 40))
    workspace.selectTool(.move)
    workspace.drag(from: pt(20, 20), to: pt(30, 30))
    workspace.deleteSelection()
    workspace.drag(from: pt(20, 20), to: pt(40, 40))
    workspace.endDrag()
    #expect(workspace.held.ids.contains(id))
    expectExact(workspace, "after the move")
}
