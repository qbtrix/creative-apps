// StageFakesTests.swift: the LM-0a2 fakes on the `empty` and `bounce` fixtures (docs/blueprints/flare.md, 7.1): bounce
// draws 3 items in paint order, a hit at Ball's center returns Ball, removing the last scene throws, and a guide drag
// of 50 steps is one undo entry.
import FlareCore
import FlareModel
import Testing

private let services = FlareServices.fake()
private let bounce = FlareFixtures.bounce
private func address(_ layerID: String, _ item: StageAddress.Item = .shape(0)) -> StageAddress {
    StageAddress(owner: .scene("scene-1"), layerID: layerID, item: item)
}

@Test func fixturesAreNamedAndValid() throws {
    #expect(FlareFixtures.all.map(\.name) == ["empty", "bounce", "character", "button", "button with machine"] && FlareFixtures.named("nope") == nil)
    #expect(FlareFixtures.named("empty")?.scenes.map(\.layers.isEmpty) == [true])
    for fixture in FlareFixtures.all { try FlareFormat.validate(fixture.document) }
    let scene = try #require(bounce.scenes.first)
    #expect(scene.fps == 24 && scene.durationFrames == 48 && scene.layers.map(\.name) == ["Background", "Shadow", "Ball"])
    let keyed = ["x", "y", "scaleX", "scaleY"].map { scene.layers[2].tracks[$0]?.map(\.frame) }
    #expect(keyed.allSatisfy { $0 == [0, 12, 24, 36, 47] } && scene.layers[1].tracks.isEmpty)
}

@Test func bounceDrawsThreeItemsInPaintOrder() {
    let list = services.stage.drawList(bounce, sceneID: "scene-1", frame: 0, editing: nil)
    #expect(list.items.map(\.address) == [address("background"), address("shadow"), address("ball")])
    #expect(list.width == 550 && list.height == 400 && list.hiddenTextCount == 0)
    // Ball is placed by its keys: at frame 12 it sits at (180, 320), squashed.
    let ball = services.stage.drawList(bounce, sceneID: "scene-1", frame: 12, editing: nil).items.last
    #expect(ball?.transform == Matrix(a: 1.25, b: 0, c: 0, d: 0.75, tx: 180, ty: 320))
    #expect(services.stage.drawList(FlareFixtures.empty, sceneID: "scene-1", frame: 0, editing: nil).items.isEmpty)
}

@Test func hiddenLayersAreSkippedAndTextIsCountedNotDrawn() {
    var doc = bounce
    doc.scenes[0].layers[1].isVisible = false
    doc.scenes[0].layers[2].texts = [TextShape(string: "Hi", fontFamily: "Helvetica", fontSize: 12, position: Point(x: 0, y: 0))]
    let list = services.stage.drawList(doc, sceneID: "scene-1", frame: 0, editing: nil)
    #expect(list.items.map(\.address.layerID) == ["background", "ball", "ball"] && list.hiddenTextCount == 1)
    #expect(list.items[2].isText && list.items[2].path.elements.isEmpty && list.items[2].address.item == .text(0))
}

@Test func instancesDrawOneLevelDeep() {
    let dot = Layer(id: "dot", name: "Dot", shapes: [FlareShape(points: [Point(x: 0, y: 0), Point(x: 10, y: 10)])],
                    instances: [Instance(symbolID: "inner")])
    let host = Layer(id: "host", name: "Host", instances: [Instance(symbolID: "star", transform: Transform(x: 100, y: 50))])
    let doc = Document(scenes: [FlareScene(id: "scene-1", name: "Scene 1", layers: [host])], symbols: [
        Symbol(id: "star", name: "Star", layers: [dot]),
        Symbol(id: "inner", name: "Inner", layers: [Layer(id: "deep", name: "Deep", shapes: dot.shapes)]),
    ])
    let list = services.stage.drawList(doc, sceneID: "scene-1", frame: 0, editing: nil)
    #expect(list.items.map(\.address) == [address("host", .instance(0))] && list.items.first?.transform == .translation(x: 100, y: 50))
    #expect(services.hits.hit(doc, sceneID: "scene-1", frame: 0, at: Point(x: 105, y: 55), tolerance: 0) == address("host", .instance(0)))
    // Editing Star in place draws its own layer, whose Inner instance is now one level deep.
    let editing = services.stage.drawList(doc, sceneID: "scene-1", frame: 0, editing: "star").items.map(\.address)
    #expect(editing.map(\.item) == [.shape(0), .instance(0)] && editing.allSatisfy { $0.owner == .symbol("star") })
}

@Test func aHitAtBallsCenterReturnsBallAndTheMarqueeAndBoundsCoverIt() throws {
    let hits = services.hits
    #expect(hits.hit(bounce, sceneID: "scene-1", frame: 0, at: Point(x: 80, y: 100), tolerance: 0) == address("ball"))
    // Background is locked, so an empty spot on the artboard hits nothing; unlocked, it is hit edges and tolerance included.
    #expect(hits.hit(bounce, sceneID: "scene-1", frame: 0, at: Point(x: 500, y: 20), tolerance: 0) == nil)
    var unlocked = bounce
    unlocked.scenes[0].layers[0].isLocked = false
    #expect(hits.hit(unlocked, sceneID: "scene-1", frame: 0, at: Point(x: 500, y: 20), tolerance: 0) == address("background"))
    #expect(hits.hit(unlocked, sceneID: "scene-1", frame: 0, at: Point(x: 600, y: 20), tolerance: 0) == nil)
    #expect(hits.hit(unlocked, sceneID: "scene-1", frame: 0, at: Point(x: 553, y: 20), tolerance: 4) == address("background"))
    unlocked.scenes[0].layers[2].isLocked = true
    #expect(hits.hit(unlocked, sceneID: "scene-1", frame: 0, at: Point(x: 80, y: 100), tolerance: 0) == address("background"))
    let rect = Rect(minX: 40, minY: 60, maxX: 120, maxY: 140)
    #expect(hits.marquee(bounce, sceneID: "scene-1", frame: 0, rect: rect) == [address("ball")])
    let box = try #require(hits.bounds(bounce, sceneID: "scene-1", frame: 0, of: [address("ball")]))
    #expect(abs(box.minX - 50) < 1e-9 && abs(box.maxX - 110) < 1e-9 && abs(box.minY - 70) < 1e-9 && abs(box.maxY - 130) < 1e-9)
    #expect(hits.bounds(bounce, sceneID: "scene-1", frame: 0, of: []) == nil)
}

@Test func j5MarqueeAroundBallAndShadowSelectsExactlyThoseTwo() {
    // J5 (docs/blueprints/flare.md, section 5): on bounce, a marquee around Ball and Shadow gives 2, and a click on the
    // empty stage gives 0, because the full-canvas Background is locked.
    let rect = Rect(minX: 30, minY: 40, maxX: 330, maxY: 370)
    #expect(services.hits.marquee(bounce, sceneID: "scene-1", frame: 0, rect: rect) == [address("shadow"), address("ball")])
    #expect(services.hits.hit(bounce, sceneID: "scene-1", frame: 0, at: Point(x: 500, y: 30), tolerance: 0) == nil)
    #expect(bounce.scenes.first?.layers.first.map { $0.name == "Background" && $0.isLocked && $0.isVisible } == true)
}

@Test func removingTheLastSceneThrows() throws {
    var engine = CommandEngine(document: bounce)
    #expect(throws: CommandError.invalidDocument(FakeScenes.lastSceneMessage)) { try services.scenes.removeScene("scene-1", in: &engine) }
    #expect(engine.document == bounce && !engine.canUndo)
    #expect(try services.scenes.addScene(.web, in: &engine) == "scene-2" && engine.document.scenes.map(\.name) == ["Scene 1", "Scene 2"])
    try services.scenes.removeScene("scene-1", in: &engine)
    #expect(engine.document.scenes.map(\.id) == ["scene-2"] && engine.undoActionName == "Undo Delete Scene")
    #expect(throws: CommandError.sceneNotFound("nope")) { try services.scenes.removeScene("nope", in: &engine) }
}

@Test func sceneEditsAreOneUndoStepEach() throws {
    var engine = CommandEngine(document: services.scenes.newDocument(.square))
    _ = try services.scenes.addScene(.vertical, in: &engine)
    try services.scenes.renameScene("scene-2", to: "Outro", in: &engine)
    try services.scenes.reorderScene("scene-2", to: 0, in: &engine)
    try services.scenes.setCanvas("scene-2", width: 640, height: 360, background: .black, in: &engine)
    try services.scenes.setTiming("scene-2", fps: 12, durationFrames: 24, in: &engine)
    let outro = engine.document.scenes[0]
    #expect(outro.name == "Outro" && outro.width == 640 && outro.background == .black && outro.fps == 12 && engine.document.scenes[1].width == 1080)
    for name in ["Set Scene Timing", "Set Canvas", "Move Scene", "Rename Scene", "Add Scene"] {
        #expect(engine.undoActionName == "Undo \(name)")
        try engine.undo()
    }
    #expect(engine.document == services.scenes.newDocument(.square))
    #expect(throws: CommandError.self) { try services.scenes.setCanvas("scene-1", width: 0, height: 1, background: .white, in: &engine) }
    #expect(throws: CommandError.sceneNotFound("nope")) { try services.scenes.renameScene("nope", to: "X", in: &engine) }
}

@Test func aGuideDragOfFiftyStepsIsOneUndoEntry() throws {
    var engine = CommandEngine(document: bounce)
    let index = try services.scenes.addGuide(.horizontal, at: 300, sceneID: "scene-1", in: &engine)
    for step in 1...50 {
        try services.scenes.moveGuide(at: index, to: 300 + Double(step), sceneID: "scene-1", coalesceKey: "guide", in: &engine)
    }
    #expect(engine.document.scenes[0].guides == [Guide(axis: .horizontal, position: 350)] && engine.undoActionName == "Undo Move Guide")
    try engine.undo()
    #expect(engine.document.scenes[0].guides == [Guide(axis: .horizontal, position: 300)] && engine.undoActionName == "Undo Add Guide")
    try services.scenes.removeGuide(at: 0, sceneID: "scene-1", in: &engine)
    #expect(engine.document.scenes[0].guides.isEmpty)
}

@Test func anUnavailableFakeIsEmptyAndRefusesWrites() {
    let reason = "Not connected yet (IN-4)."
    var engine = CommandEngine(document: bounce)
    #expect(throws: NotBuilt(reason: reason)) { try FakeScenes(unavailable: reason).renameScene("scene-1", to: "X", in: &engine) }
    #expect(engine.document == bounce && !engine.canUndo && FakeScenes(unavailable: reason).newDocument(.web).scenes.isEmpty)
    #expect(FakeStage(unavailable: reason).drawList(bounce, sceneID: "scene-1", frame: 0, editing: nil).items.isEmpty)
    #expect(FakeHits(unavailable: reason).hit(bounce, sceneID: "scene-1", frame: 0, at: Point(x: 80, y: 100), tolerance: 4) == nil)
    #expect(FakeHits(unavailable: reason).bounds(bounce, sceneID: "scene-1", frame: 0, of: [address("ball")]) == nil)
}
