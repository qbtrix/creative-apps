// LiveScenesTests.swift: SN-1's acceptance (docs/blueprints/flare/features/live-scenes.md): `newDocument` matches
// the fake, `addScene` and `removeScene` are one named undo step each that undoes exactly, and the last scene stays.
import FlareCore
import FlareModel
import Testing

private let live = LiveScenes()

@Test func newDocumentFromVerticalMatchesTheFake() throws {
    let document = live.newDocument(.vertical)
    #expect(document == FakeScenes().newDocument(.vertical))
    let scene = try #require(document.scenes.first)
    #expect(document.scenes.count == 1 && scene.id == "scene-1" && scene.name == "Scene 1")
    #expect(scene.width == 1080 && scene.height == 1920 && scene.fps == 30)
}

@Test func addSceneIsOneStepThatUndoesExactly() throws {
    var engine = CommandEngine(document: FlareFixtures.bounce)
    var fake = CommandEngine(document: FlareFixtures.bounce)
    let id = try live.addScene(.vertical, in: &engine)
    #expect(try FakeScenes().addScene(.vertical, in: &fake) == id)
    #expect(id == "scene-2" && engine.document == fake.document)
    #expect(engine.document.scenes.first { $0.id == id }?.name == "Scene 2")
    #expect(engine.undoActionName == "Undo Add Scene")
    try engine.undo()
    #expect(engine.document == FlareFixtures.bounce && !engine.canUndo)
}

@Test func removeSceneIsOneStepThatUndoesExactly() throws {
    var engine = CommandEngine(document: FlareFixtures.bounce)
    let id = try live.addScene(.square, in: &engine)
    let start = engine.document
    try live.removeScene(id, in: &engine)
    #expect(!engine.document.scenes.contains { $0.id == id })
    #expect(engine.undoActionName == "Undo Delete Scene")
    try engine.undo()
    #expect(engine.document == start && engine.undoActionName == "Undo Add Scene")
}

@Test func theLastSceneStays() {
    var engine = CommandEngine(document: FlareFixtures.empty)
    #expect(throws: CommandError.invalidDocument(FakeScenes.lastSceneMessage)) {
        try live.removeScene("scene-1", in: &engine)
    }
    #expect(engine.document == FlareFixtures.empty && !engine.canUndo)
}

@Test func anUnknownSceneThrows() {
    var engine = CommandEngine(document: FlareFixtures.bounce)
    #expect(throws: CommandError.sceneNotFound("missing")) { try live.removeScene("missing", in: &engine) }
    #expect(engine.document == FlareFixtures.bounce && !engine.canUndo)
}
