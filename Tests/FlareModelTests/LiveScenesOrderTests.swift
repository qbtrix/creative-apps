// LiveScenesOrderTests.swift: SN-2's acceptance (docs/blueprints/flare/features/live-scenes.md): `renameScene`
// and `reorderScene` are one named undo step each that undoes exactly, the index clamps like the fake's, an
// unknown id throws and changes nothing, and every write leaves the document the fake leaves.
import FlareCore
import FlareModel
import Testing

private let live = LiveScenes()

/// `bounce` plus one added scene, on a live engine and an identical fake one.
private func twoScenes() throws -> (live: CommandEngine, fake: CommandEngine, id: String) {
    var engine = CommandEngine(document: FlareFixtures.bounce)
    let id = try live.addScene(.vertical, in: &engine)
    return (engine, engine, id)
}

@Test func renameIsOneStepThatUndoesExactly() throws {
    var (engine, fake, id) = try twoScenes()
    let start = engine.document
    try live.renameScene(id, to: "Outro", in: &engine)
    try FakeScenes().renameScene(id, to: "Outro", in: &fake)
    #expect(engine.document == fake.document)
    #expect(engine.document.scenes.first { $0.id == id }?.name == "Outro")
    #expect(engine.undoActionName == "Undo Rename Scene" && engine.undoActionName == fake.undoActionName)
    try engine.undo()
    #expect(engine.document == start && engine.undoActionName == "Undo Add Scene")
}

@Test func reorderToTheFrontIsOneMoveSceneStep() throws {
    var (engine, fake, id) = try twoScenes()
    try live.renameScene(id, to: "Outro", in: &engine)
    try FakeScenes().renameScene(id, to: "Outro", in: &fake)
    let start = engine.document
    try live.reorderScene(id, to: 0, in: &engine)
    try FakeScenes().reorderScene(id, to: 0, in: &fake)
    #expect(engine.document == fake.document)
    #expect(engine.document.scenes.first?.name == "Outro")
    #expect(engine.undoActionName == "Undo Move Scene" && engine.undoActionName == fake.undoActionName)
    try engine.undo()
    #expect(engine.document == start && engine.undoActionName == "Undo Rename Scene")
}

@Test(arguments: [(-3, 0), (99, 1)])
func outOfRangeIndexClampsLikeTheFake(index: Int, landsAt: Int) throws {
    var (engine, fake, id) = try twoScenes()
    // Start the added scene at the far end from where it should land, so each clamp moves it.
    let other = landsAt == 0 ? 1 : 0
    try live.reorderScene(id, to: other, in: &engine)
    try FakeScenes().reorderScene(id, to: other, in: &fake)
    let start = engine.document
    try live.reorderScene(id, to: index, in: &engine)
    try FakeScenes().reorderScene(id, to: index, in: &fake)
    #expect(engine.document == fake.document)
    #expect(engine.document.scenes.firstIndex { $0.id == id } == landsAt)
    #expect(engine.undoActionName == "Undo Move Scene")
    try engine.undo()
    #expect(engine.document == start)
}

@Test func anUnknownIdThrowsAndChangesNothing() throws {
    var (engine, _, _) = try twoScenes()
    let start = engine.document
    #expect(throws: CommandError.sceneNotFound("missing")) { try live.reorderScene("missing", to: 0, in: &engine) }
    #expect(throws: CommandError.sceneNotFound("missing")) {
        try live.renameScene("missing", to: "Outro", in: &engine)
    }
    #expect(engine.document == start && engine.undoActionName == "Undo Add Scene")
}
