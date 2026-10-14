// ShapeScaleAxisDropTests.swift: #688, Scale on a layer square to the world (0° or 90°) never leaves scaleX or scaleY
// at 0 when a handle lands on the opposite edge's line, so a later edge or corner drag outward still grows the layer.
import FlareCore
import FlareModel
import Testing

private let shapes = FlareServices.fake().shapes
private let shadow = StageAddress(owner: .scene("scene-1"), layerID: "shadow", item: .shape(0))

private func engine(rotated degrees: Double) throws -> CommandEngine {
    var engine = CommandEngine(document: FlareFixtures.bounce)
    if degrees != 0 {
        try engine.perform(SetKeyframe(sceneID: "scene-1", layerID: "shadow", property: "rotation",
                                       keyframe: Keyframe(frame: 0, value: degrees)))
    }
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

/// Drags handle `h` 60 pt right and 60 pt down from where it is.
private func push(_ h: Int, in engine: inout CommandEngine) throws {
    try drag(h, in: &engine) { b in
        let g = FakeShapes.handle(h, on: b)
        return Point(x: g.x + 60, y: g.y + 60)
    }
}

/// The world offset that drags handle `h` 60 pt straight out of its box.
private func outward(_ h: Int) -> (dx: Double, dy: Double) {
    (dx: [2, 3, 4].contains(h) ? 60 : [0, 6, 7].contains(h) ? -60 : 0,
     dy: [4, 5, 6].contains(h) ? 60 : [0, 1, 2].contains(h) ? -60 : 0)
}

/// Every edge and corner handle dropped on the opposite edge's line: edges on the opposite edge, corners at the
/// opposite x (below or above the box) and at the opposite y (beside the box).
private let drops: [(handle: Int, to: @Sendable (Rect) -> Point)] = [
    (3, { FakeShapes.handle(7, on: $0) }), (7, { FakeShapes.handle(3, on: $0) }),
    (1, { FakeShapes.handle(5, on: $0) }), (5, { FakeShapes.handle(1, on: $0) }),
    (4, { Point(x: $0.minX, y: $0.maxY + 40) }), (4, { Point(x: $0.maxX + 40, y: $0.minY) }),
    (0, { Point(x: $0.maxX, y: $0.minY - 40) }), (0, { Point(x: $0.minX - 40, y: $0.maxY) }),
    (2, { Point(x: $0.minX, y: $0.minY - 40) }), (2, { Point(x: $0.maxX + 40, y: $0.maxY) }),
    (6, { Point(x: $0.maxX, y: $0.maxY + 40) }), (6, { Point(x: $0.minX - 40, y: $0.minY) }),
]

@Test(arguments: [0.0, 90])
func theIssueReproGrowsBack(_ degrees: Double) throws {
    // #688's repro: handle 4 dropped at (minX, maxY + 40) left the box 0 wide, and every handle dragged (+60, +60)
    // kept it 0 wide.
    var e = try engine(rotated: degrees)
    try drag(4, in: &e) { Point(x: $0.minX, y: $0.maxY + 40) }
    for h in 0..<8 { try push(h, in: &e) }
    let after = try box(e), t = try transform(e)
    #expect(after.width > 1 && after.height > 1, "\(degrees)°: \(after)")
    #expect(t.scaleX != 0 && t.scaleY != 0, "\(degrees)°: \(t.scaleX) x \(t.scaleY)")
}

@Test(arguments: [0.0, 90])
func theIssueTestGrowsBack(_ degrees: Double) throws {
    // The issue's test: handle 3 on handle 7, or handle 4 at (minX, maxY + 40); then handle 3 by (+60, 0) and
    // handle 4 by (+60, +60).
    let firsts: [(Int, (Rect) -> Point)] = [(3, { FakeShapes.handle(7, on: $0) }),
                                            (4, { Point(x: $0.minX, y: $0.maxY + 40) })]
    for (h, to) in firsts {
        var e = try engine(rotated: degrees)
        try drag(h, in: &e, to: to)
        try drag(3, in: &e) { b in
            let g = FakeShapes.handle(3, on: b)
            return Point(x: g.x + 60, y: g.y)
        }
        try push(4, in: &e)
        let after = try box(e), t = try transform(e)
        #expect(after.width > 1 && after.height > 1, "\(degrees)° handle \(h): \(after)")
        #expect(t.scaleX != 0 && t.scaleY != 0, "\(degrees)° handle \(h): \(t.scaleX) x \(t.scaleY)")
    }
}

@Test(arguments: [0.0, 90, 180, 270, -90])
func everyDropOnTheOppositeLineLeavesALayerEveryHandleGrows(_ degrees: Double) throws {
    for (i, drop) in drops.enumerated() {
        var e = try engine(rotated: degrees)
        try drag(drop.handle, in: &e, to: drop.to)
        let t = try transform(e), b = try box(e)
        #expect(t.scaleX != 0 && t.scaleY != 0, "\(degrees)° drop \(i): \(t.scaleX) x \(t.scaleY)")
        #expect(b.width > 1 && b.height > 1, "\(degrees)° drop \(i): \(b)")
        for h in 0..<8 {
            let before = try box(e)
            let (dx, dy) = outward(h)
            try drag(h, in: &e) { b in
                let g = FakeShapes.handle(h, on: b)
                return Point(x: g.x + dx, y: g.y + dy)
            }
            let after = try box(e)
            #expect(after.width >= before.width + abs(dx) - 1e-6 && after.height >= before.height + abs(dy) - 1e-6,
                    "\(degrees)° drop \(i) handle \(h): \(before) -> \(after)")
        }
    }
}

@Test func aDropThatZeroesAnAxisLeavesTheLayerAsItWas() throws {
    var e = try engine(rotated: 0)
    let was = try transform(e)
    try drag(3, in: &e) { FakeShapes.handle(7, on: $0) }
    #expect(try transform(e) == was)
    #expect(!e.canUndo)
}
