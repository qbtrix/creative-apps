// LivePropertiesKeysTests.swift: KY-3, the live stopwatch and keyframe button (docs/blueprints/flare/features/live-keys.md).
// The stopwatch turns a still row into two keys and back into one key holding the value at the playhead; the keyframe
// button adds and removes one key per undo entry; both work on a symbol's own layer.
import FlareCore
@testable import FlareModel
import Testing

private let scene = LayerOwner.scene("scene-1")
private let wave = LayerOwner.symbol("wave")

private func track(_ property: String, _ id: String, of owner: LayerOwner = scene, in engine: CommandEngine) -> [Keyframe]? {
    engine.document.layers(of: owner)?.first { $0.id == id }?.tracks[property]
}

@Test func theStopwatchAnimatesAStillRowWithTwoKeys() throws {
    let doc = FlareFixtures.bounce
    var engine = CommandEngine(document: doc)
    try LiveProperties().toggleAnimated("x", owner: scene, layerID: "shadow", frame: 0, lastFrame: 47, in: &engine)
    #expect(track("x", "shadow", in: engine) == [Keyframe(frame: 0, value: 0), Keyframe(frame: 47, value: 0)])
    #expect(engine.undoActionName == "Undo Animate X")
    try engine.undo()
    #expect(engine.document == doc)
    #expect(!engine.canUndo)
}

@Test func theStopwatchAtTheLastFrameKeysFrameZero() throws {
    var engine = CommandEngine(document: FlareFixtures.bounce)
    try LiveProperties().toggleAnimated("y", owner: scene, layerID: "shadow", frame: 47, lastFrame: 47, in: &engine)
    #expect(track("y", "shadow", in: engine)?.map(\.frame) == [0, 47])
}

@Test func theStopwatchOffKeepsTheValueAtThePlayhead() throws {
    var engine = CommandEngine(document: FlareFixtures.bounce)
    let live = LiveProperties()
    try live.toggleAnimated("x", owner: scene, layerID: "shadow", frame: 0, lastFrame: 47, in: &engine)
    try live.setValue(120, of: "x", owner: scene, layerIDs: ["shadow"], frame: 47, autoKey: false, coalesceKey: nil, in: &engine)
    try live.toggleAnimated("x", owner: scene, layerID: "shadow", frame: 20, lastFrame: 47, in: &engine)
    let expected = 120.0 * 20 / 47
    #expect(track("x", "shadow", in: engine)?.count == 1)
    #expect(track("x", "shadow", in: engine)?.first?.frame == 0)
    #expect(abs((track("x", "shadow", in: engine)?.first?.value ?? 0) - expected) < 1e-9)
    #expect(engine.undoActionName == "Undo Stop Animating X")
    let row = live.properties(engine.document, owner: scene, layerIDs: ["shadow"], frame: 20).first { $0.name == "x" }
    #expect(row?.keyState == .notAnimated)
}

@Test func theKeyframeButtonAddsThenRemovesOneKey() throws {
    let doc = FlareFixtures.bounce
    var engine = CommandEngine(document: doc)
    let live = LiveProperties()
    let sampled = engine.document.layers(of: scene)?.first { $0.id == "ball" }?.sample(at: 20)["x"]
    try live.toggleKey("x", owner: scene, layerID: "ball", frame: 20, in: &engine)
    #expect(track("x", "ball", in: engine)?.map(\.frame) == [0, 12, 20, 24, 36, 47])
    #expect(track("x", "ball", in: engine)?.first { $0.frame == 20 }?.value == sampled)
    let added = engine.document
    try live.toggleKey("x", owner: scene, layerID: "ball", frame: 20, in: &engine)
    #expect(engine.document == doc)
    try engine.undo()
    #expect(engine.document == added)
    try engine.undo()
    #expect(engine.document == doc)
    #expect(!engine.canUndo)
}

@Test func theStopwatchOnASymbolLayerUndoesExactly() throws {
    let doc = FlareFixtures.character
    var engine = CommandEngine(document: doc)
    try LiveProperties().toggleAnimated("rotation", owner: wave, layerID: "hand", frame: 12, lastFrame: 23, in: &engine)
    #expect(track("rotation", "hand", of: wave, in: engine) == [Keyframe(frame: 0, value: 25)])
    #expect(engine.undoActionName == "Undo Stop Animating Rotation")
    #expect(engine.document.scenes == doc.scenes)
    try engine.undo()
    #expect(engine.document == doc)
    #expect(!engine.canUndo)
}

@Test func aMissingOrLockedLayerThrowsAndChangesNothing() {
    var engine = CommandEngine(document: FlareFixtures.bounce)
    let live = LiveProperties()
    #expect(throws: CommandError.layerNotFound("nope")) {
        try live.toggleAnimated("x", owner: scene, layerID: "nope", frame: 0, lastFrame: 47, in: &engine)
    }
    #expect(throws: CommandError.layerLocked("background")) {
        try live.toggleKey("x", owner: scene, layerID: "background", frame: 0, in: &engine)
    }
    #expect(engine.document == FlareFixtures.bounce)
    #expect(!engine.canUndo)
}
