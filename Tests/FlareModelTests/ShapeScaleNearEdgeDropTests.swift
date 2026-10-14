// ShapeScaleNearEdgeDropTests.swift: #698, Scale on a layer square to the world never leaves it 0 wide or tall when
// a handle lands within rounding of the opposite edge's line, as the viewport maps a drop on it at a fractional zoom.
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

private func drag(_ handle: Int, in engine: inout CommandEngine, to: (Rect) -> Point) throws {
    let b = try box(engine)
    try shapes.commitBox(.scale(handle: handle, to: to(b)), layers: ["shadow"],
                         sceneID: "scene-1", frame: 0, box: b, autoKey: false, in: &engine)
}

/// The world offset that drags handle `h` 60 pt straight out of its box.
private func outward(_ h: Int) -> (dx: Double, dy: Double) {
    (dx: [2, 3, 4].contains(h) ? 60 : [0, 6, 7].contains(h) ? -60 : 0,
     dy: [4, 5, 6].contains(h) ? 60 : [0, 1, 2].contains(h) ? -60 : 0)
}

/// `v` drawn at `zoom` past a 20 pt origin, and mapped back as the viewport does: `(point - origin) / scale`.
private func roundTrip(_ v: Double, zoom: Double) -> Double { (v * zoom + 20 - 20) / zoom }

/// Where a drop on the line at `v` can land: exactly on it, one ulp to each side, and its round trip at each zoom.
private func near(_ v: Double) -> [Double] {
    [v, v.nextDown, v.nextUp] + [0.7, 0.3, 0.9, 1.1, 1.5, 3].map { roundTrip(v, zoom: $0) }
}

/// Each edge handle dropped near the opposite edge, and handle 4 near the left edge's line below the box.
private let drops: [(handle: Int, to: @Sendable (Rect, Int) -> Point)] = [
    (3, { b, i in Point(x: near(b.minX)[i], y: (b.minY + b.maxY) / 2) }), (7, { b, i in Point(x: near(b.maxX)[i], y: (b.minY + b.maxY) / 2) }),
    (1, { b, i in Point(x: (b.minX + b.maxX) / 2, y: near(b.maxY)[i]) }), (5, { b, i in Point(x: (b.minX + b.maxX) / 2, y: near(b.minY)[i]) }),
    (4, { b, i in Point(x: near(b.minX)[i], y: b.maxY + 40) }),
]

@Test func theViewportMapsTheShadowsEdgesOffTheLineAt70Percent() {
    // The issue's premise: at 70% the drawn edges come back one ulp off, so these drops are reachable by hand.
    #expect(roundTrip(344, zoom: 0.7) == Double(344).nextDown)
    #expect(roundTrip(235, zoom: 0.7) == Double(235).nextUp)
}

@Test(arguments: [0.0, 90, 180, 270])
func aDropWithinRoundingOfTheOppositeLineLeavesALayerEveryHandleGrows(_ degrees: Double) throws {
    for (d, drop) in drops.enumerated() {
        for i in 0..<9 {
            var e = try engine(rotated: degrees)
            try drag(drop.handle, in: &e) { drop.to($0, i) }
            let dropped = try box(e)
            #expect(dropped.width > 1 && dropped.height > 1, "\(degrees)° drop \(d).\(i): \(dropped)")
            for h in 0..<8 {
                let before = try box(e)
                let (dx, dy) = outward(h)
                try drag(h, in: &e) { b in
                    let g = FakeShapes.handle(h, on: b)
                    return Point(x: g.x + dx, y: g.y + dy)
                }
                let after = try box(e)
                #expect(after.width >= before.width + abs(dx) - 1e-6 && after.height >= before.height + abs(dy) - 1e-6,
                        "\(degrees)° drop \(d).\(i) handle \(h): \(before) -> \(after)")
            }
        }
    }
}

@Test(arguments: [0.0, 90])
func theNearEdgeReproGrowsBack(_ degrees: Double) throws {
    // #698's repro: handle 5 at y = minY.nextUp, or handle 4 at (minX.nextUp, maxY + 40); then every handle
    // dragged (+60, +60) left the box 0 tall (or wide).
    let firsts: [(Int, (Rect) -> Point)] = [(5, { Point(x: 0, y: $0.minY.nextUp) }),
                                            (4, { Point(x: $0.minX.nextUp, y: $0.maxY + 40) })]
    for (h, to) in firsts {
        var e = try engine(rotated: degrees)
        try drag(h, in: &e, to: to)
        for k in 0..<8 {
            try drag(k, in: &e) { b in
                let g = FakeShapes.handle(k, on: b)
                return Point(x: g.x + 60, y: g.y + 60)
            }
        }
        let after = try box(e)
        #expect(after.width > 1 && after.height > 1, "\(degrees)° handle \(h): \(after)")
    }
}

@Test func aDropWithinRoundingOfTheLineLeavesTheLayerAsItWas() throws {
    var e = try engine(rotated: 0)
    let was = e.document
    try drag(5, in: &e) { Point(x: ($0.minX + $0.maxX) / 2, y: roundTrip($0.minY, zoom: 0.7)) }
    #expect(e.document == was)
    #expect(!e.canUndo)
}
