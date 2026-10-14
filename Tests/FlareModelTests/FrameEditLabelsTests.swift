// FrameEditLabelsTests.swift: Insert Frame and Remove Frame carry frame labels with the frames they move (#637). On
// every layer, labels at or after the edit point shift by the same count in the same undo step; a label inside a
// removed run is removed. An edit on some layers only leaves the scene ruler, and so its labels, as it was.
import FlareCore
@testable import FlareModel
import Testing

private let services = FlareServices.fake()
private let scene = LayerOwner.scene("scene-1")
private let bounce = FlareFixtures.bounce

private func labels(_ e: CommandEngine) -> [String: Int] { services.keyframes.labels(e.document, sceneID: "scene-1") }
private func ball(_ e: CommandEngine) -> [Int] { services.keyframes.rows(e.document, owner: scene).last?.keyFrames ?? [] }
private func allLayers(_ e: CommandEngine) -> [String] { e.document.layers(of: scene)?.map(\.id) ?? [] }

@Test func insertFrameOnEveryLayerMovesLabelsWithTheirPoses() throws {
    var e = CommandEngine(document: bounce)
    try services.keyframes.setLabel("start", at: 5, sceneID: "scene-1", in: &e)
    try services.keyframes.setLabel("hit", at: 24, sceneID: "scene-1", in: &e)
    try services.keyframes.setLabel("land", at: 47, sceneID: "scene-1", in: &e)
    let before = e.document
    try services.keyframes.insertFrames(2, at: 10, layerIDs: allLayers(e), owner: scene, in: &e)
    #expect(ball(e) == [0, 14, 26, 38, 49])
    #expect(labels(e) == ["start": 5, "hit": 26, "land": 49])
    // Keys, labels and the scene's growth are one undo step.
    #expect(e.undoActionName == "Undo Insert Frame")
    try e.undo()
    #expect(e.document == before)
}

@Test func insertFrameCanPushALabelPastTheEndAndTheSceneGrowsToHoldIt() throws {
    var e = CommandEngine(document: bounce)
    try services.keyframes.setLabel("end", at: 48, sceneID: "scene-1", in: &e)
    try services.keyframes.insertFrames(3, at: 48, layerIDs: allLayers(e), owner: scene, in: &e)
    // No key at or after frame 48 moves, but the label does, past the scene's 49 frames.
    #expect(labels(e) == ["end": 51])
    #expect((e.document.scenes.first { $0.id == "scene-1" }?.durationFrames ?? 0) >= 51)
}

@Test func removeFrameOnEveryLayerMovesLaterLabelsAndDropsOnesInTheRun() throws {
    var e = CommandEngine(document: bounce)
    try services.keyframes.setLabel("start", at: 5, sceneID: "scene-1", in: &e)
    try services.keyframes.setLabel("gone", at: 12, sceneID: "scene-1", in: &e)
    try services.keyframes.setLabel("hit", at: 24, sceneID: "scene-1", in: &e)
    let before = e.document
    try services.keyframes.removeFrames(4, at: 10, layerIDs: allLayers(e), owner: scene, in: &e)
    #expect(ball(e) == [0, 20, 32, 43])
    #expect(labels(e) == ["start": 5, "hit": 20])
    #expect(e.undoActionName == "Undo Remove Frame")
    try e.undo()
    #expect(e.document == before)
}

@Test func aFrameEditOnSomeLayersLeavesLabelsWhereTheyAre() throws {
    var e = CommandEngine(document: bounce)
    try services.keyframes.setLabel("hit", at: 24, sceneID: "scene-1", in: &e)
    try services.keyframes.insertFrames(2, at: 10, layerIDs: ["ball"], owner: scene, in: &e)
    try services.keyframes.removeFrames(4, at: 20, layerIDs: ["ball"], owner: scene, in: &e)
    #expect(labels(e) == ["hit": 24])
}
