// ShapeScaleFlattenedRotatedTests.swift: #679, a rotated layer an edge drop has flattened (#673, scaleX 0) still
// scales through the oblique path: its box handles follow the pointer, and a drag outward grows it, never 0 x 0.
import FlareCore
import FlareModel
import Testing

private let shapes = FlareServices.fake().shapes
private let shadow = StageAddress(owner: .scene("scene-1"), layerID: "shadow", item: .shape(0))

private func engine(rotated degrees: Double) throws -> CommandEngine {
    var engine = CommandEngine(document: FlareFixtures.bounce)
    try engine.perform(SetKeyframe(owner: .scene("scene-1"), layerID: "shadow", property: "rotation",
                                   keyframe: Keyframe(frame: 0, value: degrees)))
    return engine
}

private func box(_ engine: CommandEngine) throws -> Rect {
    try #require(FakeHits().bounds(engine.document, sceneID: "scene-1", frame: 0, of: [shadow]))
}

private func transform(_ engine: CommandEngine) throws -> Transform {
    try #require(engine.document.layers(of: .scene("scene-1"))?.first { $0.id == "shadow" }).placement(at: 0).transform
}

private func drag(_ handle: Int, in engine: inout CommandEngine, to: (Rect) -> Point) throws {
    let b = try box(engine)
    try shapes.commitBox(.scale(handle: handle, to: to(b)), layers: ["shadow"],
                         sceneID: "scene-1", frame: 0, box: b, autoKey: false, in: &engine)
}

/// Shadow turned `degrees`, its right edge dropped on its left edge: one local axis at 0, the box still non-zero.
private func flattened(_ degrees: Double) throws -> CommandEngine {
    var e = try engine(rotated: degrees)
    try drag(3, in: &e) { FakeShapes.handle(7, on: $0) }
    let t = try transform(e), b = try box(e)
    #expect((t.scaleX == 0) != (t.scaleY == 0), "\(degrees)°: one axis flattened, \(t)")
    #expect(b.width > 1 && b.height > 1, "\(degrees)°: \(b)")
    return e
}

/// The world offset that drags handle `h` 80 pt straight out of its box.
private func outward(_ h: Int) -> (dx: Double, dy: Double) {
    (dx: [2, 3, 4].contains(h) ? 80 : [0, 6, 7].contains(h) ? -80 : 0,
     dy: [4, 5, 6].contains(h) ? 80 : [0, 1, 2].contains(h) ? -80 : 0)
}

@Test func theIssueReproGrowsTheFlattenedLayer() throws {
    var e = try flattened(45)
    let before = try box(e)
    try drag(4, in: &e) { b in
        let g = FakeShapes.handle(4, on: b)
        return Point(x: g.x + 80, y: g.y + 80)
    }
    let after = try box(e), t = try transform(e)
    #expect(after.width > before.width + 1 && after.height > before.height + 1, "\(before) -> \(after)")
    #expect(t.scaleX != 0 || t.scaleY != 0)
}

@Test(arguments: [30.0, 45, 135])
func everyHandleDraggedOutwardGrowsTheFlattenedLayer(_ degrees: Double) throws {
    for h in 0..<8 {
        var e = try flattened(degrees)
        let before = try box(e), (dx, dy) = outward(h)
        let grip = FakeShapes.handle(h, on: before), fixed = FakeShapes.handle(h + 4, on: before)
        let pointer = Point(x: grip.x + dx, y: grip.y + dy)
        try drag(h, in: &e) { _ in pointer }
        let after = try box(e), t = try transform(e), label = "\(degrees)° handle \(h): \(before) -> \(after)"
        #expect(t.scaleX != 0 || t.scaleY != 0, "\(label), \(t)")
        if dx != 0 { #expect(after.width > before.width + 1, "\(label)") }
        if dy != 0 { #expect(after.height > before.height + 1, "\(label)") }
        let stay = FakeShapes.handle(h + 4, on: after)
        #expect(abs(stay.x - fixed.x) < 1e-6 && abs(stay.y - fixed.y) < 1e-6, "\(label): fixed \(fixed) -> \(stay)")
        if h % 2 == 1 {
            // An edge's grip lands on the pointer along its axis.
            let landed = FakeShapes.handle(h, on: after)
            let miss = h % 4 == 1 ? landed.y - pointer.y : landed.x - pointer.x
            #expect(abs(miss) < 1e-6, "\(label): grip \(landed) vs pointer \(pointer)")
        }
    }
}

@Test(arguments: [(45.0, 4), (135.0, 6)])
func aCornerOutwardOnAKeyedFlatLayerNeverCollapses(_ degrees: Double, _ h: Int) throws {
    // The issue's last rows: scaleX keyed to 0, the state an edge drop leaves, then a corner dragged outward.
    var e = try engine(rotated: degrees)
    try e.perform(SetKeyframe(owner: .scene("scene-1"), layerID: "shadow", property: "scaleX", keyframe: Keyframe(frame: 0, value: 0)))
    let before = try box(e), (dx, dy) = outward(h)
    try drag(h, in: &e) { b in
        let g = FakeShapes.handle(h, on: b)
        return Point(x: g.x + dx, y: g.y + dy)
    }
    let after = try box(e), t = try transform(e)
    #expect(t.scaleY != 0, "\(degrees)° handle \(h): \(t)")
    #expect(after.width > before.width + 1 && after.height > before.height + 1, "\(before) -> \(after)")
}
