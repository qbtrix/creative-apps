// LivePropertiesSetTests.swift: KY-2, the live inspector write (docs/blueprints/flare/features/live-keys.md). setValue
// follows section 2's rule, refuses a non-finite value without changing anything, makes a scrub one undo entry, and works
// on a symbol's own layer as well as a scene layer.
import FlareCore
@testable import FlareModel
import Testing

private let scene = LayerOwner.scene("scene-1")
private let wave = LayerOwner.symbol("wave")

private func layer(_ id: String, of owner: LayerOwner = scene, in engine: CommandEngine) -> Layer? {
    engine.document.layers(of: owner)?.first { $0.id == id }
}

private func row(_ name: String, _ id: String, at frame: Int, in engine: CommandEngine) -> AnimatedProperty? {
    LiveProperties().properties(engine.document, owner: scene, layerIDs: [id], frame: frame).first { $0.name == name }
}

@Test func twoKeysInterpolateBetweenThem() throws {
    var engine = CommandEngine(document: FlareFixtures.bounce)
    let live = LiveProperties()
    try live.setValue(0, of: "x", owner: scene, layerIDs: ["shadow"], frame: 0, autoKey: true, coalesceKey: nil, in: &engine)
    try live.setValue(120, of: "x", owner: scene, layerIDs: ["shadow"], frame: 24, autoKey: true, coalesceKey: nil, in: &engine)
    #expect(layer("shadow", in: engine)?.tracks["x"]?.map(\.frame) == [0, 24])
    #expect(layer("shadow", in: engine)?.placement(at: 12).transform.x == 60)
}

@Test func aNotAnimatedEditSetsItsOneKey() throws {
    var engine = CommandEngine(document: FlareFixtures.bounce)
    try LiveProperties().setValue(200, of: "x", owner: scene, layerIDs: ["shadow"], frame: 30, autoKey: false,
                                  coalesceKey: nil, in: &engine)
    #expect(layer("shadow", in: engine)?.tracks["x"] == [Keyframe(frame: 0, value: 200)])
    #expect(row("x", "shadow", at: 30, in: engine)?.keyState == .notAnimated)
    #expect(row("x", "shadow", at: 0, in: engine)?.value == 200)
    #expect(row("x", "shadow", at: 30, in: engine)?.value == 200)
    #expect(engine.undoActionName == "Undo Set Keyframe")
}

@Test func autoKeyAddsASecondKeyAndAnimates() throws {
    var engine = CommandEngine(document: FlareFixtures.bounce)
    let live = LiveProperties()
    try live.setValue(200, of: "x", owner: scene, layerIDs: ["shadow"], frame: 30, autoKey: false, coalesceKey: nil, in: &engine)
    try live.setValue(300, of: "x", owner: scene, layerIDs: ["shadow"], frame: 30, autoKey: true, coalesceKey: nil, in: &engine)
    #expect(layer("shadow", in: engine)?.tracks["x"]?.map(\.frame) == [0, 30])
    #expect(row("x", "shadow", at: 20, in: engine)?.keyState == .animated)
}

@Test func anAnimatedEditKeysThePlayheadAndKeepsTheEasing() throws {
    var doc = FlareFixtures.character
    var engine = CommandEngine(document: doc)
    try engine.perform(SetKeyframeEasing(owner: wave, layerID: "hand", property: "rotation", frame: 12, easing: .easeOut))
    doc = engine.document
    try LiveProperties().setValue(40, of: "rotation", owner: wave, layerIDs: ["hand"], frame: 12, autoKey: false,
                                  coalesceKey: nil, in: &engine)
    #expect(layer("hand", of: wave, in: engine)?.tracks["rotation"]?.first { $0.frame == 12 }
        == Keyframe(frame: 12, value: 40, easing: .easeOut))
    try engine.undo()
    #expect(engine.document == doc)
}

@Test func aSymbolLayersKeySetsAndUndoesExactly() throws {
    let doc = FlareFixtures.character
    var engine = CommandEngine(document: doc)
    try LiveProperties().setValue(10, of: "rotation", owner: wave, layerIDs: ["hand"], frame: 6, autoKey: true,
                                  coalesceKey: nil, in: &engine)
    #expect(layer("hand", of: wave, in: engine)?.tracks["rotation"]?.map(\.frame) == [0, 6, 12, 23])
    #expect(engine.document.scenes == doc.scenes)
    try engine.undo()
    #expect(engine.document == doc)
    #expect(!engine.canUndo)
}

@Test func aScrubIsOneEntry() throws {
    let doc = FlareFixtures.bounce
    var engine = CommandEngine(document: doc)
    let before = engine.canUndo
    for step in 1...120 {
        try LiveProperties().setValue(Double(step) * 3, of: "rotation", owner: scene, layerIDs: ["ball"], frame: 12,
                                      autoKey: false, coalesceKey: "scrub-rotation", in: &engine)
    }
    #expect(layer("ball", in: engine)?.tracks["rotation"] == [Keyframe(frame: 0, value: 360)])
    #expect(engine.undoActionName == "Undo Set Keyframe")
    try engine.undo()
    #expect(engine.document == doc)
    #expect(engine.canUndo == before)
}

@Test func severalLayersWithoutAKeyAreOneGroup() throws {
    let doc = FlareFixtures.bounce
    var engine = CommandEngine(document: doc)
    try LiveProperties().setValue(0.5, of: "opacity", owner: scene, layerIDs: ["ball", "shadow"], frame: 0, autoKey: false,
                                  coalesceKey: nil, in: &engine)
    #expect(engine.undoActionName == "Undo Set Keyframe")
    try engine.undo()
    #expect(engine.document == doc)
    #expect(!engine.canUndo)
}

@Test func consecutiveSetKeyframesOnOneKeyMerge() {
    func set(_ value: Double) -> SetKeyframe {
        SetKeyframe(owner: scene, layerID: "ball", property: "x", keyframe: Keyframe(frame: 24, value: value))
    }
    // `#expect` can't call a mutating member, so each merge result is taken first.
    var a = set(280)
    let merged = a.merge(set(300))
    #expect(merged)
    #expect(a.keyframe.value == 300)
    var other = set(280)
    let elsewhere = other.merge(SetKeyframe(owner: scene, layerID: "ball", property: "x", keyframe: Keyframe(frame: 12, value: 1)))
    #expect(!elsewhere)
}

@Test(arguments: [Double.nan, .infinity, -.infinity])
func aNonFiniteValueThrowsAndChangesNothing(value: Double) {
    let doc = FlareFixtures.bounce
    var engine = CommandEngine(document: doc)
    #expect(throws: CommandError.invalidDocument("X needs a number.")) {
        try LiveProperties().setValue(value, of: "x", owner: scene, layerIDs: ["ball"], frame: 12, autoKey: true,
                                      coalesceKey: nil, in: &engine)
    }
    #expect(engine.document == doc)
    #expect(!engine.canUndo)
}

@Test func aMissingOrLockedLayerThrows() {
    var engine = CommandEngine(document: FlareFixtures.bounce)
    let live = LiveProperties()
    #expect(throws: CommandError.layerNotFound("nope")) {
        try live.setValue(1, of: "x", owner: scene, layerIDs: ["ball", "nope"], frame: 0, autoKey: false, coalesceKey: nil, in: &engine)
    }
    #expect(throws: CommandError.layerLocked("background")) {
        try live.setValue(1, of: "x", owner: scene, layerIDs: ["background"], frame: 0, autoKey: false, coalesceKey: nil, in: &engine)
    }
    #expect(engine.document == FlareFixtures.bounce)
}

@Test func aCoalescedWriteOnSeveralLayersThatThrowsChangesNothing() {
    var engine = CommandEngine(document: FlareFixtures.bounce)
    #expect(throws: CommandError.invalidFrame(-1)) {
        try LiveProperties().setValue(5, of: "x", owner: scene, layerIDs: ["shadow", "ball"], frame: -1, autoKey: false,
                                      coalesceKey: "s", in: &engine)
    }
    #expect(engine.document == FlareFixtures.bounce)
    #expect(!engine.canUndo)
}
