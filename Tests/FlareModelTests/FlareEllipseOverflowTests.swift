// FlareEllipseOverflowTests.swift: the Ellipse tool on FlareWorkspace at
// coordinates near the largest finite Double. The box's centre must not
// overflow, so the tool never adds an ellipse with infinite points, and a box
// it can't represent adds no layer and no undo step. Runs on Linux and macOS.
import FlareCore
import FlareModel
import Testing

private let big = Double.greatestFiniteMagnitude

private func shapePoints(_ shape: FlareShape) -> [Point] {
    shape.points + (shape.path?.elements ?? []).flatMap { element -> [Point] in
        switch element {
        case .move(let p): [p]
        case .cubic(let c1, let c2, let p): [c1, c2, p]
        default: []
        }
    }
}

private func ellipseWorkspace() -> FlareWorkspace {
    var workspace = FlareWorkspace()
    workspace.newDocument()
    workspace.selectTool(.ellipse)
    return workspace
}

@Test(arguments: [
    (Point(x: big, y: big), Point(x: big / 2, y: big / 2)),
    (Point(x: big * 0.75, y: -big * 0.75), Point(x: big * 0.5, y: -big * 0.5)),
])
func extremeCornersWhoseSumOverflowsStillMakeAFiniteEllipse(start: Point, end: Point) throws {
    // start + end overflows here; min corner + half the size does not.
    #expect(!(start.x + end.x).isFinite || !(start.y + end.y).isFinite)
    let shape = try #require(FlareWorkspace.ellipse(from: start, to: end))
    #expect(shapePoints(shape).allSatisfy { $0.x.isFinite && $0.y.isFinite })
    // Inside the box, up to rounding at these magnitudes.
    let slack = 1e-9 * max(abs(start.x - end.x), abs(start.y - end.y))
    #expect(shapePoints(shape).allSatisfy {
        $0.x >= min(start.x, end.x) - slack && $0.x <= max(start.x, end.x) + slack
            && $0.y >= min(start.y, end.y) - slack && $0.y <= max(start.y, end.y) + slack
    })
}

@Test(arguments: [0.5, 0.9, 0.99, 0.999999])
func aBoxAtTheEdgeOfTheRangeIsRefusedOrFiniteAndUndoAgrees(fraction: Double) {
    // Where the far edge rounds past the largest finite value, the tool refuses
    // the box; otherwise it adds one finite ellipse. Either way, an undo step
    // exists exactly when a layer was added.
    let start = Point(x: -big, y: big), end = Point(x: -big * fraction, y: big * fraction)
    var workspace = ellipseWorkspace()
    workspace.drag(from: start, to: end)
    let shapes = workspace.layers.flatMap(\.shapes)
    #expect(shapes.count <= 1)
    #expect(shapes.flatMap(shapePoints).allSatisfy { $0.x.isFinite && $0.y.isFinite })
    #expect(workspace.canUndo == !workspace.layers.isEmpty)
    #expect((FlareWorkspace.ellipse(from: start, to: end) == nil) == workspace.layers.isEmpty)
}

@Test func extremeCornersNeverCommitInfinitePoints() {
    var workspace = ellipseWorkspace()
    workspace.drag(from: Point(x: big, y: big), to: Point(x: big / 2, y: big / 2))
    let shapes = workspace.layers.flatMap(\.shapes)
    #expect(shapes.count == 1)
    #expect(shapes.flatMap(shapePoints).allSatisfy { $0.x.isFinite && $0.y.isFinite })
}

@Test(arguments: [
    (Point(x: -big, y: 0), Point(x: big, y: 10)),
    (Point(x: 0, y: big), Point(x: 10, y: -big)),
    (Point(x: -big, y: -big), Point(x: big, y: big)),
])
func aBoxWhoseSizeOverflowsAddsNoLayerAndNoUndoStep(start: Point, end: Point) {
    #expect(FlareWorkspace.ellipse(from: start, to: end) == nil)
    var workspace = ellipseWorkspace()
    workspace.dragChanged(from: start, to: end)
    #expect(workspace.draft == nil)
    workspace.drag(from: start, to: end)
    #expect(workspace.layers.isEmpty)
    #expect(!workspace.canUndo)
}

@Test func anOrdinaryBoxIsUnchanged() throws {
    let shape = try #require(FlareWorkspace.ellipse(from: Point(x: 10, y: 20), to: Point(x: 110, y: 70)))
    #expect(shape.points == [
        Point(x: 110, y: 45), Point(x: 60, y: 70), Point(x: 10, y: 45), Point(x: 60, y: 20),
    ])
    var workspace = ellipseWorkspace()
    workspace.drag(from: Point(x: 10, y: 20), to: Point(x: 110, y: 70))
    #expect(workspace.layers.first?.shapes == [shape])
    #expect(workspace.undoActionName == "Undo Add Ellipse")
}
