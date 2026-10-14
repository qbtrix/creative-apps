// FlarePenDegenerateTests.swift: repeated pen clicks on one spot stack no
// coincident anchors, closing needs 3 distinct anchors, and a pen path with
// fewer than 2 distinct points commits no layer and no undo step (#512).
// Runs on Linux and macOS.
import FlareCore
import FlareModel
import Testing

private let shapes = FlareServices.fake().shapes
private func click(_ x: Double, _ y: Double, after previous: ShapeDraft?) -> ShapeDraft? {
    shapes.draft(.pen, from: Point(x: x, y: y), to: Point(x: x, y: y), modifiers: [], previous: previous)
}

@Test func aClickOnTheLastAnchorAddsNothingAndCoincidentAnchorsNeverClose() throws {
    var d: ShapeDraft?
    for x in [0.0, 0.0, 0.0, 1.0] { d = click(x, 0, after: d) }
    let pen = try #require(d)
    #expect(pen.anchors == [Point(x: 0, y: 0), Point(x: 1, y: 0)] && !pen.isClosed && !pen.shape.closed)
}

@Test func aRepeatedClickBurstAddsNoAnchors() throws {
    var d = click(10, 10, after: nil)
    d = click(50, 10, after: d)
    let before = try #require(d)
    for _ in 0..<20 { d = click(50, 10, after: d) }
    #expect(d == before)
}

@Test func returningToAnEarlierAnchorDoesNotCountTowardClosing() throws {
    var d: ShapeDraft?
    for (x, y) in [(0.0, 0.0), (100.0, 0.0), (0.0, 0.0), (1.0, 1.0)] { d = click(x, y, after: d) }
    let pen = try #require(d)
    #expect(!pen.isClosed && pen.anchors.count == 4)
}

@Test func aPathWithFewerThanTwoDistinctPointsDoesNotCommit() throws {
    let one = try #require(click(3, 3, after: nil))
    let stacked = ShapeDraft(tool: .pen, shape: FlareShape(points: [Point(x: 3, y: 3), Point(x: 3, y: 3)], closed: true),
                             anchors: [Point(x: 3, y: 3), Point(x: 3, y: 3), Point(x: 3, y: 3)], isClosed: true)
    for draft in [one, stacked] {
        var engine = CommandEngine(document: FlareFixtures.empty)
        #expect(throws: CommandError.self) {
            try shapes.commit(draft, owner: .scene("scene-1"), aboveLayerID: nil, in: &engine)
        }
        #expect(engine.document.layers(of: .scene("scene-1"))?.isEmpty == true && !engine.canUndo)
    }
}

@Test func clickingOneSpotInTheWorkspaceLeavesOneAnchorAndNoLayer() {
    var workspace = FlareWorkspace(services: .fake())
    workspace.newDocument()
    workspace.selectTool(.pen)
    for _ in 0..<5 { workspace.drag(from: Point(x: 20, y: 20), to: Point(x: 20, y: 20)) }
    #expect(workspace.draft?.anchors == [Point(x: 20, y: 20)])
    #expect(workspace.layers.isEmpty && !workspace.canUndo)
}
