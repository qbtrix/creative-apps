// DesignDistributeTests.swift: LiveAligning, the live Align and Distribute
// (QD-V6, exact within 1e-9). Several layers align to the union of their
// frames, a locked one counting toward it but staying put; Distribute keeps the
// outer two and makes every gap equal, and refuses fewer than three; one layer
// lands exactly where today's alignLayer puts it. Runs on Linux and macOS.
import DesignModel
import Testing

/// An open file's page holding only `nodes` at the top level.
private func page(_ nodes: [DesignNode]) throws -> DesignPage {
    var page = try #require(openDesign().selectedPage)
    page.nodes = nodes
    return page
}

private func rect(_ id: String, _ frame: DesignRect, locked: Bool = false) -> DesignNode {
    DesignNode(id: id, name: id.uppercased(), kind: .rectangle, frame: frame, isLocked: locked)
}

private func frames(_ edit: DesignEdit, _ ids: [String]) -> [DesignRect?] {
    ids.map { id in edit.nodes.first { $0.id == id }?.frame }
}

/// Three 30 × 30 rectangles at x 10, 50 and 200; the middle one is the topmost.
private func threeInARow(middleLocked: Bool = false) throws -> DesignPage {
    try page([rect("l", rc(10, 30, 30, 30)), rect("m", rc(50, 20, 30, 30), locked: middleLocked), rect("r", rc(200, 40, 30, 30))])
}

@Test func severalLayersAlignToTheirUnion() throws {
    let edit = try LiveAligning().align(.left, ["l", "m", "r"], on: threeInARow())
    #expect(frames(edit, ["l", "m", "r"]) == [rc(10, 30, 30, 30), rc(10, 20, 30, 30), rc(10, 40, 30, 30)])
    #expect(edit.name == "Align Left")
    #expect(edit.selection == ["l", "m", "r"])
    #expect(edit.coalescingKey == nil)
}

@Test func aLockedLayerCountsTowardTheUnionButStays() throws {
    let page = try threeInARow(middleLocked: true)
    let left = try LiveAligning().align(.left, ["l", "m", "r"], on: page)
    #expect(frames(left, ["l", "m", "r"]) == [rc(10, 30, 30, 30), rc(50, 20, 30, 30), rc(10, 40, 30, 30)])
    // The locked layer is the topmost, so Align Top only reaches y 20 through it.
    let top = try LiveAligning().align(.top, ["l", "m", "r"], on: page)
    #expect(frames(top, ["l", "m", "r"]) == [rc(10, 20, 30, 30), rc(50, 20, 30, 30), rc(200, 20, 30, 30)])
}

@Test func onlyLockedLayersRefuse() throws {
    let page = try page([rect("m", rc(50, 20, 30, 30), locked: true), rect("n", rc(90, 20, 30, 30), locked: true)])
    #expect(throws: DesignRefusal.locked("M")) { try LiveAligning().align(.left, ["m", "n"], on: page) }
    #expect(LiveAligning().alignHelp(.left, ["m", "n"], on: page) == "Unlock M to change it.")
}

@Test func distributeSpacesTheInnerLayersEqually() throws {
    // Widths 20, 40, 20 spanning 0…300, passed out of order.
    let page = try page([rect("first", rc(0, 0, 20, 20)), rect("inner", rc(30, 0, 40, 20)), rect("last", rc(280, 0, 20, 20))])
    let edit = try LiveAligning().distribute(.horizontal, ["inner", "last", "first"], on: page)
    let placed = try frames(edit, ["first", "inner", "last"]).map { try #require($0) }
    #expect(placed[0] == rc(0, 0, 20, 20))
    #expect(placed[2] == rc(280, 0, 20, 20))
    let gaps = [placed[1].x - placed[0].maxX, placed[2].x - placed[1].maxX]
    #expect(abs(gaps[0] - 110) <= 1e-9)
    #expect(abs(gaps[0] - gaps[1]) <= 1e-9)
    #expect(edit.name == "Distribute Horizontally")
    #expect(LiveAligning().distributeHelp(.horizontal, ["inner", "last", "first"], on: page) == nil)
}

@Test func distributeNeedsThreeLayers() throws {
    let page = try page([rect("a", rc(0, 0, 20, 20)), rect("b", rc(100, 0, 20, 20))])
    #expect(throws: DesignRefusal.tooFewToDistribute) { try LiveAligning().distribute(.horizontal, ["a", "b"], on: page) }
    #expect(LiveAligning().distributeHelp(.vertical, ["a", "b"], on: page) == "Select three or more layers to distribute.")
}

@Test func alignTopOnTheCardsRow() throws {
    // cards' Desktop frame holding A (100, 100, 100 × 80), B (300, 140, 200 × 80) and C (700, 100, 100 × 120).
    let desktop = DesignNode(
        id: "desktop", name: "Desktop", kind: .frame, frame: rc(0, 0, 1440, 1024),
        children: [rect("a", rc(100, 100, 100, 80)), rect("b", rc(300, 140, 200, 80)), rect("c", rc(700, 100, 100, 120))])
    let edit = try LiveAligning().align(.top, ["a", "b", "c"], on: page([desktop]))
    let row = edit.nodes.first?.children.map(\.frame)
    #expect(row == [rc(100, 100, 100, 80), rc(300, 100, 200, 80), rc(700, 100, 100, 120)])
    #expect(edit.name == "Align Top")
}

/// Desktop holds a 400 × 300 frame at 100, 50 holding a 40 × 20 rectangle (node-3), which is selected.
@Test(arguments: DesignAlignEdge.allCases)
func oneLayerLandsWhereAlignLayerPutsIt(edge: DesignAlignEdge) throws {
    var workspace = openDesign()
    try workspace.addNode(.frame, frame: rc(100, 50, 400, 300), in: "node-1")
    try workspace.addNode(.rectangle, frame: rc(150, 80, 40, 20), in: "node-2")
    let before = try #require(workspace.selectedPage)
    let edit = try LiveAligning().align(edge, ["node-3"], on: before)
    workspace.alignLayer(edge)
    let after = try #require(workspace.selectedPage)
    #expect(edit.nodes == after.nodes)
    #expect(edit.name == edge.title)
    // Already there: the write changes nothing and the help reads today's.
    #expect(throws: DesignRefusal.unchanged) { try LiveAligning().align(edge, ["node-3"], on: after) }
    #expect(LiveAligning().alignHelp(edge, ["node-3"], on: after) == workspace.alignHelp(edge))
}

@Test func oneLayerInAGroupOrAtTheTopKeepsTodaysBounds() throws {
    var workspace = openDesign()
    try workspace.addNode(.group, frame: rc(50, 50, 100, 100), in: "node-1")
    try workspace.addNode(.rectangle, frame: rc(60, 60, 20, 20), in: "node-2")
    try workspace.addNode(.rectangle, frame: rc(10, 20, 100, 50))
    for id in ["node-3", "node-4"] {
        workspace.selectItem(id)
        let edit = try LiveAligning().align(.right, [id], on: #require(workspace.selectedPage))
        workspace.alignLayer(.right)
        #expect(edit.nodes == workspace.selectedPage?.nodes)
    }
    #expect(workspace.frame("node-3") == rc(1420, 60, 20, 20))
    #expect(workspace.frame("node-4") == rc(1340, 20, 100, 50))
}
