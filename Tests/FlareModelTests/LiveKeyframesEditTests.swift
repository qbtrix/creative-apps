// LiveKeyframesEditTests.swift: KY-6's acceptance (docs/blueprints/flare/features/live-keys.md): Ball's 24 -> 28 is one
// "Undo Move Keyframe"; 24 onto 36 throws and changes nothing, undo state included; past frame 47 throws a key sentence; 50 coalesced
// one-frame steps are one entry; deleting 12 is one "Undo Delete Keyframe"; a symbol key moves and undoes exactly, and
// refuses past the symbol's last frame or before frame 0 without naming a scene.
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
    let past = CommandError.invalidDocument("A key can't move past the scene's last frame.")
    #expect(throws: past) {
        try live.moveKeys([KeyRef(layerID: "ball", property: "y", frame: 47)], by: 1, owner: scene, coalesceKey: nil, in: &engine)
    }
    #expect(FlareLayerError.command(past).message == "A key can't move past the scene's last frame.")
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

/// A summary-diamond drag moves every track's key, so each coalesced step runs several commands; the whole drag is
/// still one named entry that one undo restores.
@Test func coalescedSummaryDragIsOneEntry() throws {
    var engine = CommandEngine(document: FlareFixtures.bounce)
    for step in 0..<50 {
        let frame = step < 9 ? 12 + step : 21 - (step - 9) % 2  // out to 21, then back and forth between 20 and 21
        try live.moveKeys([KeyRef(layerID: "ball", property: nil, frame: frame)], by: frame == 21 ? -1 : 1, owner: scene,
                          coalesceKey: "drag-2", in: &engine)
    }
    for property in ["x", "y", "scaleX", "scaleY"] { #expect(frames(engine, scene, "ball", property) == [0, 20, 24, 36, 47]) }
    #expect(engine.undoActionName == "Undo Move Keyframe")
    try engine.undo()
    #expect(engine.document == FlareFixtures.bounce && !engine.canUndo)
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
    try live.moveKeys([KeyRef(layerID: "hand", property: nil, frame: 12)], by: 5, owner: wave, coalesceKey: nil, in: &engine)
    #expect(frames(engine, wave, "hand", "rotation") == [0, 17, 23])
    #expect(engine.undoActionName == "Undo Move Keyframe")
    #expect(throws: (any Error).self) {
        try live.moveKeys([KeyRef(layerID: "hand", property: "rotation", frame: 17)], by: 6, owner: wave, coalesceKey: nil, in: &engine)
    }
    #expect(frames(engine, wave, "hand", "rotation") == [0, 17, 23])
    try engine.undo()
    #expect(engine.document == FlareFixtures.character && !engine.canUndo)
    try live.removeKeys([KeyRef(layerID: "hand", property: "rotation", frame: 12)], owner: wave, in: &engine)
    #expect(frames(engine, wave, "hand", "rotation") == [0, 23])
    try engine.undo()
    #expect(engine.document == FlareFixtures.character)
}

/// "wave" is 24 frames (0-23): a key moved past its last frame would never play, so the move refuses.
@Test func symbolKeyPastTheSymbolEndThrowsAndChangesNothing() throws {
    var engine = CommandEngine(document: FlareFixtures.character)
    try live.moveKeys([KeyRef(layerID: "hand", property: "rotation", frame: 12)], by: 5, owner: wave, coalesceKey: nil, in: &engine)
    let before = engine.document
    let (canUndo, name) = (engine.canUndo, engine.undoActionName)
    #expect(throws: CommandError.invalidDocument("A key can't move past the symbol's last frame.")) {
        try live.moveKeys([KeyRef(layerID: "hand", property: "rotation", frame: 23)], by: 7, owner: wave, coalesceKey: nil, in: &engine)
    }
    #expect(engine.document == before && engine.canUndo == canUndo && engine.undoActionName == name)
    #expect(throws: CommandError.symbolNotFound("nope")) {
        try live.moveKeys([KeyRef(layerID: "hand", property: "rotation", frame: 23)], by: 1, owner: .symbol("nope"),
                          coalesceKey: nil, in: &engine)
    }
}

/// A key before frame 0 refuses with words that fit a symbol as well as a scene.
@Test func keyBeforeFrameZeroThrowsWithoutNamingTheScene() throws {
    for (document, owner, layerID, property) in [(FlareFixtures.character, wave, "hand", "rotation"),
                                                 (FlareFixtures.bounce, scene, "ball", "x")] {
        var engine = CommandEngine(document: document)
        do {
            try live.moveKeys([KeyRef(layerID: layerID, property: property, frame: 0)], by: -1, owner: owner,
                              coalesceKey: nil, in: &engine)
            Issue.record("a move before frame 0 should throw")
        } catch let error as CommandError {
            #expect(error == .invalidDocument("A key can't move before frame 0."))
            if case .invalidDocument(let message) = error { #expect(!message.contains("scene")) }
        }
        #expect(engine.document == document && !engine.canUndo)
    }
}
