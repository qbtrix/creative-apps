// DesignMarqueeMarksTests.swift: while a marquee drag is live the canvas draws no
// selection handles (showsSelectionHandles is false), only the marquee and an
// outline on each layer it touches; once the drag ends the box's handles come
// back. A locked layer or an empty selection keeps them off. Runs on Linux and macOS.
import DesignModel
import Testing

@Test func aLiveMarqueeHidesTheSelectionHandlesUntilTheDragEnds() {
    var model = DesignFixtures.cards
    let (start, end) = (DesignPoint(x: 80, y: 80), DesignPoint(x: 520, y: 240))
    model.drag(from: start, to: start)
    model.drag(from: start, to: end)
    #expect(model.marquee != nil)
    #expect(model.selectedNodeIDs == ["node-2", "node-3"])
    #expect(model.transformHelp == nil)
    #expect(!model.showsSelectionHandles)
    model.endDrag()
    #expect(model.marquee == nil)
    #expect(model.selectedNodeIDs == ["node-2", "node-3"])
    #expect(model.showsSelectionHandles)
}

@Test func oneLayerShowsHandlesUnlessLockedOrNothingIsSelected() throws {
    var model = DesignFixtures.cards
    model.selectItem("node-2")
    #expect(model.showsSelectionHandles)
    try model.setNodeLocked("node-2", true)
    #expect(!model.showsSelectionHandles)
    model.deselect()
    #expect(!model.showsSelectionHandles)
}
