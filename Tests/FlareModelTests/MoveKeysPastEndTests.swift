// MoveKeysPastEndTests.swift: a key move that would land past the scene's last frame refuses and changes nothing, so
// the final pose still plays (#636, the moveKeys half of #596).
import FlareCore
@testable import FlareModel
import Testing

private let services = FlareServices.fake()
private let scene = LayerOwner.scene("scene-1")

@Test func draggingTheLandingKeyPastTheLastFrameRefusesAndKeepsThePose() throws {
    var e = CommandEngine(document: FlareFixtures.bounce)
    #expect(e.document.scenes.first?.durationFrames == 48)
    #expect(throws: CommandError.invalidFrame(51)) {
        try services.keyframes.moveKeys([KeyRef(layerID: "ball", property: nil, frame: 47)], by: 4,
                                         owner: scene, coalesceKey: "drag", in: &e)
    }
    #expect(throws: CommandError.invalidFrame(48)) {
        try services.keyframes.moveKeys([KeyRef(layerID: "ball", property: "x", frame: 36)], by: 12,
                                         owner: scene, coalesceKey: nil, in: &e)
    }
    #expect(e.document == FlareFixtures.bounce && !e.canUndo)
    #expect(services.keyframes.rows(e.document, owner: scene).last?.keyFrames == [0, 12, 24, 36, 47])
    // A move that lands on the last frame itself still works.
    try services.keyframes.moveKeys([KeyRef(layerID: "ball", property: nil, frame: 47)], by: -1, owner: scene, coalesceKey: "drag", in: &e)
    try services.keyframes.moveKeys([KeyRef(layerID: "ball", property: nil, frame: 46)], by: 1, owner: scene, coalesceKey: "drag", in: &e)
    #expect(e.document == FlareFixtures.bounce && e.canUndo)
}
