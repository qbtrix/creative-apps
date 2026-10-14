// FlarePenStageScaleTests.swift: the pen's anchor tolerance is
// `FakeShapes.anchorTolerance` stage (view) points, so the stage's fit scale
// sets it in scene points: half-point clicks on a shrunk stage commit nothing,
// and deliberate clicks on a zoomed stage still close a path (#619). Runs on
// Linux and macOS.
import FlareCore
import FlareModel
import Testing

private func penClicks(_ points: [(Double, Double)], stageScale: Double) -> FlareWorkspace {
    var w = FlareWorkspace(services: .fake())
    w.newDocument(); w.selectTool(.pen)
    for (x, y) in points { w.drag(from: Point(x: x, y: y), to: Point(x: x, y: y), stageScale: stageScale) }
    return w
}

@Test func subPointPenClicksOnAShrunkStageCommitNoLayer() {
    let w = penClicks([(20, 20), (21.25, 20), (20, 21.25), (19.8, 19.9)], stageScale: 0.4)
    #expect(w.layers.isEmpty && !w.canUndo)
    #expect(w.draft?.anchors == [Point(x: 20, y: 20)])
}

@Test func penClicksAFewScreenPointsApartOnAZoomedStageCommitAPath() {
    let w = penClicks([(20, 20), (20.75, 20), (20, 20.75), (20, 20)], stageScale: 8)
    #expect(w.layers.map(\.name) == ["Path 1"] && w.canUndo)
}

@Test func theToleranceIsStagePointsOverTheFitScale() {
    #expect(FakeShapes.anchorTolerance(atStageScale: 1) == FakeShapes.anchorTolerance)
    #expect(FakeShapes.anchorTolerance(atStageScale: 0.4) == FakeShapes.anchorTolerance / 0.4)
    #expect(FakeShapes.anchorTolerance(atStageScale: 8) == FakeShapes.anchorTolerance / 8)
}

@Test func aDegenerateStageScaleCommitsNoPath() {
    for scale: Double in [0, -1, .nan, -.infinity, .leastNonzeroMagnitude] {
        #expect(FakeShapes.anchorTolerance(atStageScale: scale) == .infinity)
        let w = penClicks([(0, 0), (50, 0), (50, 50), (0, 0)], stageScale: scale)
        #expect(w.layers.isEmpty && !w.canUndo)
    }
}
