// DesignMoveLiftTests.swift: `moveLift`, what the canvas draws a live move from: the page at
// the press, the moved run's first and last painted node, and the offset so far; nil when no
// move has moved or the moved layers aren't one run in paint order. An Option-drag lifts its copies from
// the page with the copies made in place. Runs on Linux and macOS.
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
    workspace.drag(from: pt(150, 150), to: pt(170, 155), modifiers: .noSnap)
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
    workspace.drag(from: pt(150, 150), to: pt(160, 170), modifiers: .noSnap)
    let lift = try #require(workspace.moveLift)
    #expect((lift.firstID, lift.lastID) == ("node-2", "node-3"))
    #expect(lift.offset == pt(10, 20))
}

@Test func layersSplitByAnotherInPaintOrderDoNotLift() throws {
    var workspace = try threeInAFrame()
    try workspace.select(["node-2", "node-4"])
    workspace.drag(from: pt(150, 150), to: pt(160, 170), modifiers: .noSnap)
    #expect(workspace.frame("node-2") == rc(110, 120, 100, 100), "the move itself still happens")
    #expect(workspace.moveLift == nil)
}

@Test func aFrameLiftsWithItsChildren() throws {
    var workspace = try threeInAFrame()
    workspace.selectItem("node-1")  // a press on a frame that isn't selected marquees inside it
    workspace.drag(from: pt(20, 20), to: pt(30, 20))
    let lift = try #require(workspace.moveLift)
    #expect((lift.firstID, lift.lastID) == ("node-1", "node-4"))
    #expect(lift.offset == pt(10, 0))
}

@Test func anOptionDragLiftsItsCopyFromThePageWithTheCopyInIt() throws {
    var workspace = try threeInAFrame()
    workspace.selectItem("node-2")
    let option: DesignModifiers = [.option, .noSnap]
    workspace.drag(from: pt(150, 150), to: pt(150, 150), modifiers: option)
    workspace.drag(from: pt(150, 150), to: pt(170, 155), modifiers: option)
    let copy = try #require(workspace.selectedNodeID)
    #expect(copy != "node-2")
    let lift = try #require(workspace.moveLift, "an Option-drag repaints the whole page every step")
    #expect((lift.firstID, lift.lastID) == (copy, copy))
    #expect(lift.offset == pt(20, 5))
    // The copy sits where it was made, over the original, which stays put.
    let shown = try #require(lift.page.nodes.first?.children)
    #expect(shown.first { $0.id == copy }?.frame == rc(100, 100, 100, 100))
    #expect(shown.first { $0.id == "node-2" }?.frame == rc(100, 100, 100, 100))
    #expect(workspace.frame(copy) == rc(120, 105, 100, 100))
    workspace.endDrag()
    #expect(workspace.moveLift == nil)
}
