// LiveScenesJourneyTests.swift: SN-5's acceptance (docs/blueprints/flare/features/live-scenes.md). Journey steps
// 1-4 (J2, J16, J14) on `LiveScenes`, steps 2-4 through a `FlareWorkspace` whose scenes service is live: every
// write is one named undo entry that undoes exactly, the last scene is refused, refusals read as plain sentences
// (QB-F2), and every valid write on `bounce` leaves the same document and undo name as `FakeScenes`.
import FlareCore
@testable import FlareModel
import Testing

private let red = FlareColor(r: 1, g: 0, b: 0)

/// A workspace on the fakes with `LiveScenes` as its scenes service, `document` open.
private func liveWorkspace(_ document: Document) -> FlareWorkspace {
    var services = FlareServices.fake()
    services.scenes = LiveScenes()
    var workspace = FlareWorkspace(services: services)
    workspace.load(document)
    return workspace
}

/// Runs `edit` as one step named `name`: one undo puts the document back, one redo brings the edit back.
private func expectOneStep(_ w: inout FlareWorkspace, _ name: String, _ edit: (inout FlareWorkspace) -> Void,
                           sourceLocation: SourceLocation = #_sourceLocation) {
    let before = w.document, beforeName = w.undoActionName
    edit(&w)
    let after = w.document
    #expect(w.layerError == nil && after != before, sourceLocation: sourceLocation)
    #expect(w.undoActionName == "Undo \(name)", sourceLocation: sourceLocation)
    w.undo()
    #expect(w.document == before && w.undoActionName == beforeName, sourceLocation: sourceLocation)
    w.redo()
    #expect(w.document == after, sourceLocation: sourceLocation)
}

/// A sentence a person reads: starts with a capital, ends with a full stop, and has no code in it.
private func isPlainSentence(_ text: String?) -> Bool {
    guard let text, let first = text.first, first.isUppercase, text.hasSuffix(".") else { return false }
    let code = ["(", ")", "_", "Error", "invalid", "FPS", "Command", "Scene("]
    let camelCase = text.split(separator: " ").contains { word in
        zip(word, word.dropFirst()).contains { $0.isLowercase && $1.isUppercase }
    }
    return !camelCase && !code.contains { text.contains($0) }
}

@Test func testNewAnimationFromPreset() throws {
    var w = liveWorkspace(LiveScenes().newDocument(.vertical))
    let created = try #require(w.selectedScene)
    #expect(created.width == 1080 && created.height == 1920 && created.fps == 30 && !w.canUndo)
    expectOneStep(&w, "Set Scene Timing") { $0.setSceneTiming(fps: 60, durationFrames: created.durationFrames) }
    let scene = try #require(w.selectedScene)
    #expect(scene.width == 1080 && scene.height == 1920 && scene.fps == 60)
    #expect(scene.durationFrames == created.durationFrames)
}

@Test func testScenesAddRenameReorderRemove() throws {
    var w = liveWorkspace(FlareFixtures.bounce)
    expectOneStep(&w, "Add Scene") { $0.addScene() }
    let id = try #require(w.scenes.last?.id)
    #expect(id == "scene-2" && w.scenes.map(\.name) == ["Scene 1", "Scene 2"])
    w.selectScene(id)

    expectOneStep(&w, "Rename Scene") { $0.renameScene(id, to: "Outro") }
    #expect(w.scenes.map(\.name) == ["Scene 1", "Outro"])

    let outro = try #require(w.selectedScene)
    #expect(outro.id == id)
    expectOneStep(&w, "Set Canvas") {
        $0.setSceneCanvas(width: outro.width, height: outro.height, background: red)
    }
    #expect(w.scenes.last?.background == red && w.scenes.last?.width == outro.width)

    expectOneStep(&w, "Move Scene") { $0.moveScene(from: 1, to: 0) }
    #expect(w.scenes.map(\.name) == ["Outro", "Scene 1"])

    // J16: select Scene 1, then remove Outro, which is not the selected scene.
    w.selectScene("scene-1")
    #expect(w.selectedSceneID == "scene-1")
    expectOneStep(&w, "Delete Scene") { $0.removeScene(id) }
    #expect(w.scenes.map(\.name) == ["Scene 1"])
    #expect(w.selectedSceneID == "scene-1")

    // Step 3: the only scene stays; the workspace refuses it and nothing changes.
    let last = w.document
    w.removeScene("scene-1")
    #expect(w.layerError == .refused(FakeScenes.lastSceneMessage))
    #expect(w.layerError?.message == "An animation needs at least one scene.")
    #expect(w.document == last && w.undoActionName == "Undo Delete Scene")
}

@Test func testGuidesDragAsOneStep() throws {
    var w = liveWorkspace(FlareFixtures.bounce)
    expectOneStep(&w, "Add Guide") { $0.addGuide(.horizontal, at: 300) }
    #expect(w.guides.map(\.position) == [300] && w.guides.first?.axis == .horizontal)

    expectOneStep(&w, "Move Guide") {
        for step in 1...20 { $0.moveGuide(at: 0, to: 300 + Double(step), dragStart: 300) }
        $0.endGuideDrag()
    }
    #expect(w.guides.map(\.position) == [320])
    w.undo()
    #expect(w.guides.map(\.position) == [300] && w.undoActionName == "Undo Add Guide")
    w.redo()

    expectOneStep(&w, "Remove Guide") { $0.removeGuide(at: 0) }
    #expect(w.guides.isEmpty)
}

@Test func refusalsArePlainText() throws {
    var w = liveWorkspace(FlareFixtures.bounce)
    let start = w.document
    w.setSceneTiming(fps: 0, durationFrames: 48)
    #expect(w.layerError?.message == "Frame rate must be at least 1 fps.")
    #expect(isPlainSentence(w.layerError?.message) && w.document == start)

    w.renameScene("scene-1", to: "  ")
    #expect(w.layerError?.message == "Type a name for the scene.")
    #expect(isPlainSentence(w.layerError?.message) && w.document == start)

    w.removeScene("scene-1")
    #expect(isPlainSentence(w.layerError?.message) && w.document == start && !w.canUndo)

    // Refusals `LiveScenes` itself throws reach the person as sentences too, and change nothing.
    w.addGuide(.horizontal, at: 300)
    let guided = w.document, undoName = w.undoActionName
    let refusals: [(String, (inout FlareWorkspace) -> Void)] = [
        ("That item is no longer there.", { $0.removeGuide(at: 5) }),
        ("That item is no longer there.", { $0.moveGuide(at: 5, to: 310, dragStart: 300) }),
        ("This scene is no longer in the document.", { $0.renameScene("scene-9", to: "Outro") }),
    ]
    // Each refusal runs on its own copy, so one cannot pass on the error an earlier one left behind.
    for (message, refuse) in refusals {
        var attempt = w
        #expect(attempt.layerError == nil)
        refuse(&attempt)
        #expect(attempt.layerError?.message == message)
        #expect(isPlainSentence(attempt.layerError?.message))
        #expect(attempt.document == guided && attempt.undoActionName == undoName)
    }
    // The checker itself catches a case name.
    #expect(!isPlainSentence("The layer could not be changed (invalidIndex(5))."))
}

/// Every engine refusal reads as a sentence with no case name or engine text in it (QB-F2).
@Test func commandRefusalsArePlainText() {
    let errors: [CommandError] = [
        .invalidIndex(5), .sceneNotFound("scene-9"), .emptyName, .invalidDocument(FakeScenes.lastSceneMessage),
        .invalidDocument("scene scene-1: canvas size must be finite and > 0"), .layerNotFound("layer-9"),
        .notExecuted, .malformedCommand("bad"),
    ]
    for error in errors { #expect(isPlainSentence(FlareLayerError.command(error).message), "\(error)") }
    #expect(FlareLayerError.command(.invalidDocument(FakeScenes.lastSceneMessage)).message == FakeScenes.lastSceneMessage)
}

@Test func liveEqualsFake() throws {
    typealias Write = (any SceneEditing, inout CommandEngine) throws -> Void
    let writes: [Write] = [
        { _ = try $0.addScene(.vertical, in: &$1) },
        { try $0.renameScene("scene-2", to: "Outro", in: &$1) },
        { try $0.setCanvas("scene-2", width: 1080, height: 1920, background: red, in: &$1) },
        { try $0.setTiming("scene-2", fps: 60, durationFrames: 90, in: &$1) },
        { try $0.reorderScene("scene-2", to: 0, in: &$1) },
        { _ = try $0.addGuide(.horizontal, at: 300, sceneID: "scene-1", in: &$1) },
        { try $0.moveGuide(at: 0, to: 310, sceneID: "scene-1", coalesceKey: "drag", in: &$1) },
        { try $0.moveGuide(at: 0, to: 320, sceneID: "scene-1", coalesceKey: "drag", in: &$1) },
        { try $0.removeGuide(at: 0, sceneID: "scene-1", in: &$1) },
        { try $0.removeScene("scene-2", in: &$1) },
    ]
    var live = CommandEngine(document: FlareFixtures.bounce)
    var fake = CommandEngine(document: FlareFixtures.bounce)
    for write in writes {
        try write(LiveScenes(), &live)
        try write(FakeScenes(), &fake)
        #expect(live.document == fake.document && live.undoActionName == fake.undoActionName)
    }
    #expect(LiveScenes().newDocument(.vertical) == FakeScenes().newDocument(.vertical))
    while live.canUndo {
        try live.undo()
        try fake.undo()
        #expect(live.document == fake.document && live.undoActionName == fake.undoActionName)
    }
    #expect(live.document == FlareFixtures.bounce && !fake.canUndo)
}
