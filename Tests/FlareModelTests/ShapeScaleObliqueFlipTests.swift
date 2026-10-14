// ShapeScaleObliqueFlipTests.swift: #655, Scale on a layer rotated off a multiple of 90° flips when a handle is
// dragged through the opposite one, as it does at 0°, and an edge dropped on the opposite edge never collapses the
// layer to a point no handle can grow back.
import FlareCore
import FlareModel
import Testing

private let shapes = FlareServices.fake().shapes
private let shadow = StageAddress(owner: .scene("scene-1"), layerID: "shadow", item: .shape(0))
private let tolerance = 1e-6

private func rotated(_ degrees: Double) throws -> CommandEngine {
    var engine = CommandEngine(document: FlareFixtures.bounce)
    try engine.perform(SetKeyframe(sceneID: "scene-1", layerID: "shadow", property: "rotation",
                                   keyframe: Keyframe(frame: 0, value: degrees)))
    return engine
}

private func box(_ engine: CommandEngine) throws -> Rect {
    try #require(FakeHits().bounds(engine.document, sceneID: "scene-1", frame: 0, of: [shadow]))
}

private func transform(_ engine: CommandEngine) throws -> Transform {
    try #require(engine.document.layers(of: .scene("scene-1"))?.first { $0.id == "shadow" }).placement(at: 0).transform
}

/// Drags world handle `handle` of Shadow's current box to `to(box)`.
private func drag(_ handle: Int, in engine: inout CommandEngine, to: (Rect) -> Point) throws {
    let b = try box(engine)
    try shapes.commitBox(.scale(handle: handle, to: to(b)), layers: ["shadow"],
                         sceneID: "scene-1", frame: 0, box: b, autoKey: false, in: &engine)
}

/// The point 40 pt past the edge opposite edge handle `handle`, level with the grip.
private func past(_ handle: Int, _ b: Rect) -> Point {
    let grip = FakeShapes.handle(handle, on: b), fixed = FakeShapes.handle(handle + 4, on: b)
    return handle % 4 == 1 ? Point(x: grip.x, y: fixed.y + (fixed.y > grip.y ? 40 : -40))
        : Point(x: fixed.x + (fixed.x > grip.x ? 40 : -40), y: grip.y)
}

@Test(arguments: [30.0, 45, 135], [1, 3, 5, 7])
func anEdgeDraggedThroughTheOppositeEdgeMirrorsTheLayer(_ degrees: Double, _ handle: Int) throws {
    // #655's repro: at 30° the right edge dragged 40 pt past the left one stayed on the right, 80 pt off the pointer.
    var engine = try rotated(degrees)
    let (before, was) = (try box(engine), try transform(engine))
    let pointer = past(handle, before)
    try drag(handle, in: &engine) { _ in pointer }
    let (after, now) = (try box(engine), try transform(engine))
    let fixed = FakeShapes.handle(handle + 4, on: before)
    // Along the edge's axis the grip lands on the pointer, past the fixed edge, which still sits where it was.
    let (grip, still) = (FakeShapes.handle(handle + 4, on: after), FakeShapes.handle(handle, on: after))
    let along: (Point) -> Double = { handle % 4 == 1 ? $0.y : $0.x }
    #expect(abs(along(grip) - along(pointer)) <= tolerance, "\(degrees)° handle \(handle): grip on the pointer")
    #expect(abs(along(still) - along(fixed)) <= tolerance, "\(degrees)° handle \(handle): fixed edge stays")
    #expect((now.scaleX * now.scaleY > 0) != (was.scaleX * was.scaleY > 0), "\(degrees)° handle \(handle) mirrors")
}

@Test(arguments: [30.0, 45, 135])
func aCornerDraggedThroughTheOppositeSideMirrorsTheLayer(_ degrees: Double) throws {
    // Handle 4 (bottom-right) dragged 40 pt past the left edge, level with itself: the box flips to the left.
    var engine = try rotated(degrees)
    let before = try box(engine), was = try transform(engine)
    let grip = FakeShapes.handle(4, on: before), pointer = Point(x: before.minX - 40, y: grip.y)
    try drag(4, in: &engine) { _ in pointer }
    let after = try box(engine), now = try transform(engine)
    #expect(after.maxX <= before.minX + tolerance, "\(degrees)°: the box lies left of the fixed edge")
    #expect(abs(after.minY - before.minY) <= tolerance, "\(degrees)°: the top stays put")
    #expect((now.scaleX * now.scaleY > 0) != (was.scaleX * was.scaleY > 0))
}

@Test(arguments: [30.0, 45, 135], 0..<8)
func anEdgeDroppedOnTheOppositeEdgeLeavesALayerThatGrowsBack(_ degrees: Double, _ handle: Int) throws {
    // #655: at 30° the right edge dropped on the left one left scale 0 x 0, and no handle could grow it back.
    var engine = try rotated(degrees)
    try drag(3, in: &engine) { b in FakeShapes.handle(7, on: b) }
    let flat = try transform(engine)
    #expect(flat.scaleX != 0 || flat.scaleY != 0, "\(degrees)°: only the dragged axis goes to 0")
    try drag(handle, in: &engine) { b in
        let grip = FakeShapes.handle(handle, on: b)
        return Point(x: grip.x + 60, y: grip.y + 60)
    }
    let after = try box(engine)
    #expect(after.width > 1 && after.height > 1, "\(degrees)° handle \(handle): \(after)")
}
