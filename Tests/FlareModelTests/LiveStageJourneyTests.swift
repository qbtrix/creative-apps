// LiveStageJourneyTests.swift: ST-10 of live-stage (#798), the Model half of J3 (draw with each tool) and J5 (select,
// marquee, scale, rotate) on the live types. The two tests walk the packet's "Journey steps" 1-6 in order on
// `LiveStage`, `LiveHits` and `LiveShapes` with a real `CommandEngine`: names, counts and values as J3 and J5 give them,
// and every commit, box gesture and paste one named undo entry.
import FlareCore
import FlareModel
import Testing

private let owner = LayerOwner.scene("scene-1")
private let stage = LiveStage(), hits = LiveHits(), shapes = LiveShapes()
private func pt(_ x: Double, _ y: Double) -> Point { Point(x: x, y: y) }
private func names(_ engine: CommandEngine) -> [String] { (engine.document.layers(of: owner) ?? []).map(\.name) }
private func cubics(_ path: FlarePath) -> Int { path.elements.filter { if case .cubic = $0 { true } else { false } }.count }

/// The last change was one entry named `name`: one undo() gives back `before` and leaves `canUndo` as it was before;
/// redo() puts the change back so the journey carries on.
private func expectOneStep(_ engine: inout CommandEngine, named name: String, from before: CommandEngine) throws {
    #expect(engine.undoActionName == "Undo \(name)")
    let after = engine.document
    try engine.undo()
    #expect(engine.document == before.document && engine.canUndo == before.canUndo, "\(name)")
    try engine.redo()
    #expect(engine.document == after)
}

/// A pen draft clicked through `clicks`, each (point, where the press was released).
private func pen(_ clicks: [(Point, Point)]) -> ShapeDraft? {
    clicks.reduce(nil as ShapeDraft?) { draft, click in
        shapes.draft(.pen, from: click.0, to: click.1, modifiers: [], previous: draft)
    }
}

@Test func testDrawShapesWithEachTool() throws {
    var engine = CommandEngine(document: FlareFixtures.empty)

    // 1. A Rectangle from (100, 100) to (300, 200), committed: "Rectangle 1" in one "Undo Add Rectangle".
    let rect = try #require(shapes.draft(.rectangle, from: pt(100, 100), to: pt(300, 200), modifiers: [], previous: nil))
    var before = engine
    let rectID = try shapes.commit(rect, owner: owner, aboveLayerID: nil, in: &engine)
    #expect(names(engine) == ["Rectangle 1"])
    try expectOneStep(&engine, named: "Add Rectangle", from: before)

    // 2. An Ellipse with Shift is a circle; a closed three-corner pen path and a pen path dragged at its second point
    // give "Path 1" and "Path 2", the second anchor of "Path 2" smooth.
    let oval = try #require(shapes.draft(.ellipse, from: pt(350, 100), to: pt(420, 140), modifiers: .shift, previous: nil))
    let ovalBox = try #require(oval.shape.path?.bounds)
    #expect(ovalBox.width == ovalBox.height && ovalBox.width == 70)
    before = engine
    let ovalID = try shapes.commit(oval, owner: owner, aboveLayerID: rectID, in: &engine)
    try expectOneStep(&engine, named: "Add Ellipse", from: before)

    let triangle = try #require(pen([(pt(100, 250), pt(100, 250)), (pt(200, 250), pt(200, 250)),
                                     (pt(150, 330), pt(150, 330)), (pt(100, 250), pt(100, 250))]))
    #expect(triangle.isClosed && triangle.anchors.count == 3 && triangle.smoothAnchors.isEmpty)
    before = engine
    let path1 = try shapes.commit(triangle, owner: owner, aboveLayerID: ovalID, in: &engine)
    try expectOneStep(&engine, named: "Add Path", from: before)

    let wave = try #require(pen([(pt(300, 300), pt(300, 300)), (pt(380, 260), pt(420, 300)),
                                 (pt(460, 340), pt(460, 340))]))
    #expect(!wave.isClosed && wave.smoothAnchors == [1])
    before = engine
    let path2 = try shapes.commit(wave, owner: owner, aboveLayerID: path1, in: &engine)
    try expectOneStep(&engine, named: "Add Path", from: before)
    #expect(names(engine) == ["Rectangle 1", "Ellipse 1", "Path 1", "Path 2"])

    // 3. The live draw list has those items in paint order, curves kept as cubics.
    let list = stage.drawList(engine.document, sceneID: "scene-1", frame: 0, editing: nil)
    #expect(list.items.map(\.address) == [rectID, ovalID, path1, path2].map {
        StageAddress(owner: owner, layerID: $0, item: .shape(0))
    })
    #expect(list.hiddenTextCount == 0)
    let drawn = list.items.map(\.path), drafted = [rect, oval, triangle, wave].compactMap(\.shape.path)
    #expect(drawn == drafted)
    #expect(drawn.map(cubics) == [0, 4, 0, 2])
}

@Test func testSelectMarqueeScaleRotate() throws {
    let bounce = FlareFixtures.bounce
    let ball = StageAddress(owner: owner, layerID: "ball", item: .shape(0))
    let shadow = StageAddress(owner: owner, layerID: "shadow", item: .shape(0))

    // 4. A hit at Ball's center returns Ball; the locked Background is never hit, even with tolerance; a marquee
    // around Ball and Shadow returns both in paint order, and one over the whole canvas leaves Background out.
    #expect(hits.hit(bounce, sceneID: "scene-1", frame: 0, at: pt(80, 100), tolerance: 4) == ball)
    #expect(hits.hit(bounce, sceneID: "scene-1", frame: 0, at: pt(500, 30), tolerance: 4) == nil)
    let around = Rect(minX: 40, minY: 60, maxX: 330, maxY: 370)
    #expect(hits.marquee(bounce, sceneID: "scene-1", frame: 0, rect: around) == [shadow, ball])
    let canvas = Rect(minX: -10, minY: -10, maxX: 560, maxY: 410)
    #expect(hits.marquee(bounce, sceneID: "scene-1", frame: 0, rect: canvas) == [shadow, ball])

    // 5. A scale from the bottom-right handle (4) keeps the top-left corner within 1e-9; a rotate of Ball and Shadow
    // turns both about their box's center. Each is one named entry.
    var engine = CommandEngine(document: bounce)
    func box() throws -> Rect { try #require(hits.bounds(engine.document, sceneID: "scene-1", frame: 0, of: [ball])) }
    let start = try box()
    #expect(abs(start.minX - 50) <= 1e-9 && abs(start.minY - 70) <= 1e-9)
    var before = engine
    try shapes.commitBox(.scale(handle: 4, to: pt(start.maxX + 50, start.maxY + 20)), layers: ["ball"],
                         sceneID: "scene-1", frame: 0, box: start, autoKey: false, in: &engine)
    try expectOneStep(&engine, named: "Scale", from: before)
    let scaled = try box()
    #expect(abs(scaled.minX - start.minX) <= 1e-9 && abs(scaled.minY - start.minY) <= 1e-9)
    #expect(abs(scaled.maxX - (start.maxX + 50)) <= 1e-9 && abs(scaled.maxY - (start.maxY + 20)) <= 1e-9)

    // Rotate Ball and Shadow together: their shared box's center is neither layer's origin, so each origin must turn
    // 30 degrees about that center, not stay put, and each layer's rotation grows by 30.
    func place(_ id: String) throws -> [String: Double] {
        try #require(engine.document.layers(of: owner)?.first { $0.id == id }).sample(at: 0)
    }
    let pair = try #require(hits.bounds(engine.document, sceneID: "scene-1", frame: 0, of: [ball, shadow]))
    let c = pt((pair.minX + pair.maxX) / 2, (pair.minY + pair.maxY) / 2)
    let old = try ["ball": place("ball"), "shadow": place("shadow")]
    #expect(old.values.allSatisfy { abs(($0["x"] ?? 0) - c.x) > 1 || abs(($0["y"] ?? 0) - c.y) > 1 })
    before = engine
    try shapes.commitBox(.rotate(degrees: 30), layers: ["ball", "shadow"], sceneID: "scene-1", frame: 0, box: pair,
                         autoKey: false, in: &engine)
    try expectOneStep(&engine, named: "Rotate", from: before)
    let (cos30, sin30) = (3.0.squareRoot() / 2, 0.5)
    for (id, was) in old {
        let (dx, dy) = ((was["x"] ?? 0) - c.x, (was["y"] ?? 0) - c.y), now = try place(id)
        #expect(abs((now["x"] ?? .nan) - (c.x + dx * cos30 - dy * sin30)) <= 1e-9, "\(id) x")
        #expect(abs((now["y"] ?? .nan) - (c.y + dx * sin30 + dy * cos30)) <= 1e-9, "\(id) y")
        #expect(now["rotation"] == (was["rotation"] ?? 0) + 30, "\(id) rotation")
    }

    // 6. Copy Ball, paste above it: "Ball copy" above Ball, 10 pt right, in one "Undo Paste".
    let copied = try shapes.copy(layers: ["ball"], owner: owner, from: engine.document)
    before = engine
    let pasted = try shapes.paste(copied, owner: owner, aboveLayerID: "ball", offset: 10, in: &engine)
    try expectOneStep(&engine, named: "Paste", from: before)
    #expect(pasted.count == 1 && names(engine) == ["Background", "Shadow", "Ball", "Ball copy"])
    let layers = engine.document.layers(of: owner) ?? []
    let original = try #require(layers.first { $0.id == "ball" }), copy = try #require(layers.first { $0.id == pasted.first })
    #expect(copy.tracks["x"]?.map(\.value) == original.tracks["x"]?.map { $0.value + 10 })
    #expect(copy.tracks["y"] == original.tracks["y"] && copy.shapes == original.shapes)
}
