// PropertyFakesTests.swift: the LM-0b1 fake properties on `bounce` (docs/blueprints/flare.md, 7.1): section 2's
// not-animated rule, the stopwatch, Mixed across a multi-selection, auto-key on the workspace, and QB-F3's budget that a
// scrub of 120 values is exactly one undo entry.
import FlareCore
@testable import FlareModel
import Testing

private let properties = FlareServices.fake().properties
private let scene = LayerOwner.scene("scene-1")

private func keys(_ e: CommandEngine, _ layer: String, _ property: String) -> [Keyframe] {
    e.document.layers(of: scene)?.first { $0.id == layer }?.tracks[property] ?? []
}
private func row(_ e: CommandEngine, _ layers: [String], _ name: String, at frame: Int) -> AnimatedProperty? {
    properties.properties(e.document, owner: scene, layerIDs: layers, frame: frame).first { $0.name == name }
}
/// How many undo entries the engine holds, by undoing them all on a copy.
private func undoEntries(_ engine: CommandEngine) throws -> Int {
    var copy = engine, n = 0
    while copy.canUndo { try copy.undo(); n += 1 }
    return n
}

@Test func ballXIsAnimatedAndShadowXIsNot() {
    let e = CommandEngine(document: FlareFixtures.bounce)
    #expect(row(e, ["ball"], "x", at: 6)?.keyState == .animated)
    #expect(row(e, ["ball"], "x", at: 12)?.keyState == .keyedHere)
    #expect(row(e, ["shadow"], "x", at: 30)?.keyState == .notAnimated && row(e, ["shadow"], "x", at: 30)?.value == 0)
    #expect(properties.properties(e.document, owner: scene, layerIDs: ["ball"], frame: 0).map(\.title)
        == ["X", "Y", "Scale X", "Scale Y", "Rotation", "Opacity"])
}

@Test func anEditWithAutoKeyOffSetsTheOneKeyAndStaysNotAnimated() throws {
    var e = CommandEngine(document: FlareFixtures.bounce)
    try properties.setValue(50, of: "x", owner: scene, layerIDs: ["shadow"], frame: 30, autoKey: false, coalesceKey: nil, in: &e)
    try properties.setValue(60, of: "x", owner: scene, layerIDs: ["shadow"], frame: 30, autoKey: false, coalesceKey: nil, in: &e)
    #expect(keys(e, "shadow", "x").map(\.frame) == [0] && keys(e, "shadow", "x").first?.value == 60)
    #expect(row(e, ["shadow"], "x", at: 30)?.keyState == .notAnimated && row(e, ["shadow"], "x", at: 0)?.value == 60)
}

@Test func autoKeyOnKeysThePlayheadAndAnEditAtASecondFrameAnimates() throws {
    var e = CommandEngine(document: FlareFixtures.bounce)
    try properties.setValue(50, of: "x", owner: scene, layerIDs: ["shadow"], frame: 0, autoKey: false, coalesceKey: nil, in: &e)
    try properties.setValue(90, of: "x", owner: scene, layerIDs: ["shadow"], frame: 24, autoKey: true, coalesceKey: nil, in: &e)
    #expect(keys(e, "shadow", "x").map(\.frame) == [0, 24] && row(e, ["shadow"], "x", at: 24)?.keyState == .keyedHere)
    // Animated: an edit keys the playhead even with auto-key off.
    try properties.setValue(200, of: "x", owner: scene, layerIDs: ["ball"], frame: 6, autoKey: false, coalesceKey: nil, in: &e)
    #expect(keys(e, "ball", "x").map(\.frame) == [0, 6, 12, 24, 36, 47])
}

@Test func theStopwatchOnShadowKeysZeroAndTheLastFrame() throws {
    var e = CommandEngine(document: FlareFixtures.bounce)
    try properties.toggleAnimated("x", owner: scene, layerID: "shadow", frame: 0, lastFrame: 47, in: &e)
    #expect(keys(e, "shadow", "x").map(\.frame) == [0, 47] && row(e, ["shadow"], "x", at: 10)?.keyState == .animated)
    #expect(try undoEntries(e) == 1 && e.undoActionName == "Undo Animate X")
    try properties.toggleAnimated("x", owner: scene, layerID: "ball", frame: 12, lastFrame: 47, in: &e)
    #expect(keys(e, "ball", "x").map { [$0.frame, Int($0.value)] } == [[0, 180]] && e.undoActionName == "Undo Stop Animating X")
}

@Test func oneHundredTwentyScrubValuesLeaveExactlyOneUndoEntry() throws {
    var e = CommandEngine(document: FlareFixtures.bounce)
    for i in 0..<120 {
        try properties.setValue(Double(i), of: "x", owner: scene, layerIDs: ["shadow"], frame: 30, autoKey: false,
                                coalesceKey: "scrub", in: &e)
    }
    #expect(try undoEntries(e) == 1 && keys(e, "shadow", "x").map(\.value) == [119] && e.undoActionName == "Undo Set Keyframe")
    try e.undo()
    #expect(e.document == FlareFixtures.bounce)
}

@Test func ballAndShadowTogetherReadMixed() throws {
    var e = CommandEngine(document: FlareFixtures.bounce)
    #expect(row(e, ["ball", "shadow"], "x", at: 0)?.value == nil && row(e, ["ball", "shadow"], "rotation", at: 0)?.value == 0)
    try properties.setValue(10, of: "x", owner: scene, layerIDs: ["ball", "shadow"], frame: 0, autoKey: false, coalesceKey: nil, in: &e)
    #expect(try undoEntries(e) == 1 && row(e, ["ball", "shadow"], "x", at: 0)?.value == nil)
}

@Test func lockedLayersSymbolsAndNotBuiltChangeNothing() {
    var e = CommandEngine(document: FlareFixtures.bounce)
    #expect(throws: CommandError.layerLocked("background")) {
        try properties.setValue(1, of: "x", owner: scene, layerIDs: ["background"], frame: 0, autoKey: false, coalesceKey: nil, in: &e)
    }
    #expect(throws: (any Error).self) {
        try properties.toggleKey("x", owner: .symbol("star"), layerID: "ball", frame: 0, in: &e)
    }
    #expect(throws: NotBuilt(reason: "off")) {
        try FakeProperties(unavailable: "off").setValue(1, of: "x", owner: scene, layerIDs: ["ball"], frame: 0,
                                                        autoKey: false, coalesceKey: nil, in: &e)
    }
    #expect(e.document == FlareFixtures.bounce && !e.canUndo)
}

@Test func theKeyButtonAddsThenRemovesAKey() throws {
    var e = CommandEngine(document: FlareFixtures.bounce)
    try properties.toggleKey("x", owner: scene, layerID: "ball", frame: 6, in: &e)
    #expect(keys(e, "ball", "x").count == 6 && row(e, ["ball"], "x", at: 6)?.keyState == .keyedHere)
    try properties.toggleKey("x", owner: scene, layerID: "ball", frame: 6, in: &e)
    #expect(e.document == FlareFixtures.bounce)
}

@Test func fillAndStrokeAreOneNamedStepEach() throws {
    var e = CommandEngine(document: FlareFixtures.bounce)
    let ball = StageAddress(owner: scene, layerID: "ball", item: .shape(0))
    try properties.setFill(.solid(FlareColor(r: 0, g: 0, b: 1)), of: [ball], in: &e)
    #expect(e.undoActionName == "Undo Set Fill")
    try properties.setStroke(Stroke(), of: [ball], in: &e)
    #expect(e.undoActionName == "Undo Set Stroke" && e.document.layers(of: scene)?.last?.shapes.first?.stroke == Stroke())
    try e.undo(); try e.undo()
    #expect(e.document == FlareFixtures.bounce)
}

@Test func theWorkspaceScrubsWithAutoKeyAndShowsMixed() {
    var w = FlareWorkspace(services: .fake())
    w.load(FlareFixtures.bounce)
    w.selectLayer("shadow")
    #expect(!w.autoKey)
    w.toggleAutoKey()
    w.currentFrame = 24
    for i in 0..<120 { w.setProperty("x", to: Double(i), dragStart: 0) }
    #expect(w.autoKey && w.undoActionName == "Undo Set Keyframe" && w.animatedProperties.first?.value == 119)
    w.undo()
    #expect(w.document == FlareFixtures.bounce && !w.canUndo)
    w.toggleAnimated("x")
    #expect(w.animatedProperties.first?.keyState == .keyedHere && w.undoActionName == "Undo Animate X")
    w.selection = [StageAddress(owner: scene, layerID: "ball", item: .shape(0)), StageAddress(owner: scene, layerID: "shadow", item: .shape(0))]
    #expect(w.animatedProperties.first?.value == nil)
    w.toggleKey("x")
    #expect(w.layerError?.message == "Select one layer to key it.")
}
