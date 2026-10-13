// FlareEllipseDegenerateScaleTests.swift: a degenerate stage scale refuses
// every Ellipse box (#502). Zero, negative, -infinity, NaN and a scale whose
// 1 / scale overflows give a minimum no box can meet, so even a box of the
// largest finite size adds no layer, no draft and no undo step. Runs on Linux
// and macOS.
import FlareCore
import FlareModel
import Testing

private let degenerateScales: [Double] = [0, -0.0, -1, -.infinity, .nan, .leastNonzeroMagnitude]

@Test(arguments: degenerateScales)
func aDegenerateScaleHasAMinimumNoBoxMeets(scale: Double) {
    #expect(FlareWorkspace.minimumEllipseExtent(atStageScale: scale) == .infinity)
}

@Test(arguments: degenerateScales)
func aDegenerateScaleRefusesTheLargestBox(scale: Double) {
    var workspace = FlareWorkspace()
    workspace.newDocument()
    workspace.selectTool(.ellipse)
    let start = Point(x: 0, y: 0)
    let end = Point(x: .greatestFiniteMagnitude, y: .greatestFiniteMagnitude)
    #expect(FlareWorkspace.ellipse(from: start, to: end, stageScale: scale) == nil)
    workspace.dragChanged(from: start, to: end, stageScale: scale)
    #expect(workspace.draft == nil)
    workspace.drag(from: start, to: end, stageScale: scale)
    #expect(workspace.layers.isEmpty)
    #expect(!workspace.canUndo)
}

@Test func aTinyFiniteScaleStillCommitsABoxAboveItsMinimum() throws {
    // Only a degenerate scale refuses every box: at 1e-300 the minimum is a
    // finite 1e300 scene points, and a box ten times that still commits.
    var workspace = FlareWorkspace()
    workspace.newDocument()
    workspace.selectTool(.ellipse)
    let scale = 1e-300, start = Point(x: 0, y: 0), end = Point(x: 1e301, y: 1e301)
    #expect(FlareWorkspace.minimumEllipseExtent(atStageScale: scale).isFinite)
    let shape = try #require(FlareWorkspace.ellipse(from: start, to: end, stageScale: scale))
    workspace.drag(from: start, to: end, stageScale: scale)
    #expect(workspace.layers.first?.shapes == [shape])
    #expect(workspace.canUndo)
}
