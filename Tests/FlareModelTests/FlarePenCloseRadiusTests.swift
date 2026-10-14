// FlarePenCloseRadiusTests.swift: the pen closes a path on a click within
// `FakeShapes.closeDistance` stage (view) points of the first anchor, so the
// stage's fit scale sets the radius in scene points: a near miss on a shrunk
// stage still closes, and a fourth anchor a few screen points off on a zoomed
// stage doesn't (#649). Runs on Linux and macOS.
import FlareCore
import FlareModel
import Testing

private func penClicks(_ points: [(Double, Double)], stageScale: Double) -> FlareWorkspace {
    var w = FlareWorkspace(services: .fake())
    w.newDocument(); w.selectTool(.pen)
    for (x, y) in points { w.drag(from: Point(x: x, y: y), to: Point(x: x, y: y), stageScale: stageScale) }
    return w
}

@Test func aCloseClickTwoScreenPointsOffOnAShrunkStageClosesThePath() {
    let w = penClicks([(100, 100), (300, 100), (300, 300), (105, 100)], stageScale: 0.4)
    #expect(w.layers.map(\.name) == ["Path 1"] && w.canUndo)
}

@Test func aFourthAnchorOnAZoomedStageDoesNotClose() {
    let w = penClicks([(20, 20), (25, 20), (25, 25), (20, 23.5)], stageScale: 8)
    #expect(w.layers.isEmpty && !w.canUndo)
    #expect(w.draft?.anchors.count == 4 && w.draft?.isClosed == false)
}

@Test func theCloseRadiusIsStagePointsOverTheFitScale() {
    #expect(FakeShapes.closeDistance(atStageScale: 1) == FakeShapes.closeDistance)
    #expect(FakeShapes.closeDistance(atStageScale: 0.4) == FakeShapes.closeDistance / 0.4)
    #expect(FakeShapes.closeDistance(atStageScale: 8) == FakeShapes.closeDistance / 8)
    for scale: Double in [0, -1, .nan, -.infinity, .leastNonzeroMagnitude] {
        #expect(FakeShapes.closeDistance(atStageScale: scale) == .infinity)
    }
}
