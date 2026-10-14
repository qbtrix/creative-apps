// InsertFramesSceneEndTests.swift: Insert Frame keeps a scene's ending (#596). When a shifted key passes the scene's
// last frame, the scene grows by just enough in the same undo step, so the final pose still plays.
import FlareCore
@testable import FlareModel
import Testing

private let services = FlareServices.fake()
private let scene = LayerOwner.scene("scene-1")
private let bounce = FlareFixtures.bounce

private func duration(_ e: CommandEngine) -> Int? { e.document.scenes.first { $0.id == "scene-1" }?.durationFrames }
private func frames(_ e: CommandEngine) -> [Int] { services.keyframes.rows(e.document, owner: scene).last?.keyFrames ?? [] }

@Test func insertFramePastTheEndGrowsTheSceneSoTheLandingPlays() throws {
    var e = CommandEngine(document: bounce)
    let all = e.document.layers(of: scene)?.map(\.id) ?? []
    try services.keyframes.insertFrames(1, at: 10, layerIDs: all, owner: scene, in: &e)
    try services.keyframes.insertFrames(1, at: 10, layerIDs: all, owner: scene, in: &e)
    #expect(services.keyframes.rows(e.document, owner: scene).last?.keyFrames == [0, 14, 26, 38, 49])
    #expect(duration(e) == 50)
    let path = services.onion.motionPath(e.document, owner: scene, layerID: "ball")
    #expect(path.count == 50 && path.last == Point(x: 470, y: 100))
    // Each insert, scene growth included, is one undo step.
    try e.undo()
    #expect(duration(e) == 49 && e.undoActionName == "Undo Insert Frame")
    try e.undo()
    #expect(e.document == bounce)
}

@Test func insertFrameThatStaysInsideTheSceneLeavesItsLength() throws {
    // No key at or after the insert point: nothing shifts, so the scene keeps its length.
    var e = CommandEngine(document: bounce)
    try services.keyframes.insertFrames(3, at: 48, layerIDs: ["ball"], owner: scene, in: &e)
    #expect(e.document == bounce)
    // Room to spare after the last key: the keys shift and the scene keeps its length.
    var longer = bounce
    longer.scenes[0].durationFrames = 60
    var f = CommandEngine(document: longer)
    try services.keyframes.insertFrames(5, at: 0, layerIDs: ["ball"], owner: scene, in: &f)
    #expect(frames(f).last == 52 && duration(f) == 60)
}
