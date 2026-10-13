// StageFakesEdgeTests.swift: edge cases for the LM-0a2 fakes (FakeScenes, FakeStage, FakeHits) on `bounce`:
// frames past either end, missing scenes and symbols, self-nesting symbols, text inside instances,
// odd hit inputs and scene edits the engine refuses.
import FlareCore
import FlareModel
import Testing

private let services = FlareServices.fake()
private let bounce = FlareFixtures.bounce
private let ball = StageAddress(owner: .scene("scene-1"), layerID: "ball", item: .shape(0))

@Test func framesPastEitherEndHoldTheEndKeys() {
    for (frame, x) in [(-10, 80.0), (Int.min, 80), (48, 470), (1000, 470), (Int.max, 470)] {
        let last = services.stage.drawList(bounce, sceneID: "scene-1", frame: frame, editing: nil).items.last
        #expect(last?.transform == .translation(x: x, y: 100))
    }
}

@Test func aMissingSceneOrSymbolDrawsNothing() {
    let none = services.stage.drawList(bounce, sceneID: "nope", frame: 0, editing: nil)
    #expect(none.items.isEmpty && none.width == 0 && none.hiddenTextCount == 0)
    let symbol = services.stage.drawList(bounce, sceneID: "scene-1", frame: 0, editing: "nope")
    #expect(symbol.items.isEmpty && symbol.width == 550)
    #expect(services.hits.hit(bounce, sceneID: "nope", frame: 0, at: Point(x: 80, y: 100), tolerance: 4) == nil)
    #expect(services.hits.marquee(bounce, sceneID: "nope", frame: 0, rect: Rect(minX: 0, minY: 0, maxX: 550, maxY: 400)).isEmpty)
}

@Test func aSymbolHoldingItselfDrawsOnceAndTextInEachInstanceIsCounted() {
    let dot = FlareShape(points: [Point(x: 0, y: 0), Point(x: 10, y: 10)])
    let selfish = Layer(id: "in", name: "In", shapes: [dot], instances: [Instance(symbolID: "s")])
    let doc = Document(scenes: [FlareScene(id: "scene-1", name: "Scene 1", layers: [
        Layer(id: "host", name: "Host", instances: [Instance(symbolID: "s")]),
    ])], symbols: [Symbol(id: "s", name: "S", layers: [selfish])])
    #expect(services.stage.drawList(doc, sceneID: "scene-1", frame: 0, editing: nil).items.count == 1)
    #expect(services.stage.drawList(doc, sceneID: "scene-1", frame: 0, editing: "s").items.count == 1)

    let title = Layer(id: "t", name: "T", texts: [TextShape(string: "Hi", fontFamily: "Helvetica", fontSize: 12,
                                                            position: Point(x: 0, y: 0))])
    let twice = Document(scenes: [FlareScene(id: "scene-1", name: "Scene 1", layers: [
        Layer(id: "h", name: "H", instances: [Instance(symbolID: "t"), Instance(symbolID: "t")]),
    ])], symbols: [Symbol(id: "t", name: "T", layers: [title])])
    let list = services.stage.drawList(twice, sceneID: "scene-1", frame: 0, editing: nil)
    #expect(list.hiddenTextCount == 2 && list.items.allSatisfy(\.isText))
    #expect(services.hits.hit(twice, sceneID: "scene-1", frame: 0, at: Point(x: 0, y: 0), tolerance: 10) == nil)
}

@Test func oddHitInputsNeverReachPastTheBox() {
    let hits = services.hits
    // Ball's box at frame 0 is 50...110 by 70...130; just outside it only the locked Background is under the point.
    let outside = Point(x: 111, y: 100)
    #expect(hits.hit(bounce, sceneID: "scene-1", frame: 0, at: outside, tolerance: -5) == nil)
    #expect(hits.hit(bounce, sceneID: "scene-1", frame: 0, at: outside, tolerance: .infinity) == nil)
    #expect(hits.hit(bounce, sceneID: "scene-1", frame: 0, at: outside, tolerance: .nan) == nil)
    #expect(hits.hit(bounce, sceneID: "scene-1", frame: 0, at: outside, tolerance: 2) == ball)
    #expect(hits.hit(bounce, sceneID: "scene-1", frame: 0, at: Point(x: .nan, y: 100), tolerance: 0) == nil)
    #expect(hits.bounds(bounce, sceneID: "scene-1", frame: 0, of: [StageAddress(owner: .scene("scene-1"), layerID: "nope", item: .shape(0))]) == nil)
}

@Test func refusedSceneEditsLeaveNoUndoStep() throws {
    var engine = CommandEngine(document: bounce)
    for position in [Double.nan, .infinity] {
        #expect(throws: (any Error).self) { _ = try services.scenes.addGuide(.vertical, at: position, sceneID: "scene-1", in: &engine) }
    }
    #expect(throws: CommandError.sceneNotFound("nope")) { _ = try services.scenes.addGuide(.vertical, at: 1, sceneID: "nope", in: &engine) }
    #expect(throws: (any Error).self) { try services.scenes.moveGuide(at: 0, to: 1, sceneID: "scene-1", coalesceKey: nil, in: &engine) }
    #expect(throws: (any Error).self) { try services.scenes.setTiming("scene-1", fps: 0, durationFrames: 48, in: &engine) }
    for width in [Double.nan, .infinity, -5] {
        #expect(throws: (any Error).self) { try services.scenes.setCanvas("scene-1", width: width, height: 400, background: .white, in: &engine) }
    }
    #expect(throws: CommandError.sceneNotFound("nope")) { try services.scenes.reorderScene("nope", to: 0, in: &engine) }
    #expect(engine.document == bounce && !engine.canUndo)
}

@Test func newSceneIDsSkipEveryIDAndNameInUse() throws {
    var engine = CommandEngine(document: bounce)
    let second = try services.scenes.addScene(.web, in: &engine)
    #expect(second == "scene-2")
    #expect(try services.scenes.addScene(.web, in: &engine) == "scene-3")
    try services.scenes.removeScene(second, in: &engine)
    #expect(try services.scenes.addScene(.web, in: &engine) == "scene-4")
    try services.scenes.renameScene("scene-1", to: "Scene 5", in: &engine)
    #expect(try services.scenes.addScene(.web, in: &engine) == "scene-6")
    #expect(Set(engine.document.scenes.map(\.id)).count == engine.document.scenes.count)
    try services.scenes.reorderScene("scene-6", to: -3, in: &engine)
    try services.scenes.reorderScene("scene-1", to: 99, in: &engine)
    #expect(engine.document.scenes.map(\.id) == ["scene-6", "scene-3", "scene-4", "scene-1"])
}
