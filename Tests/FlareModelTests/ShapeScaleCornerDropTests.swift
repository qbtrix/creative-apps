// ShapeScaleCornerDropTests.swift: #682, a corner dropped exactly on the opposite corner never leaves Scale at 0 x 0,
// so a later handle drag can still grow the layer, as #655 made an edge dropped on the opposite edge.
import FlareCore
import FlareModel
import Testing

private let shapes = FlareServices.fake().shapes
private let shadow = StageAddress(owner: .scene("scene-1"), layerID: "shadow", item: .shape(0))

private func engine(rotated degrees: Double, mirrored: Bool = false) throws -> CommandEngine {
    var engine = CommandEngine(document: FlareFixtures.bounce)
    if degrees != 0 {
        try engine.perform(SetKeyframe(sceneID: "scene-1", layerID: "shadow", property: "rotation",
                                       keyframe: Keyframe(frame: 0, value: degrees)))
    }
    if mirrored {
        try engine.perform(SetKeyframe(sceneID: "scene-1", layerID: "shadow", property: "scaleX",
                                       keyframe: Keyframe(frame: 0, value: -1)))
    }
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

@Test func theIssueReproGrowsBack() throws {
    // #682's repro: handle 4 dropped on handle 0 set scaleX = scaleY = 0, and a later drag of handle 4 kept 0 x 0.
    var e = try engine(rotated: 0)
    let was = try transform(e)
    try drag(4, in: &e) { FakeShapes.handle(0, on: $0) }
    // A zero-size drop leaves the layer as it was, with no undo step.
    #expect(try transform(e) == was)
    #expect(!e.canUndo)
    try drag(4, in: &e) { Point(x: $0.maxX + 60, y: $0.maxY + 60) }
    let after = try box(e)
    #expect(after.width > 1 && after.height > 1, "\(after)")
}

@Test(arguments: [0.0, 10, 30, 44, 45, 46, 60, 80, 135, 200, -30], [false, true])
func everyCornerDroppedOnItsOppositeGrowsBack(_ degrees: Double, _ mirrored: Bool) throws {
    for corner in [0, 2, 4, 6] {
        var e = try engine(rotated: degrees, mirrored: mirrored)
        try drag(corner, in: &e) { FakeShapes.handle(corner + 4, on: $0) }
        let flat = try transform(e)
        #expect(flat.scaleX != 0 || flat.scaleY != 0, "\(degrees)° corner \(corner): never 0 x 0")
        try drag(4, in: &e) { b in
            let grip = FakeShapes.handle(4, on: b)
            return Point(x: grip.x + 60, y: grip.y + 60)
        }
        let after = try box(e), now = try transform(e)
        #expect(now.scaleX != 0 && now.scaleY != 0, "\(degrees)° corner \(corner): \(now.scaleX) x \(now.scaleY)")
        #expect(after.width > 1 && after.height > 1, "\(degrees)° corner \(corner): \(after)")
    }
}
