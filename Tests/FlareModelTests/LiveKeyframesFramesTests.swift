// LiveKeyframesFramesTests.swift: KY-7's acceptance (docs/blueprints/flare/features/live-keys.md): on bounce after
// Ball's 24 -> 28, two frames inserted at 10 on every layer move 28 to 30 and grow the scene in the same entry; one frame
// removed moves it to 29; a label moves with a whole-scene edit; setLabel replaces and removes; each step is one entry;
// LiveKeyframes is a KeyframeEditing; frame edits inside symbol "wave" shift the hand's keys and undo exactly, and an
// insert past its last frame refuses; a blank label name refuses.
import FlareCore
import FlareModel
import Testing

private let live = LiveKeyframes()
private let scene = LayerOwner.scene("scene-1")
private let wave = LayerOwner.symbol("wave")
private let every = ["background", "shadow", "ball"]

private func ball(_ engine: CommandEngine) -> [Int] {
    live.rows(engine.document, owner: scene).first { $0.layerID == "ball" }?.keyFrames ?? []
}
private func length(_ engine: CommandEngine) -> Int? { engine.document.scenes.first?.durationFrames }
private func labels(_ engine: CommandEngine) -> [String: Int] { live.labels(engine.document, sceneID: "scene-1") }

/// Bounce with Ball's summary key at 24 moved to 28, and an empty undo stack.
private func moved() throws -> CommandEngine {
    var engine = CommandEngine(document: FlareFixtures.bounce)
    try live.moveKeys([KeyRef(layerID: "ball", property: nil, frame: 24)], by: 4, owner: scene, coalesceKey: nil, in: &engine)
    return CommandEngine(document: engine.document)
}

@Test func liveKeyframesIsAKeyframeEditing() {
    let _: any KeyframeEditing = LiveKeyframes()
}

@Test func insertOnEveryLayerShiftsKeysAndGrowsTheSceneInOneEntry() throws {
    var engine = try moved()
    let before = engine.document
    try live.insertFrames(2, at: 10, layerIDs: every, owner: scene, in: &engine)
    #expect(ball(engine) == [0, 14, 30, 38, 49])
    #expect(length(engine) == 50)
    #expect(engine.undoActionName == "Undo Insert Frame")
    try engine.undo()
    #expect(engine.document == before && !engine.canUndo)
    #expect(length(engine) == 48)
}

@Test func insertMatchesTheFake() throws {
    var engine = try moved()
    var fake = CommandEngine(document: engine.document)
    try live.insertFrames(3, at: 20, layerIDs: ["ball"], owner: scene, in: &engine)
    try FakeKeyframes().insertFrames(3, at: 20, layerIDs: ["ball"], owner: scene, in: &fake)
    #expect(engine.document == fake.document)
}

@Test func removeOneFrameMovesTheKeyBackInOneEntry() throws {
    var engine = try moved()
    let before = engine.document
    try live.removeFrames(1, at: 10, layerIDs: every, owner: scene, in: &engine)
    #expect(ball(engine) == [0, 11, 27, 35, 46])
    try engine.undo()
    try live.insertFrames(2, at: 10, layerIDs: every, owner: scene, in: &engine)
    try live.removeFrames(1, at: 10, layerIDs: every, owner: scene, in: &engine)
    #expect(ball(engine) == [0, 13, 29, 37, 48])
    #expect(engine.undoActionName == "Undo Remove Frame")
    try engine.undo()
    #expect(ball(engine) == [0, 14, 30, 38, 49])
    try engine.undo()
    #expect(engine.document == before)
}

@Test func removeDropsKeysInsideTheRun() throws {
    var engine = try moved()
    try live.removeFrames(4, at: 10, layerIDs: ["ball"], owner: scene, in: &engine)
    #expect(ball(engine) == [0, 24, 32, 43])
    try engine.undo()
    #expect(ball(engine) == [0, 12, 28, 36, 47] && !engine.canUndo)
}

@Test func aLabelMovesWithAWholeSceneEditOnly() throws {
    var engine = try moved()
    try live.setLabel("hit", at: 29, sceneID: "scene-1", in: &engine)
    try live.insertFrames(2, at: 10, layerIDs: every, owner: scene, in: &engine)
    #expect(labels(engine) == ["hit": 31])
    try live.removeFrames(1, at: 10, layerIDs: every, owner: scene, in: &engine)
    #expect(labels(engine) == ["hit": 30])
    // Some layers only: the ruler, and so the label, stays.
    try live.insertFrames(2, at: 10, layerIDs: ["ball"], owner: scene, in: &engine)
    #expect(labels(engine) == ["hit": 30])
    // A label inside a removed run goes, in the same entry.
    try live.removeFrames(5, at: 28, layerIDs: every, owner: scene, in: &engine)
    #expect(labels(engine).isEmpty)
    try engine.undo()
    #expect(labels(engine) == ["hit": 30])
}

@Test func setLabelReplacesAndNilRemovesEachInOneEntry() throws {
    var engine = try moved()
    try live.setLabel("land", at: 29, sceneID: "scene-1", in: &engine)
    try live.setLabel("hit", at: 29, sceneID: "scene-1", in: &engine)
    #expect(labels(engine) == ["hit": 29])
    #expect(engine.undoActionName == "Undo Set Frame Label")
    try live.setLabel(nil, at: 29, sceneID: "scene-1", in: &engine)
    #expect(labels(engine).isEmpty)
    #expect(engine.undoActionName == "Undo Remove Frame Label")
    try engine.undo()
    #expect(labels(engine) == ["hit": 29])
    try engine.undo()
    #expect(labels(engine) == ["land": 29])
    #expect(throws: CommandError.invalidDocument("A label needs a name.")) {
        try live.setLabel("", at: 3, sceneID: "scene-1", in: &engine)
    }
}

@Test func badFramesAndLayersThrowAndChangeNothing() throws {
    var engine = CommandEngine(document: FlareFixtures.bounce)
    #expect(throws: CommandError.invalidFrame(-1)) {
        try live.insertFrames(1, at: -1, layerIDs: ["ball"], owner: scene, in: &engine)
    }
    #expect(throws: CommandError.invalidFrame(-2)) {
        try live.removeFrames(1, at: -2, layerIDs: ["ball"], owner: scene, in: &engine)
    }
    #expect(throws: CommandError.layerNotFound("nope")) {
        try live.insertFrames(1, at: 0, layerIDs: ["ball", "nope"], owner: scene, in: &engine)
    }
    #expect(throws: CommandError.layerNotFound("nope")) {
        try live.removeFrames(1, at: 0, layerIDs: ["nope"], owner: scene, in: &engine)
    }
    #expect(engine.document == FlareFixtures.bounce && !engine.canUndo)
}

@Test func insertInsideASymbolShiftsTheHandAndUndoesExactly() throws {
    var engine = CommandEngine(document: FlareFixtures.character)
    try live.removeFrames(3, at: 5, layerIDs: ["hand"], owner: wave, in: &engine)
    #expect(live.rows(engine.document, owner: wave).first?.keyFrames == [0, 9, 20])
    #expect(engine.undoActionName == "Undo Remove Frame")
    try live.insertFrames(3, at: 5, layerIDs: ["hand"], owner: wave, in: &engine)
    #expect(live.rows(engine.document, owner: wave).first?.keyFrames == [0, 12, 23])
    #expect(engine.undoActionName == "Undo Insert Frame")
    #expect(engine.document.symbols == FlareFixtures.character.symbols)
    try engine.undo()
    try engine.undo()
    #expect(engine.document == FlareFixtures.character && !engine.canUndo)
}

/// "wave" is 24 frames (0-23) and FlareCore has no command that grows a symbol, so an insert that would push the
/// hand's last key past 23 refuses with an insert sentence (not the key-move one) and changes nothing.
@Test func insertPastASymbolEndThrowsAndChangesNothing() throws {
    var engine = CommandEngine(document: FlareFixtures.character)
    let sentence = "A symbol can't get longer yet, so frames can't be inserted before its last key."
    #expect(throws: CommandError.invalidDocument(sentence)) {
        try live.insertFrames(3, at: 5, layerIDs: ["hand"], owner: wave, in: &engine)
    }
    #expect(FlareLayerError.command(.invalidDocument(sentence)).message == sentence)
    #expect(throws: CommandError.symbolNotFound("nope")) {
        try live.insertFrames(1, at: 0, layerIDs: [], owner: .symbol("nope"), in: &engine)
    }
    #expect(engine.document == FlareFixtures.character && !engine.canUndo)
}

@Test func aBlankLabelThrowsAndChangesNothing() throws {
    var engine = CommandEngine(document: FlareFixtures.bounce)
    var fake = CommandEngine(document: FlareFixtures.bounce)
    #expect(throws: CommandError.invalidDocument("A label needs a name.")) {
        try live.setLabel("  ", at: 3, sceneID: "scene-1", in: &engine)
    }
    #expect(throws: CommandError.invalidDocument("A label needs a name.")) {
        try FakeKeyframes().setLabel("  ", at: 3, sceneID: "scene-1", in: &fake)
    }
    #expect(engine.document == FlareFixtures.bounce && !engine.canUndo)
    #expect(fake.document == FlareFixtures.bounce && !fake.canUndo)
}
