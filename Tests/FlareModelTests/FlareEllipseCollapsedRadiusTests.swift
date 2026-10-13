// FlareEllipseCollapsedRadiusTests.swift: at an infinite stage scale the
// minimum is the smallest subnormal, and half of a box that size rounds to
// zero (#503). Such a box makes no zero-radius ellipse: no layer, no draft and
// no undo step. Runs on Linux and macOS.
import FlareCore
import FlareModel
import Testing

private func ellipseWorkspace() -> FlareWorkspace {
    var workspace = FlareWorkspace()
    workspace.newDocument()
    workspace.selectTool(.ellipse)
    return workspace
}

private let tiny = Double.leastNonzeroMagnitude

@Test(arguments: [
    Point(x: tiny, y: tiny), Point(x: tiny, y: 100), Point(x: 100, y: tiny), Point(x: -tiny, y: -tiny),
])
func aBoxWhoseRadiusRoundsToZeroRecordsNothing(end: Point) {
    var workspace = ellipseWorkspace()
    let start = Point(x: 0, y: 0)
    #expect(FlareWorkspace.ellipse(from: start, to: end, stageScale: .infinity) == nil)
    workspace.dragChanged(from: start, to: end, stageScale: .infinity)
    #expect(workspace.draft == nil)
    workspace.drag(from: start, to: end, stageScale: .infinity)
    #expect(workspace.layers.isEmpty)
    #expect(!workspace.canUndo)
}

@Test func aBoxTwiceTheSmallestSubnormalStillMakesAnEllipse() throws {
    let end = Point(x: 2 * tiny, y: 2 * tiny)
    let shape = try #require(FlareWorkspace.ellipse(from: Point(x: 0, y: 0), to: end, stageScale: .infinity))
    #expect(shape.points.contains { $0.x > 0 })
    var workspace = ellipseWorkspace()
    workspace.drag(from: Point(x: 0, y: 0), to: end, stageScale: .infinity)
    #expect(workspace.layers.first?.shapes == [shape])
}
