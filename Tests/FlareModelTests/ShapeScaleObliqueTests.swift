// ShapeScaleObliqueTests.swift: #560, Scale on a layer rotated off a multiple of 90° works on the layer's own
// (oriented) box. The oriented handle nearest the grabbed one follows the pointer, the opposite one stays put, at
// any angle, 45° included; before the fix the world-axis ratio blew the layer up about 7x near 45°.
import FlareCore
import FlareModel
import Testing

private let shapes = FlareServices.fake().shapes
private let shadow = StageAddress(owner: .scene("scene-1"), layerID: "shadow", item: .shape(0))
private let drag = Point(x: 50, y: 20)
/// The budget: how far, in scene points, a handle may land from where it belongs.
private let tolerance = 1e-6

private func rotated(_ degrees: Double) throws -> CommandEngine {
    var engine = CommandEngine(document: FlareFixtures.bounce)
    try engine.perform(SetKeyframe(sceneID: "scene-1", layerID: "shadow", property: "rotation",
                                   keyframe: Keyframe(frame: 0, value: degrees)))
    return engine
}

/// Shadow's oriented handles in the scene, 0...7 clockwise from its local top-left, as `FakeShapes.handle` numbers them.
private func oriented(_ e: CommandEngine) throws -> [Point] {
    let layer = try #require(e.document.layers(of: .scene("scene-1"))?.first { $0.id == "shadow" })
    let shape = try #require(layer.shapes.first), local = try #require(shape.outline.bounds)
    let width = shape.stroke?.width ?? 0, half = (width.isFinite ? max(width, 0) : 0) / 2
    let box = Rect(minX: local.minX - half, minY: local.minY - half, maxX: local.maxX + half, maxY: local.maxY + half)
    let m = layer.placement(at: 0).transform.matrix
    return (0..<8).map { m.apply(FakeShapes.handle($0, on: box)) }
}

private func distance(_ a: Point, _ b: Point) -> Double { ((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y)).squareRoot() }

/// Scales Shadow at `degrees` by dragging world handle `handle` by `drag`; returns the oriented handle it grabbed,
/// the oriented handles before and after, and the world boxes before and after.
private func scale(_ degrees: Double, handle: Int) throws
    -> (grabbed: Int, before: [Point], after: [Point], box: Rect, now: Rect, undo: String?) {
    var engine = try rotated(degrees)
    let box = try #require(FakeHits().bounds(engine.document, sceneID: "scene-1", frame: 0, of: [shadow]))
    let grip = FakeShapes.handle(handle, on: box), before = try oriented(engine)
    // The oriented handle of the same kind (corner or edge) nearest the one the pointer grabbed.
    let grabbed = try #require(stride(from: handle % 2, to: 8, by: 2).min { distance(before[$0], grip) < distance(before[$1], grip) })
    try shapes.commitBox(.scale(handle: handle, to: Point(x: grip.x + drag.x, y: grip.y + drag.y)), layers: ["shadow"],
                         sceneID: "scene-1", frame: 0, box: box, autoKey: false, in: &engine)
    let now = try #require(FakeHits().bounds(engine.document, sceneID: "scene-1", frame: 0, of: [shadow]))
    return (grabbed, before, try oriented(engine), box, now, engine.undoActionName)
}

private let angles: [Double] = [30, 44, 45, 46, 60, -30, 135]

@Test(arguments: angles, 0..<8)
func theOppositeOrientedHandleStaysPut(_ degrees: Double, _ handle: Int) throws {
    let r = try scale(degrees, handle: handle)
    let opposite = (r.grabbed + 4) % 8
    #expect(distance(r.after[opposite], r.before[opposite]) <= tolerance, "\(degrees)° handle \(handle)")
    #expect(r.undo == "Undo Scale")
}

@Test(arguments: angles, 0..<8)
func theGrabbedOrientedHandleFollowsThePointer(_ degrees: Double, _ handle: Int) throws {
    let r = try scale(degrees, handle: handle)
    let (from, opposite) = (r.before[r.grabbed], r.before[(r.grabbed + 4) % 8])
    var wanted = Point(x: from.x + drag.x, y: from.y + drag.y)
    if r.grabbed % 2 == 1 {
        // An edge moves only along its own normal (from the opposite edge): the pointer's part along it.
        let n = Point(x: from.x - opposite.x, y: from.y - opposite.y), len = distance(from, opposite)
        let along = (drag.x * n.x + drag.y * n.y) / (len * len)
        wanted = Point(x: from.x + n.x * along, y: from.y + n.y * along)
    }
    #expect(distance(r.after[r.grabbed], wanted) <= tolerance, "\(degrees)° handle \(handle)")
}

@Test(arguments: [44.0, 45, 46])
func theNearFortyFiveReproStaysWithinTheDrag(_ degrees: Double) throws {
    // #560's repro: bottom-right dragged by (50, 20) grew the box to about 481 x 492. No point of the layer moves
    // farther than the pointer did, so no box edge may move farther either.
    let r = try scale(degrees, handle: 4)
    let reach = distance(Point(x: 0, y: 0), drag) + tolerance
    #expect(abs(r.now.minX - r.box.minX) <= reach && abs(r.now.minY - r.box.minY) <= reach)
    #expect(abs(r.now.maxX - r.box.maxX) <= reach && abs(r.now.maxY - r.box.maxY) <= reach)
}
