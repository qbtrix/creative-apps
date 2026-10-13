// TimelineFakesTests.swift: the LM-0b2 fake keyframes, easing and onion on `bounce` (docs/blueprints/flare.md, 7.1),
// and the workspace's onion and motion path state. The acceptance test: moving key 24 onto 36 throws and changes
// nothing; onion 3 and 3 gives 6 ghosts with opacity falling by the falloff; `motionPath` has 48 points.
import FlareCore
@testable import FlareModel
import Testing

private let services = FlareServices.fake()
private let scene = LayerOwner.scene("scene-1")
private let bounce = FlareFixtures.bounce

private func frames(_ e: CommandEngine, _ property: String) -> [Int] {
    e.document.layers(of: scene)?.first { $0.id == "ball" }?.tracks[property]?.map(\.frame) ?? []
}
private func undoEntries(_ engine: CommandEngine) throws -> Int {
    var copy = engine, n = 0
    while copy.canUndo { try copy.undo(); n += 1 }
    return n
}

@Test func movingKey24Onto36ThrowsAndChangesNothing() {
    var e = CommandEngine(document: bounce)
    #expect(throws: CommandError.frameOccupied(property: "x", frame: 36)) {
        try services.keyframes.moveKeys([KeyRef(layerID: "ball", property: "x", frame: 24)], by: 12, owner: scene, coalesceKey: nil, in: &e)
    }
    // A summary key moves every track; the coalesced drag path refuses as a whole too.
    #expect(throws: CommandError.self) {
        try services.keyframes.moveKeys([KeyRef(layerID: "ball", property: nil, frame: 24)], by: 12, owner: scene, coalesceKey: "drag", in: &e)
    }
    #expect(e.document == bounce && !e.canUndo)
}

@Test func keyMovesAreOneStepAndPassOverKeysThatMoveToo() throws {
    var e = CommandEngine(document: bounce)
    for f in 12..<17 {
        try services.keyframes.moveKeys([KeyRef(layerID: "ball", property: nil, frame: f)], by: 1, owner: scene, coalesceKey: "drag", in: &e)
    }
    #expect(["x", "y", "scaleX", "scaleY"].allSatisfy { frames(e, $0) == [0, 17, 24, 36, 47] })
    #expect(try undoEntries(e) == 1)
    let pair: Set = [KeyRef(layerID: "ball", property: "x", frame: 24), KeyRef(layerID: "ball", property: "x", frame: 36)]
    try services.keyframes.moveKeys(pair, by: 10, owner: scene, coalesceKey: nil, in: &e)
    #expect(frames(e, "x") == [0, 17, 34, 46, 47] && e.undoActionName == "Undo Move Keyframe")
    try e.undo(); try e.undo()
    #expect(e.document == bounce)
}

@Test func rowsKeysFramesAndLabelsEditInOneStepEach() throws {
    var e = CommandEngine(document: bounce)
    let ball = services.keyframes.rows(e.document, owner: scene).last
    #expect(ball?.keyFrames == [0, 12, 24, 36, 47] && ball?.segments == [0...12, 12...24, 24...36, 36...47] && ball?.easedSegments == [:])
    try services.easing.setEasing(.easeOut, at: KeyRef(layerID: "ball", property: nil, frame: 12), owner: scene, coalesceKey: nil, in: &e)
    #expect(services.keyframes.rows(e.document, owner: scene).last?.easedSegments == [12: .easeOut])
    try services.keyframes.removeKeys([KeyRef(layerID: "ball", property: nil, frame: 24)], owner: scene, in: &e)
    #expect(frames(e, "x") == [0, 12, 36, 47] && e.undoActionName == "Undo Delete Keyframe")
    try services.keyframes.insertFrames(2, at: 13, layerIDs: ["ball", "shadow"], owner: scene, in: &e)
    #expect(frames(e, "scaleY") == [0, 12, 38, 49] && e.undoActionName == "Undo Insert Frame")
    try services.keyframes.removeFrames(3, at: 10, layerIDs: ["ball"], owner: scene, in: &e)
    #expect(frames(e, "x") == [0, 35, 46] && e.undoActionName == "Undo Remove Frame")
    try services.keyframes.setLabel("land", at: 12, sceneID: "scene-1", in: &e)
    try services.keyframes.setLabel("hit", at: 12, sceneID: "scene-1", in: &e)
    #expect(services.keyframes.labels(e.document, sceneID: "scene-1") == ["hit": 12])
    try services.keyframes.setLabel(nil, at: 12, sceneID: "scene-1", in: &e)
    #expect(services.keyframes.labels(e.document, sceneID: "scene-1").isEmpty)
    #expect(try undoEntries(e) == 7)
    while e.canUndo { try e.undo() }
    #expect(e.document == bounce)
}

@Test func symbolOwnersAndUnavailableFakesRefuse() {
    var e = CommandEngine(document: bounce)
    #expect(throws: CommandError.invalidDocument(FakeProperties.symbolKeys)) {
        try services.keyframes.removeKeys([], owner: .symbol("star"), in: &e)
    }
    #expect(throws: NotBuilt(reason: "off")) { try FakeKeyframes(unavailable: "off").setLabel("a", at: 0, sceneID: "scene-1", in: &e) }
    #expect(FakeKeyframes(unavailable: "off").rows(bounce, owner: scene).isEmpty && FakeEasing(unavailable: "off").presets.isEmpty)
    #expect(FakeOnion(unavailable: "off").motionPath(bounce, owner: scene, layerID: "ball").isEmpty)
    #expect(e.document == bounce && !e.canUndo)
}

@Test func easingHasSixPresetsAndAnExactCurve() {
    #expect(services.easing.presets == EasingPreset.allCases && services.easing.presets.count == 6)
    let curve = services.easing.curve(.easeOut, count: 11)
    #expect(curve.count == 11 && curve.first == Point(x: 0, y: 0) && curve.last == Point(x: 1, y: 1))
    #expect(curve[5].y == Easing.easeOut.value(at: 0.5) && services.easing.curve(.linear, count: 0).isEmpty)
}

@Test func onion3And3GivesSixGhostsFallingByTheFalloff() {
    let on = OnionSettings(isOn: true, before: 3, after: 3, falloff: 0.5)
    let ghosts = services.onion.ghosts(bounce, sceneID: "scene-1", layerIDs: ["ball"], frame: 24, settings: on)
    #expect(ghosts.map(\.frame) == [21, 22, 23, 27, 26, 25])
    #expect(ghosts.map(\.opacity) == [0.125, 0.25, 0.5, 0.125, 0.25, 0.5])
    #expect(ghosts.allSatisfy { $0.items.map(\.address.layerID) == ["ball"] })
    // Clamped at the scene's edges, every layer when none are named, and nothing while off.
    let edge = services.onion.ghosts(bounce, sceneID: "scene-1", layerIDs: [], frame: 1, settings: on)
    #expect(edge.map(\.frame) == [0, 4, 3, 2] && edge.first?.items.count == 3)
    #expect(services.onion.ghosts(bounce, sceneID: "scene-1", layerIDs: [], frame: 24, settings: OnionSettings()).isEmpty)
}

@Test func motionPathHas48PointsAtTheSampledOrigin() {
    let path = services.onion.motionPath(bounce, owner: scene, layerID: "ball")
    #expect(path.count == 48 && path.first == Point(x: 80, y: 100) && path[12] == Point(x: 180, y: 320) && path.last == Point(x: 470, y: 100))
}

@Test func theWorkspaceKeepsOnionAndMotionPathState() {
    var w = FlareWorkspace(services: .fake())
    w.load(bounce)
    #expect(w.ghosts.isEmpty && w.motionPath.isEmpty)
    w.toggleOnion(); w.setOnionBefore(3); w.setOnionAfter(99); w.setOnionFalloff(.nan); w.setOnionFalloff(0.8)
    #expect(w.onion == OnionSettings(isOn: true, before: 3, after: 10, falloff: 0.8))
    w.currentFrame = 24; w.setOnionAfter(3)
    #expect(w.ghosts.count == 6 && w.ghosts.first?.items.count == 3)
    w.toggleMotionPath()
    #expect(w.motionPath.isEmpty)  // no layer inspected yet
    w.selectLayer("ball")
    #expect(w.motionPath.count == 48)
    // Preferences: they survive opening another file and never touch undo.
    w.load(FlareFixtures.empty)
    #expect(w.onion.isOn && w.showsMotionPath && !w.canUndo)
}
