// FlareEllipseFarBoxTests.swift: far from the origin a coordinate's spacing
// can exceed a box's radius, so centre ± radius rounds back to the centre and
// a box with positive radii makes an ellipse with no extent (#553). Such a box
// makes no ellipse: no layer, no draft and no undo step. Runs on Linux and macOS.
import FlareCore
import FlareModel
import Testing

private func ellipseWorkspace() -> FlareWorkspace {
    var workspace = FlareWorkspace()
    workspace.newDocument()
    workspace.selectTool(.ellipse)
    return workspace
}

// Doubles near 2^60 are 256 apart. The box from far + 256 to far + 512 has
// radius 128; its centre, edges and every point on it round to far + 512.
private let far = 0x1p60

@Test(arguments: [
    (Point(x: far + 256, y: 0), Point(x: far + 512, y: 100)),
    (Point(x: 0, y: far + 256), Point(x: 100, y: far + 512)),
    (Point(x: far + 256, y: far + 256), Point(x: far + 512, y: far + 512)),
    (Point(x: -far - 512, y: -far - 512), Point(x: -far - 256, y: -far - 256)),
])
func aFarBoxThatCollapsesToZeroExtentRecordsNothing(start: Point, end: Point) {
    var workspace = ellipseWorkspace()
    #expect(FlareWorkspace.ellipse(from: start, to: end) == nil)
    workspace.dragChanged(from: start, to: end, stageScale: 1)
    #expect(workspace.draft == nil)
    workspace.drag(from: start, to: end, stageScale: 1)
    #expect(workspace.layers.isEmpty)
    #expect(!workspace.canUndo)
}

@Test func aFarBoxWideEnoughToKeepItsExtentStillMakesAnEllipse() throws {
    let start = Point(x: far, y: far), end = Point(x: far + 4096, y: far + 4096)
    let shape = try #require(FlareWorkspace.ellipse(from: start, to: end))
    let xs = shape.points.map(\.x), ys = shape.points.map(\.y)
    #expect((xs.max() ?? 0) > (xs.min() ?? 0))
    #expect((ys.max() ?? 0) > (ys.min() ?? 0))
    var workspace = ellipseWorkspace()
    workspace.drag(from: start, to: end, stageScale: 1)
    #expect(workspace.layers.first?.shapes == [shape])
}
