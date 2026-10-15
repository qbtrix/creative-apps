// LiveKeyframesEditTests.swift: KY-6's acceptance (docs/blueprints/flare/features/live-keys.md): Ball's 24 -> 28 is one
// "Undo Move Keyframe"; 24 onto 36 throws and changes nothing, undo state included; past frame 47 throws; 50 coalesced
// one-frame steps are one entry; deleting 12 is one "Undo Delete Keyframe"; a symbol key moves and undoes exactly.
import FlareCore
import FlareModel
import Testing

private let live = LiveKeyframes()
private let scene = LayerOwner.scene("scene-1")
private let wave = LayerOwner.symbol("wave")

private func frames(_ engine: CommandEngine, _ owner: LayerOwner, _ layerID: String, _ property: String) -> [Int] {
    engine.document.layers(of: owner)?.first { $0.id == layerID }?.tracks[property]?.map(\.frame).sorted() ?? []
}

@Test func moveBallSummaryKeyIsOneUndoStep() throws {
    var engine = CommandEngine(document: FlareFixtures.bounce)
    try live.moveKeys([KeyRef(layerID: "ball", property: nil, frame: 24)], by: 4, owner: scene, coalesceKey: nil, in: &engine)
    for property in ["x", "y", "scaleX", "scaleY"] { #expect(frames(engine, scene, "ball", property) == [0, 12, 28, 36, 47]) }
    #expect(engine.undoActionName == "Undo Move Keyframe")
    try engine.undo()
    #expect(engine.document == FlareFixtures.bounce && !engine.canUndo)
}

@Test func moveMatchesTheFakeOnAScene() throws {
    let keys: Set<KeyRef> = [KeyRef(layerID: "ball", property: nil, frame: 12), KeyRef(layerID: "ball", property: "x", frame: 24)]
    var engine = CommandEngine(document: FlareFixtures.bounce)
    var fake = CommandEngine(document: FlareFixtures.bounce)
    try live.moveKeys(keys, by: 5, owner: scene, coalesceKey: nil, in: &engine)
    try FakeKeyframes().moveKeys(keys, by: 5, owner: scene, coalesceKey: nil, in: &fake)
    #expect(engine.document == fake.document)
    #expect(frames(engine, scene, "ball", "x") == [0, 17, 29, 36, 47])
}

@Test func collisionThrowsAndChangesNothing() throws {
    var engine = CommandEngine(document: FlareFixtures.bounce)
    try live.moveKeys([KeyRef(layerID: "ball", property: "x", frame: 0)], by: 1, owner: scene, coalesceKey: nil, in: &engine)
    let before = engine.document
    let (canUndo, name) = (engine.canUndo, engine.undoActionName)
    #expect(throws: (any Error).self) {
        try live.moveKeys([KeyRef(layerID: "ball", property: nil, frame: 24)], by: 12, owner: scene, coalesceKey: nil, in: &engine)
    }
    #expect(engine.document == before && engine.canUndo == canUndo && engine.undoActionName == name)
}

@Test func pastTheSceneEndThrows() throws {
    var engine = CommandEngine(document: FlareFixtures.bounce)
    #expect(throws: CommandError.invalidFrame(48)) {
        try live.moveKeys([KeyRef(layerID: "ball", property: "y", frame: 47)], by: 1, owner: scene, coalesceKey: nil, in: &engine)
    }
    #expect(throws: CommandError.invalidFrame(Int.max)) {
        try live.moveKeys([KeyRef(layerID: "ball", property: "y", frame: 12)], by: Int.max, owner: scene, coalesceKey: nil, in: &engine)
    }
    #expect(engine.document == FlareFixtures.bounce && !engine.canUndo)
}

@Test func zeroDeltaAndNothingToMoveAreNoOps() throws {
    var engine = CommandEngine(document: FlareFixtures.bounce)
    try live.moveKeys([KeyRef(layerID: "ball", property: nil, frame: 24)], by: 0, owner: scene, coalesceKey: nil, in: &engine)
    try live.moveKeys([KeyRef(layerID: "ball", property: nil, frame: 5)], by: 3, owner: scene, coalesceKey: nil, in: &engine)
    try live.moveKeys([], by: 3, owner: scene, coalesceKey: nil, in: &engine)
    #expect(engine.document == FlareFixtures.bounce && !engine.canUndo)
}

@Test func coalescedDragIsOneEntry() throws {
    var engine = CommandEngine(document: FlareFixtures.bounce)
    for step in 0..<50 {
        let frame = step < 9 ? 12 + step : 21 - (step - 9) % 2  // out to 21, then back and forth between 20 and 21
        try live.moveKeys([KeyRef(layerID: "ball", property: "x", frame: frame)], by: frame == 21 ? -1 : 1, owner: scene,
                          coalesceKey: "drag-1", in: &engine)
    }
    #expect(frames(engine, scene, "ball", "x") == [0, 20, 24, 36, 47])
    #expect(engine.undoActionName == "Undo Move Keyframe")
    try engine.undo()
    #expect(engine.document == FlareFixtures.bounce && !engine.canUndo)
    var a = MoveKeyframe(owner: scene, layerID: "ball", property: "x", from: 12, to: 13)
    let merged = a.merge(MoveKeyframe(owner: scene, layerID: "ball", property: "x", from: 13, to: 14))
    #expect(merged && a.to == 14)
}

@Test func deleteSummaryKeyIsOneUndoStep() throws {
    var engine = CommandEngine(document: FlareFixtures.bounce)
    try live.removeKeys([KeyRef(layerID: "ball", property: nil, frame: 12)], owner: scene, in: &engine)
    for property in ["x", "y", "scaleX", "scaleY"] { #expect(frames(engine, scene, "ball", property) == [0, 24, 36, 47]) }
    #expect(engine.undoActionName == "Undo Delete Keyframe")
    try engine.undo()
    #expect(engine.document == FlareFixtures.bounce && !engine.canUndo)
}

@Test func symbolKeyMovesAndUndoesExactly() throws {
    var engine = CommandEngine(document: FlareFixtures.character)
    // A symbol has no scene ruler: only a collision or a frame before 0 refuses.
    try live.moveKeys([KeyRef(layerID: "hand", property: nil, frame: 23)], by: 7, owner: wave, coalesceKey: nil, in: &engine)
    #expect(frames(engine, wave, "hand", "rotation") == [0, 12, 30])
    #expect(engine.undoActionName == "Undo Move Keyframe")
    #expect(throws: (any Error).self) {
        try live.moveKeys([KeyRef(layerID: "hand", property: "rotation", frame: 12)], by: 18, owner: wave, coalesceKey: nil, in: &engine)
    }
    #expect(throws: (any Error).self) {
        try live.moveKeys([KeyRef(layerID: "hand", property: "rotation", frame: 0)], by: -1, owner: wave, coalesceKey: nil, in: &engine)
    }
    #expect(frames(engine, wave, "hand", "rotation") == [0, 12, 30])
    try engine.undo()
    #expect(engine.document == FlareFixtures.character && !engine.canUndo)
    try live.removeKeys([KeyRef(layerID: "hand", property: "rotation", frame: 12)], owner: wave, in: &engine)
    #expect(frames(engine, wave, "hand", "rotation") == [0, 23])
    try engine.undo()
    #expect(engine.document == FlareFixtures.character)
}
