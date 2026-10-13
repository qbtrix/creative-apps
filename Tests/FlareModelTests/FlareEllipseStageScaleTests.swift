// FlareEllipseStageScaleTests.swift: the Ellipse tool's minimum box applies in
// stage points. On a stage fit-scaled down, click jitter of a few stage points
// spans more than one scene point, yet adds no layer, no draft and no undo
// step; a real drag still adds one Ellipse; a non-finite, zero or tiny scale
// falls back to scale 1. Runs on Linux and macOS.
import FlareCore
import FlareModel
import Testing

private func ellipseWorkspace() -> FlareWorkspace {
    var workspace = FlareWorkspace()
    workspace.newDocument()
    workspace.selectTool(.ellipse)
    return workspace
}

private let m = FlareWorkspace.minimumEllipseExtent
// Half a stage point of jitter at scale 0.25 is 2 scene points: above the
// scene-point minimum, below the stage-point one.
private let start = Point(x: 10, y: 10)
private let jitter = Point(x: 10 + 2 * m, y: 10 + 2 * m)

@Test func aJitterDragAtASmallFitScaleCommitsNothing() {
    var workspace = ellipseWorkspace()
    workspace.addLayer()
    let before = workspace.document
    let undoName = workspace.undoActionName
    #expect(FlareWorkspace.ellipse(from: start, to: jitter, stageScale: 0.25) == nil)
    workspace.dragChanged(from: start, to: jitter, stageScale: 0.25)
    #expect(workspace.draft == nil)
    workspace.drag(from: start, to: jitter, stageScale: 0.25)
    #expect(workspace.document == before)
    #expect(workspace.undoActionName == undoName)
    #expect(workspace.layerError == nil)
}

@Test func theSameDragAtScaleOneBehavesAsBefore() throws {
    var workspace = ellipseWorkspace()
    let shape = try #require(FlareWorkspace.ellipse(from: start, to: jitter))
    #expect(FlareWorkspace.ellipse(from: start, to: jitter, stageScale: 1) == shape)
    workspace.dragChanged(from: start, to: jitter, stageScale: 1)
    #expect(workspace.draft == shape)
    workspace.drag(from: start, to: jitter, stageScale: 1)
    #expect(workspace.layers.map(\.name) == ["Ellipse 1"])
    #expect(workspace.layers.first?.shapes == [shape])
    #expect(workspace.undoActionName == "Undo Add Ellipse")
}

@Test func aRealDragAtASmallFitScaleAddsOneEllipse() throws {
    var workspace = ellipseWorkspace()
    let end = Point(x: 210, y: 130)
    let shape = try #require(FlareWorkspace.ellipse(from: start, to: end, stageScale: 0.25))
    workspace.dragChanged(from: start, to: end, stageScale: 0.25)
    #expect(workspace.draft == shape)
    workspace.drag(from: start, to: end, stageScale: 0.25)
    #expect(workspace.draft == nil)
    #expect(workspace.layers.map(\.name) == ["Ellipse 1"])
    #expect(workspace.layers.first?.shapes == [shape])
    workspace.undo()
    #expect(workspace.layers.isEmpty)
    #expect(!workspace.canUndo)
}

@Test func theMinimumAtAScaleIsInStagePoints() {
    #expect(FlareWorkspace.minimumEllipseExtent(atStageScale: 1) == m)
    #expect(FlareWorkspace.minimumEllipseExtent(atStageScale: 0.25) == 4 * m)
    #expect(FlareWorkspace.minimumEllipseExtent(atStageScale: 4) == m / 4)
}

@Test(arguments: [0.0, -0.0, -1.0, .nan, .infinity, -.infinity, .leastNonzeroMagnitude])
func aBadScaleFallsBackToScaleOne(scale: Double) throws {
    let minimum = FlareWorkspace.minimumEllipseExtent(atStageScale: scale)
    #expect(minimum.isFinite)
    #expect(minimum == m)
    var workspace = ellipseWorkspace()
    let below = Point(x: 10 + m / 2, y: 10 + m / 2)
    workspace.drag(from: start, to: below, stageScale: scale)
    #expect(workspace.layers.isEmpty)
    #expect(!workspace.canUndo)
    let shape = try #require(FlareWorkspace.ellipse(from: start, to: jitter))
    workspace.dragChanged(from: start, to: jitter, stageScale: scale)
    #expect(workspace.draft == shape)
    workspace.drag(from: start, to: jitter, stageScale: scale)
    #expect(workspace.layers.first?.shapes == [shape])
}
