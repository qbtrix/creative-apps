// FlarePenToleranceTests.swift: pen clicks within `FakeShapes.anchorTolerance`
// of the last anchor stack nothing, only anchors that far apart count toward
// closing, and a path whose extent is under it commits no layer and no undo
// step; a stroke just over it still commits (#561). Runs on Linux and macOS.
import FlareCore
import FlareModel
import Testing

private let shapes = FlareServices.fake().shapes
private func click(_ x: Double, _ y: Double, after previous: ShapeDraft?) -> ShapeDraft? {
    shapes.draft(.pen, from: Point(x: x, y: y), to: Point(x: x, y: y), modifiers: [], previous: previous)
}

@Test func subPointPenClicksInTheWorkspaceCommitNoLayer() {
    var w = FlareWorkspace(services: .fake())
    w.newDocument(); w.selectTool(.pen)
    for (x, y) in [(20.0, 20.0), (20.5, 20.0), (20.0, 20.5), (20.2, 20.2)] {
        w.drag(from: Point(x: x, y: y), to: Point(x: x, y: y))
    }
    #expect(w.layers.isEmpty && !w.canUndo)
    #expect(w.draft?.anchors == [Point(x: 20, y: 20)])
}

@Test func aJitteredClickNearTheLastAnchorAddsNothing() throws {
    var d = click(20, 20, after: nil)
    d = click(80, 20, after: d)
    d = click(80, 20.4, after: d)
    #expect(try #require(d).anchors == [Point(x: 20, y: 20), Point(x: 80, y: 20)])
}

@Test func aPathUnderTheToleranceDoesNotCommit() {
    let points = [Point(x: 3, y: 3), Point(x: 3.6, y: 3), Point(x: 3, y: 3.6)]
    let draft = ShapeDraft(tool: .pen, shape: FlareShape(points: points, closed: true), anchors: points, isClosed: true)
    var engine = CommandEngine(document: FlareFixtures.empty)
    #expect(throws: CommandError.self) { try shapes.commit(draft, sceneID: "scene-1", aboveLayerID: nil, in: &engine) }
    #expect(engine.document.layers(of: .scene("scene-1"))?.isEmpty == true && !engine.canUndo)
}

@Test func aStrokeJustOverTheToleranceStillCommits() throws {
    let step = FakeShapes.anchorTolerance + 0.01
    var d = click(0, 0, after: nil)
    d = click(step, 0, after: d)
    let draft = try #require(d)
    #expect(draft.anchors.count == 2)
    var engine = CommandEngine(document: FlareFixtures.empty)
    _ = try shapes.commit(draft, sceneID: "scene-1", aboveLayerID: nil, in: &engine)
    #expect(engine.document.layers(of: .scene("scene-1"))?.map(\.name) == ["Path 1"] && engine.canUndo)
}

@Test func anchorsJustOverTheToleranceApartClose() throws {
    let step = FakeShapes.anchorTolerance + 0.01
    var d: ShapeDraft?
    for (x, y) in [(0.0, 0.0), (step, 0.0), (step, step), (0.0, 0.0)] { d = click(x, y, after: d) }
    #expect(try #require(d).isClosed)
}
