// FlareEllipseMinimumTests.swift: the Ellipse tool's minimum box. A drag
// narrower or shorter than `minimumEllipseExtent` (a click with pointer
// jitter) adds no layer, no draft and no undo step; a box at the minimum in
// both axes commits. Runs on Linux and macOS.
import FlareCore
import FlareModel
import Testing

private func ellipseWorkspace() -> FlareWorkspace {
    var workspace = FlareWorkspace()
    workspace.newDocument()
    workspace.selectTool(.ellipse)
    return workspace
}

private let below = FlareWorkspace.minimumEllipseExtent * 0.5

@Test(arguments: [
    (Point(x: 10, y: 10), Point(x: 10 + below, y: 80)),
    (Point(x: 10, y: 10), Point(x: 80, y: 10 + below)),
    (Point(x: 10, y: 10), Point(x: 10 - below, y: 10 + below)),
])
func aSubMinimumBoxCommitsNothing(start: Point, end: Point) {
    var workspace = ellipseWorkspace()
    workspace.addLayer()
    let before = workspace.document
    let undoName = workspace.undoActionName
    #expect(FlareWorkspace.ellipse(from: start, to: end) == nil)
    workspace.dragChanged(from: start, to: end)
    #expect(workspace.draft == nil)
    workspace.drag(from: start, to: end)
    #expect(workspace.document == before)
    #expect(workspace.undoActionName == undoName)
    #expect(workspace.layerError == nil)
}

@Test func aBoxAtTheMinimumCommitsOneUndoStep() throws {
    var workspace = ellipseWorkspace()
    let m = FlareWorkspace.minimumEllipseExtent
    let start = Point(x: 10, y: 10), end = Point(x: 10 + m, y: 10 - m)
    let shape = try #require(FlareWorkspace.ellipse(from: start, to: end))
    workspace.drag(from: start, to: end)
    #expect(workspace.layers.map(\.name) == ["Ellipse 1"])
    #expect(workspace.layers.first?.shapes == [shape])
    #expect(workspace.undoActionName == "Undo Add Ellipse")
    workspace.undo()
    #expect(workspace.layers.isEmpty)
    #expect(!workspace.canUndo)
}
