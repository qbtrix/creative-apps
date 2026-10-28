// DesignMoveLiftTests.swift: `moveLift`, what the canvas draws a live move from: the page at
// the press, the moved run's first and last painted node, and the offset so far; nil when no
// move has moved or the moved layers aren't one run in paint order. Runs on Linux and macOS.
import DesignModel
import Testing

/// node-1 (the new file's frame) holding node-2, node-3 and node-4, side by side.
private func threeInAFrame() throws -> DesignWorkspace {
    var workspace = openDesign()
    for x in [100.0, 300, 500] { try workspace.addNode(.rectangle, frame: rc(x, 100, 100, 100), in: "node-1") }
    workspace.selectTool(.move)
    return workspace
}

@Test func aMoveLiftsItsLayerFromThePageAtThePress() throws {
    var workspace = try threeInAFrame()
    let before = try #require(workspace.selectedPage)
    #expect(workspace.moveLift == nil)
    workspace.drag(from: pt(150, 150), to: pt(150, 150))
    #expect(workspace.moveLift == nil, "a press that hasn't moved lifts nothing")
    workspace.drag(from: pt(150, 150), to: pt(170, 155))
    let lift = try #require(workspace.moveLift)
    #expect(lift.page == before)
    #expect((lift.firstID, lift.lastID) == ("node-2", "node-2"))
    #expect(lift.offset == pt(20, 5))
    #expect(workspace.frame("node-2") == rc(120, 105, 100, 100))
    workspace.endDrag()
    #expect(workspace.moveLift == nil)
}

@Test func severalLayersInOneRunLiftTogether() throws {
    var workspace = try threeInAFrame()
    try workspace.select(["node-2", "node-3"])
    workspace.drag(from: pt(150, 150), to: pt(160, 170))
    let lift = try #require(workspace.moveLift)
    #expect((lift.firstID, lift.lastID) == ("node-2", "node-3"))
    #expect(lift.offset == pt(10, 20))
}

@Test func layersSplitByAnotherInPaintOrderDoNotLift() throws {
    var workspace = try threeInAFrame()
    try workspace.select(["node-2", "node-4"])
    workspace.drag(from: pt(150, 150), to: pt(160, 170))
    #expect(workspace.frame("node-2") == rc(110, 120, 100, 100), "the move itself still happens")
    #expect(workspace.moveLift == nil)
}

@Test func aFrameLiftsWithItsChildren() throws {
    var workspace = try threeInAFrame()
    workspace.drag(from: pt(20, 20), to: pt(30, 20))
    let lift = try #require(workspace.moveLift)
    #expect((lift.firstID, lift.lastID) == ("node-1", "node-4"))
    #expect(lift.offset == pt(10, 0))
}
