// LiveHitsBoundsTests.swift: ST-4 of the live-stage packet. `LiveHits.marquee` over the core marquee query (LC-2) and
// `LiveHits.bounds` over the core world bounds with stroke (LC-3): a marquee around Ball and Shadow gives both in paint
// order, one over only the locked Background gives [], a 10-wide stroke grows a square's bounds by 5 on each side,
// bounds of [] are nil, a rotated layer's bounds match the core's, and `LiveHits` serves as `any StageHitTesting`.
import FlareCore
import FlareModel
import Testing

private let live = LiveHits()
private let bounce = FlareFixtures.bounce
private func address(_ layerID: String, _ item: StageAddress.Item = .shape(0),
                     owner: LayerOwner = .scene("scene-1")) -> StageAddress {
    StageAddress(owner: owner, layerID: layerID, item: item)
}
private func square(_ id: String, stroke: Stroke? = nil, tracks: [String: [Keyframe]] = [:]) -> Document {
    let shape = FlareShape(points: [Point(x: 100, y: 100), Point(x: 140, y: 100), Point(x: 140, y: 140), Point(x: 100, y: 140)],
                           stroke: stroke)
    return Document(scenes: [FlareScene(id: "scene-1", name: "Scene 1", layers: [
        Layer(id: id, name: id, shapes: [shape], tracks: tracks),
    ])])
}

@Test func aMarqueeAroundBallAndShadowGivesBothInPaintOrder() {
    // Ball is a radius-30 circle at (80, 100) at frame 0; Shadow an 80 × 16 ellipse at (275, 352).
    let rect = Rect(minX: 40, minY: 60, maxX: 330, maxY: 370)
    #expect(live.marquee(bounce, sceneID: "scene-1", frame: 0, editing: nil, rect: rect) == [address("shadow"), address("ball")])
    // Only the locked Background lies under this rect.
    let empty = Rect(minX: 400, minY: 10, maxX: 540, maxY: 60)
    #expect(live.marquee(bounce, sceneID: "scene-1", frame: 0, editing: nil, rect: empty) == [])
    #expect(live.marquee(bounce, sceneID: "nope", frame: 0, editing: nil, rect: rect) == [])
}

@Test func editingASymbolMarqueesItsItemsAndAnInstanceAnswersOnce() {
    let dot = FlareShape(points: [Point(x: 0, y: 0), Point(x: 10, y: 0), Point(x: 10, y: 10), Point(x: 0, y: 10)])
    let symbol = Symbol(id: "star", name: "Star", layers: [Layer(id: "dot", name: "Dot", shapes: [dot, dot])])
    let host = Layer(id: "host", name: "Host", instances: [Instance(symbolID: "star", transform: Transform(x: 100, y: 50))])
    let doc = Document(scenes: [FlareScene(id: "scene-1", name: "Scene 1", layers: [host])], symbols: [symbol])
    let all = Rect(minX: -20, minY: -20, maxX: 200, maxY: 200)
    #expect(live.marquee(doc, sceneID: "scene-1", frame: 0, editing: nil, rect: all) == [address("host", .instance(0))])
    #expect(live.marquee(doc, sceneID: "scene-1", frame: 0, editing: "star", rect: all)
        == [address("dot", owner: .symbol("star")), address("dot", .shape(1), owner: .symbol("star"))])
    let bounds = live.bounds(doc, sceneID: "scene-1", frame: 0, editing: nil, of: [address("host", .instance(0))])
    #expect(bounds == Rect(minX: 100, minY: 50, maxX: 110, maxY: 60))
}

@Test func aStrokedSquaresBoundsGrowByHalfTheStroke() throws {
    let doc = square("sq", stroke: Stroke(width: 10))
    let bounds = try #require(live.bounds(doc, sceneID: "scene-1", frame: 0, editing: nil, of: [address("sq")]))
    #expect(bounds == Rect(minX: 95, minY: 95, maxX: 145, maxY: 145))
    #expect(live.bounds(doc, sceneID: "scene-1", frame: 0, editing: nil, of: []) == nil)
    #expect(live.bounds(doc, sceneID: "nope", frame: 0, editing: nil, of: [address("sq")]) == nil)
}

@Test func aRotatedLayersBoundsMatchTheCores() throws {
    let doc = square("turned", stroke: Stroke(width: 4), tracks: ["rotation": [Keyframe(frame: 0, value: 30)]])
    let list = doc.scenes[0].renderList(at: 0, symbols: doc.symbols)
    let core = try #require(list.worldBounds(of: list.items.map(\.address)))
    let mine = try #require(live.bounds(doc, sceneID: "scene-1", frame: 0, editing: nil, of: [address("turned")]))
    #expect(abs(mine.minX - core.minX) < 1e-9 && abs(mine.minY - core.minY) < 1e-9)
    #expect(abs(mine.maxX - core.maxX) < 1e-9 && abs(mine.maxY - core.maxY) < 1e-9)
    // The rotation widens the box beyond the unrotated 40-wide square.
    #expect(mine.maxX - mine.minX > 44)
}

@Test func liveHitsServesAsStageHitTesting() {
    let h: any StageHitTesting = LiveHits()
    let rect = Rect(minX: 40, minY: 60, maxX: 120, maxY: 140)
    #expect(h.marquee(bounce, sceneID: "scene-1", frame: 0, rect: rect) == [address("ball")])
    #expect(h.bounds(bounce, sceneID: "scene-1", frame: 0, of: [address("ball")]) != nil)
}
