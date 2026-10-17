// DesignCompactSelectionTests.swift: a small selection stays usable. Under three
// handles across on either side only the corners show, pushed outside the box,
// and a press inside the box moves it instead of grabbing a handle. Also the
// inline editor's scale and the Open guard (one file per window).
// Runs on Linux and macOS.
import DesignModel
import Testing

@Test func aLargeRectShowsEightHandlesOnItsCornersAndSides() {
    let handles = rc(0, 0, 100, 60).handles(size: 10)
    #expect(handles.count == 8)
    #expect(handles[.topLeft] == pt(0, 0))
    #expect(handles[.top] == pt(50, 0))
    #expect(handles[.right] == pt(100, 30))
    #expect(handles[.bottomRight] == pt(100, 60))
}

@Test func aCompactRectShowsOnlyItsCornersPushedOutside() {
    // 120 x 24 is under three 10-point handles tall.
    let box = rc(10, 20, 120, 24)
    #expect(box.isCompact(handleSize: 10))
    #expect(!box.isCompact(handleSize: 8))
    #expect(
        box.handles(size: 10) == [
            .topLeft: pt(5, 15), .topRight: pt(135, 15), .bottomLeft: pt(5, 49), .bottomRight: pt(135, 49),
        ])
    // Narrow but tall is compact too.
    #expect(rc(0, 0, 20, 400).handles(size: 10).keys.sorted { $0.rawValue < $1.rawValue } == [
        .bottomLeft, .bottomRight, .topLeft, .topRight,
    ])
}

@Test func aNonFiniteHandleSizeIsNeverCompact() {
    #expect(!rc(0, 0, 5, 5).isCompact(handleSize: .nan))
    #expect(rc(0, 0, 5, 5).handles(size: .nan).count == 8)
}

/// A text-sized node, selected, at a zoom where a handle is 18 document points across.
private func smallTextBox() throws -> DesignWorkspace {
    var workspace = openDesign()
    try workspace.addNode(.text, frame: rc(100, 100, 120, 24), in: "node-1")
    workspace.setHandleTolerance(18)
    return workspace
}

@Test func aPressInsideACompactNodeIsNoHandle() throws {
    let workspace = try smallTextBox()
    // The middle of the top edge would be the top handle on a large node.
    #expect(workspace.handle(at: pt(160, 101)) == nil)
    #expect(workspace.handle(at: pt(101, 112)) == nil)
    // The corners still grab, from outside and right on the corner.
    #expect(workspace.handle(at: pt(91, 91)) == .topLeft)
    #expect(workspace.handle(at: pt(100, 100)) == .topLeft)
    #expect(workspace.handle(at: pt(229, 133)) == .bottomRight)
    // No side handle anywhere.
    #expect(workspace.handle(at: pt(160, 85)) == nil)
}

@Test func aDragInsideACompactNodeMovesIt() throws {
    var workspace = try smallTextBox()
    workspace.gesture(.move, pt(160, 101), pt(170, 141))
    #expect(workspace.frame("node-2") == rc(110, 140, 120, 24))
    #expect(workspace.undoActionName == "Undo Move")
}

@Test func aCornerDragOutsideACompactNodeResizesIt() throws {
    var workspace = try smallTextBox()
    workspace.gesture(.move, pt(229, 133), pt(259, 153))
    #expect(workspace.frame("node-2") == rc(100, 100, 150, 44))
    #expect(workspace.undoActionName == "Undo Resize")
}

@Test func theTextEditorScaleFollowsTheZoom() {
    #expect(DesignWorkspace.textEditScale(zoom: 0.43) == 0.43)
    #expect(DesignWorkspace.textEditScale(zoom: 1) == 1)
    #expect(DesignWorkspace.textEditScale(zoom: 2.5) == 2.5)
    #expect(DesignWorkspace.textEditScale(zoom: 0) == 1)
    #expect(DesignWorkspace.textEditScale(zoom: -2) == 1)
    #expect(DesignWorkspace.textEditScale(zoom: .nan) == 1)
    #expect(DesignWorkspace.textEditScale(zoom: .infinity) == 1)
}

@Test func openFillsOnlyAWorkspaceWithNothingOpen() throws {
    var workspace = DesignWorkspace()
    #expect(workspace.takesOpenedFile)
    workspace.newFile()
    #expect(!workspace.takesOpenedFile)
    // Drawn on and unsaved: still never replaced.
    workspace.gesture(.rectangle, pt(10, 10), pt(60, 60))
    #expect(!workspace.takesOpenedFile)
    // Opened from a file and untouched: Open goes to a new window all the same.
    var opened = DesignWorkspace()
    try opened.open(try workspace.fileData())
    #expect(!opened.takesOpenedFile)
}
