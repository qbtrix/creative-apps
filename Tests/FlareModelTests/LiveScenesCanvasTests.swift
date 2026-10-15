// LiveScenesCanvasTests.swift: SN-3's acceptance (docs/blueprints/flare/features/live-scenes.md): `setCanvas` and
// `setTiming` are one named undo step each that matches the fake and undoes exactly; a bad size, fps or length
// throws and leaves the document and the undo stack as they were.
import FlareCore
import FlareModel
import Testing

private let live = LiveScenes()
private let red = FlareColor(r: 1, g: 0, b: 0)
private let nanRed = FlareColor(r: .nan, g: 0, b: 0)

@Test func setCanvasIsOneSetCanvasStepThatMatchesTheFake() throws {
    var engine = CommandEngine(document: FlareFixtures.bounce)
    var fake = CommandEngine(document: FlareFixtures.bounce)
    try live.setCanvas("scene-1", width: 1080, height: 1920, background: red, in: &engine)
    try FakeScenes().setCanvas("scene-1", width: 1080, height: 1920, background: red, in: &fake)
    let scene = try #require(engine.document.scenes.first)
    #expect(scene.width == 1080 && scene.height == 1920 && scene.background == red)
    #expect(engine.document == fake.document)
    #expect(engine.undoActionName == "Undo Set Canvas" && engine.undoActionName == fake.undoActionName)
    try engine.undo()
    #expect(engine.document == FlareFixtures.bounce && !engine.canUndo)
}

@Test(arguments: [(0.0, 1920.0, red), (1080.0, 0.0, red), (-5.0, 1920.0, red), (Double.infinity, 1920.0, red),
                   (1080.0, 1920.0, nanRed)])
func aBadCanvasSizeThrowsAndChangesNothing(width: Double, height: Double, background: FlareColor) {
    var engine = CommandEngine(document: FlareFixtures.bounce)
    #expect(throws: CommandError.self) {
        try live.setCanvas("scene-1", width: width, height: height, background: background, in: &engine)
    }
    #expect(engine.document == FlareFixtures.bounce && !engine.canUndo)
}

@Test func setCanvasOnAnUnknownSceneThrowsAndChangesNothing() {
    var engine = CommandEngine(document: FlareFixtures.bounce)
    #expect(throws: CommandError.sceneNotFound("missing")) {
        try live.setCanvas("missing", width: 1080, height: 1920, background: red, in: &engine)
    }
    #expect(engine.document == FlareFixtures.bounce && !engine.canUndo)
}

@Test func setTimingIsOneStepThatMatchesTheFake() throws {
    var engine = CommandEngine(document: FlareFixtures.bounce)
    var fake = CommandEngine(document: FlareFixtures.bounce)
    try live.setTiming("scene-1", fps: 30, durationFrames: 150, in: &engine)
    try FakeScenes().setTiming("scene-1", fps: 30, durationFrames: 150, in: &fake)
    let scene = try #require(engine.document.scenes.first)
    #expect(scene.fps == 30 && scene.durationFrames == 150)
    #expect(engine.document == fake.document)
    #expect(engine.undoActionName == "Undo Set Scene Timing" && engine.undoActionName == fake.undoActionName)
    try engine.undo()
    #expect(engine.document == FlareFixtures.bounce && !engine.canUndo)
}

@Test func fpsZeroThrowsAndChangesNothing() {
    var engine = CommandEngine(document: FlareFixtures.bounce)
    #expect(throws: CommandError.invalidFPS(0)) {
        try live.setTiming("scene-1", fps: 0, durationFrames: 150, in: &engine)
    }
    #expect(engine.document == FlareFixtures.bounce && !engine.canUndo)
}

@Test func aNegativeLengthThrowsAndChangesNothing() {
    var engine = CommandEngine(document: FlareFixtures.bounce)
    #expect(throws: CommandError.invalidDuration(-1)) {
        try live.setTiming("scene-1", fps: 30, durationFrames: -1, in: &engine)
    }
    #expect(engine.document == FlareFixtures.bounce && !engine.canUndo)
}

@Test func aFailedCanvasEditLeavesAnEarlierStepOnTop() throws {
    var engine = CommandEngine(document: FlareFixtures.bounce)
    try live.setTiming("scene-1", fps: 30, durationFrames: 150, in: &engine)
    let start = engine.document
    #expect(throws: CommandError.self) {
        try live.setCanvas("scene-1", width: 0, height: 1920, background: red, in: &engine)
    }
    #expect(engine.document == start && engine.undoActionName == "Undo Set Scene Timing")
    try engine.undo()
    #expect(engine.document == FlareFixtures.bounce && !engine.canUndo)
}

/// A refused canvas edit (a zero width or a NaN background) in the middle of a guide drag leaves the drag one
/// "Move Guide" entry, as the fake does.
private func dragAcrossARefusedCanvas(_ scenes: some SceneEditing, width: Double,
                                      background: FlareColor) throws -> CommandEngine {
    var engine = CommandEngine(document: FlareFixtures.bounce)
    _ = try scenes.addGuide(.horizontal, at: 300, sceneID: "scene-1", in: &engine)
    try scenes.moveGuide(at: 0, to: 310, sceneID: "scene-1", coalesceKey: "drag", in: &engine)
    #expect(throws: CommandError.self) {
        try scenes.setCanvas("scene-1", width: width, height: 1920, background: background, in: &engine)
    }
    try scenes.moveGuide(at: 0, to: 320, sceneID: "scene-1", coalesceKey: "drag", in: &engine)
    try engine.undo()
    return engine
}

@Test(arguments: [(0.0, red), (1080.0, nanRed)])
func refusedCanvasKeepsADragOneEntry(width: Double, background: FlareColor) throws {
    let engine = try dragAcrossARefusedCanvas(live, width: width, background: background)
    let fake = try dragAcrossARefusedCanvas(FakeScenes(), width: width, background: background)
    #expect(engine.document == fake.document)
    #expect(engine.document.scenes.first?.guides.first?.position == 300)
}
