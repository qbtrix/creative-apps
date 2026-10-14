// ShapeScaleObliqueTests.swift: #560 and #625, Scale on a layer rotated off a multiple of 90° works on the world box
// the stage shows (FakeHits bounds). The handle opposite the grip stays put at any angle, an edge follows the pointer
// along its axis, and a corner lands as near the pointer as a turned box can, with no blow-up near 45°.
import FlareCore
import FlareModel
import Testing

private let shapes = FlareServices.fake().shapes
private let shadow = StageAddress(owner: .scene("scene-1"), layerID: "shadow", item: .shape(0))
/// The budget: how far, in scene points, a handle may land from where it belongs.
private let tolerance = 1e-6

private func rotated(_ degrees: Double, scaleX: Double = 1) throws -> CommandEngine {
    var engine = CommandEngine(document: FlareFixtures.bounce)
    try engine.perform(SetKeyframe(owner: .scene("scene-1"), layerID: "shadow", property: "rotation",
                                   keyframe: Keyframe(frame: 0, value: degrees)))
    if scaleX != 1 {
        try engine.perform(SetKeyframe(owner: .scene("scene-1"), layerID: "shadow", property: "scaleX",
                                       keyframe: Keyframe(frame: 0, value: scaleX)))
    }
    return engine
}

private func distance(_ a: Point, _ b: Point) -> Double { ((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y)).squareRoot() }

/// Scales Shadow at `degrees` by dragging world handle `handle` by `drag` (or by `drag(box)` from its box); returns
/// the world boxes before and after, the pointer, and the undo name.
private func scale(_ degrees: Double, handle: Int, scaleX: Double = 1, drag: (Rect) -> Point) throws
    -> (box: Rect, now: Rect, pointer: Point, transform: Transform, undo: String?) {
    var engine = try rotated(degrees, scaleX: scaleX)
    let box = try #require(FakeHits().bounds(engine.document, sceneID: "scene-1", frame: 0, of: [shadow]))
    let grip = FakeShapes.handle(handle, on: box), d = drag(box), pointer = Point(x: grip.x + d.x, y: grip.y + d.y)
    try shapes.commitBox(.scale(handle: handle, to: pointer), layers: ["shadow"],
                         sceneID: "scene-1", frame: 0, box: box, autoKey: false, in: &engine)
    let now = try #require(FakeHits().bounds(engine.document, sceneID: "scene-1", frame: 0, of: [shadow]))
    let layer = try #require(engine.document.layers(of: .scene("scene-1"))?.first { $0.id == "shadow" })
    return (box, now, pointer, layer.placement(at: 0).transform, engine.undoActionName)
}

private let angles: [Double] = [30, 44, 45, 46, 60, -30, 135]

@Test(arguments: angles, 0..<8)
func theOppositeWorldHandleStaysPut(_ degrees: Double, _ handle: Int) throws {
    // #625's repro: at 45° bottom-right dragged by (50, 20) moved the top-left handle 15 pt.
    let r = try scale(degrees, handle: handle) { _ in Point(x: 50, y: 20) }
    let (before, after) = (FakeShapes.handle(handle + 4, on: r.box), FakeShapes.handle(handle + 4, on: r.now))
    #expect(distance(before, after) <= tolerance, "\(degrees)° handle \(handle)")
    #expect(r.undo == "Undo Scale")
}

@Test(arguments: angles, [1, 3, 5, 7])
func aWorldEdgeFollowsThePointerAlongItsAxis(_ degrees: Double, _ handle: Int) throws {
    // A (10, 10) drag moves a side edge 10 pt across and a top or bottom edge 10 pt down; at 45° it used to do nothing.
    let r = try scale(degrees, handle: handle) { _ in Point(x: 10, y: 10) }
    let grip = FakeShapes.handle(handle, on: r.box)
    let wanted = handle % 4 == 1 ? Point(x: grip.x, y: r.pointer.y) : Point(x: r.pointer.x, y: grip.y)
    #expect(distance(FakeShapes.handle(handle, on: r.now), wanted) <= tolerance, "\(degrees)° handle \(handle)")
}

@Test(arguments: angles, [0, 2, 4, 6])
func aWorldCornerFollowsAnEvenDrag(_ degrees: Double, _ handle: Int) throws {
    // A drag along the box's diagonal (the box grows 20% both ways) is one the turned box can take exactly.
    let r = try scale(degrees, handle: handle) { box in
        let (grip, fixed) = (FakeShapes.handle(handle, on: box), FakeShapes.handle(handle + 4, on: box))
        return Point(x: (grip.x - fixed.x) * 0.2, y: (grip.y - fixed.y) * 0.2)
    }
    #expect(distance(FakeShapes.handle(handle, on: r.now), r.pointer) <= tolerance, "\(degrees)° handle \(handle)")
}

@Test func atFortyFiveTheCornerLandsWhereTheSquareBoxComesNearest() throws {
    // At 45° Shadow's world box is square at any scale, so a (50, 20) drag can grow it only evenly: the grip lands on
    // the pointer's nearest point on the box's diagonal, (35, 35) from where it was.
    let r = try scale(45, handle: 4) { _ in Point(x: 50, y: 20) }
    let grip = FakeShapes.handle(4, on: r.box)
    #expect(distance(FakeShapes.handle(4, on: r.now), Point(x: grip.x + 35, y: grip.y + 35)) <= tolerance)
}

@Test(arguments: [30.0, 44, 45, 46, 60], 0..<8)
func aCornerDragNeverFlipsOrOvershoots(_ degrees: Double, _ handle: Int) throws {
    // #560's blow-up near 45° grew the box to about 481 x 492: no box edge may move farther than the pointer did, and
    // the layer keeps its facing, even mirrored.
    let r = try scale(degrees, handle: handle, scaleX: -1) { _ in Point(x: 50, y: 20) }
    let reach = distance(Point(x: 0, y: 0), Point(x: 50, y: 20)) + tolerance
    #expect(abs(r.now.minX - r.box.minX) <= reach && abs(r.now.minY - r.box.minY) <= reach)
    #expect(abs(r.now.maxX - r.box.maxX) <= reach && abs(r.now.maxY - r.box.maxY) <= reach)
    #expect(r.transform.scaleX < 0 && r.transform.scaleY > 0, "\(degrees)° handle \(handle)")
}
