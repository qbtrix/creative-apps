// LiveHitsTests.swift: ST-3 of the live-stage packet. `LiveHits.hit` over the core topmost hit (LC-2): Ball's center
// hits Ball and its bounding-box corner misses (the core is geometric), the tolerance reaches a 0-width stroke, locked,
// hidden and text items are never hit, editing a symbol hits only its items, and live equals `FakeHits` wherever both
// are exact (every shape's center, and points far outside every box).
import FlareCore
import FlareModel
import Testing

private let live = LiveHits()
private let bounce = FlareFixtures.bounce
private func address(_ layerID: String, _ item: StageAddress.Item = .shape(0),
                     owner: LayerOwner = .scene("scene-1")) -> StageAddress {
    StageAddress(owner: owner, layerID: layerID, item: item)
}
private func hit(_ doc: Document, _ x: Double, _ y: Double, tolerance: Double = 0, editing: String? = nil,
                 frame: Int = 0) -> StageAddress? {
    live.hit(doc, sceneID: "scene-1", frame: frame, editing: editing, at: Point(x: x, y: y), tolerance: tolerance)
}

@Test func ballsCenterHitsBallAndItsBoxCornerMisses() {
    #expect(hit(bounce, 80, 100) == address("ball"))
    // Ball is a radius-30 circle at (80, 100): (55, 75) is inside its box, about 35 from the center.
    #expect(hit(bounce, 55, 75) == nil)
    #expect(FakeHits().hit(bounce, sceneID: "scene-1", frame: 0, at: Point(x: 55, y: 75), tolerance: 0) == address("ball"))
    // At frame 12 Ball sits at (180, 320), squashed.
    #expect(hit(bounce, 180, 320, frame: 12) == address("ball"))
}

@Test func theToleranceReachesAZeroWidthStroke() {
    let line = FlareShape(points: [Point(x: 100, y: 100), Point(x: 200, y: 100)], closed: false, stroke: Stroke(width: 0))
    let doc = Document(scenes: [FlareScene(id: "scene-1", name: "Scene 1", layers: [Layer(id: "line", name: "Line", shapes: [line])])])
    #expect(hit(doc, 150, 104, tolerance: 4) == address("line"))
    #expect(hit(doc, 150, 104, tolerance: 0) == nil)
    #expect(hit(doc, 150, 105, tolerance: 4) == nil)
}

@Test func lockedHiddenAndTextItemsAreNeverHit() {
    // The locked Background fills the canvas, so an empty spot hits nothing.
    #expect(hit(bounce, 500, 20) == nil && hit(bounce, 500, 20, tolerance: 4) == nil)
    var unlocked = bounce
    unlocked.scenes[0].layers[0].isLocked = false
    #expect(hit(unlocked, 500, 20) == address("background"))
    var hidden = bounce
    hidden.scenes[0].layers[2].isVisible = false
    #expect(hit(hidden, 80, 100) == nil)
    var lockedBall = unlocked
    lockedBall.scenes[0].layers[2].isLocked = true
    #expect(hit(lockedBall, 80, 100) == address("background"))
    var text = Document(scenes: [FlareScene(id: "scene-1", name: "Scene 1", layers: [Layer(id: "t", name: "T")])])
    text.scenes[0].layers[0].texts = [TextShape(string: "Hi", fontFamily: "Helvetica", fontSize: 12, position: Point(x: 0, y: 0))]
    #expect(hit(text, 0, 0, tolerance: 4) == nil)
    #expect(live.hit(bounce, sceneID: "nope", frame: 0, editing: nil, at: Point(x: 80, y: 100), tolerance: 0) == nil)
}

@Test func insideASymbolOnlyItsItemsHit() {
    let dot = Layer(id: "dot", name: "Dot", shapes: [FlareShape(points: [Point(x: 0, y: 0), Point(x: 10, y: 0),
                                                                          Point(x: 10, y: 10), Point(x: 0, y: 10)])])
    let host = Layer(id: "host", name: "Host", instances: [Instance(symbolID: "star", transform: Transform(x: 100, y: 50))])
    let doc = Document(scenes: [FlareScene(id: "scene-1", name: "Scene 1", layers: [host])],
                       symbols: [Symbol(id: "star", name: "Star", layers: [dot])])
    #expect(hit(doc, 105, 55) == address("host", .instance(0)))
    #expect(hit(doc, 5, 5) == nil)
    #expect(hit(doc, 5, 5, editing: "star") == address("dot", owner: .symbol("star")))
    #expect(hit(doc, 105, 55, editing: "star") == nil)
    #expect(hit(doc, 5, 5, editing: "missing") == nil)
}

@Test func liveEqualsFakeWhereBothAreExact() throws {
    let fake = FakeHits()
    for doc in [bounce, FlareFixtures.character] {
        for frame in [0, 12] {
            let items = FakeStage().drawList(doc, sceneID: "scene-1", frame: frame, editing: nil).items
            var boxes: [Rect] = []
            for item in items {
                let local = try #require(item.path.bounds)
                let corners = [Point(x: local.minX, y: local.minY), Point(x: local.maxX, y: local.minY),
                               Point(x: local.minX, y: local.maxY), Point(x: local.maxX, y: local.maxY)]
                boxes.append(try #require(Rect(enclosing: corners.map(item.transform.apply))))
            }
            let centers = boxes.map { Point(x: ($0.minX + $0.maxX) / 2, y: ($0.minY + $0.maxY) / 2) }
            let all = try #require(Rect(enclosing: boxes.flatMap { [Point(x: $0.minX, y: $0.minY), Point(x: $0.maxX, y: $0.maxY)] }))
            let far = (0..<10).map { i -> Point in
                let x = i % 2 == 0 ? all.minX - 50 - Double(i) * 7 : all.maxX + 50 + Double(i) * 7
                let y = i < 5 ? all.minY - 60 - Double(i) * 3 : all.maxY + 60 + Double(i) * 3
                return Point(x: x, y: y)
            }
            for point in centers + far {
                let l = live.hit(doc, sceneID: "scene-1", frame: frame, editing: nil, at: point, tolerance: 0)
                let f = fake.hit(doc, sceneID: "scene-1", frame: frame, editing: nil, at: point, tolerance: 0)
                #expect(l == f, "frame \(frame) at \(point)")
            }
            #expect(centers.count == items.count && far.count == 10)
        }
    }
}
