// J5MarqueeAdversarialTests.swift: adversarial checks on #465's fix, bounce's locked Background (blueprint section 4
// fixtures, J5): no frame, spot or reorder lets a stage click or marquee pick Background, and unlocking it from the
// Layers panel brings it back as one undo step.
import FlareCore
@testable import FlareModel
import Testing

private let hits = FlareServices.fake().hits
private let bounce = FlareFixtures.bounce
private let artboard = Rect(minX: 0, minY: 0, maxX: 550, maxY: 400)
private func address(_ layerID: String) -> StageAddress {
    StageAddress(owner: .scene("scene-1"), layerID: layerID, item: .shape(0))
}

@Test func atEveryFrameAMarqueeOverTheWholeArtboardSelectsOnlyShadowAndBall() {
    for frame in 0..<48 {
        #expect(hits.marquee(bounce, sceneID: "scene-1", frame: frame, rect: artboard) == [address("shadow"), address("ball")])
    }
}

@Test func noEmptySpotOnTheArtboardHitsBackground() {
    for x in stride(from: 0.0, through: 550, by: 10) {
        for y in stride(from: 0.0, through: 400, by: 10) {
            let hit = hits.hit(bounce, sceneID: "scene-1", frame: 0, at: Point(x: x, y: y), tolerance: 4)
            #expect(hit?.layerID != "background", "(\(x), \(y))")
        }
    }
    let corner = Rect(minX: 400, minY: 10, maxX: 540, maxY: 60)
    #expect(hits.marquee(bounce, sceneID: "scene-1", frame: 0, rect: corner).isEmpty)
}

@Test func theJ5SelectionBoxEnclosesBallAndShadowOnly() throws {
    let picked = hits.marquee(bounce, sceneID: "scene-1", frame: 0, rect: Rect(minX: 30, minY: 40, maxX: 330, maxY: 370))
    let box = try #require(hits.bounds(bounce, sceneID: "scene-1", frame: 0, of: picked))
    // Ball 50...110 × 70...130 and Shadow 235...315 × 344...360; Background would make it 0...550 × 0...400.
    #expect(box == Rect(minX: 50, minY: 70, maxX: 315, maxY: 360))
    #expect(hits.bounds(bounce, sceneID: "scene-1", frame: 0, of: [address("background")]) == nil)
}

@Test func aLockedBackgroundMovedToTheTopStillLetsClicksThrough() {
    var workspace = FlareWorkspace()
    workspace.load(bounce)
    workspace.moveLayer(from: 2, to: 0)
    guard let doc = workspace.document else { return #expect(Bool(false), "bounce did not load") }
    #expect(doc.scenes[0].layers.last?.id == "background")
    #expect(hits.hit(doc, sceneID: "scene-1", frame: 0, at: Point(x: 80, y: 100), tolerance: 0) == address("ball"))
    #expect(hits.marquee(doc, sceneID: "scene-1", frame: 0, rect: artboard) == [address("shadow"), address("ball")])
}

@Test func unlockingBackgroundInTheLayersPanelMakesItPickableAndUndoLocksItAgain() {
    var workspace = FlareWorkspace()
    workspace.load(bounce)
    func picked() -> [String] {
        workspace.document.map { hits.marquee($0, sceneID: "scene-1", frame: 0, rect: artboard).map(\.layerID) } ?? []
    }
    workspace.toggleLayerFlag("background", .locked)
    #expect(picked() == ["background", "shadow", "ball"] && workspace.layerError == nil)
    workspace.undo()
    #expect(picked() == ["shadow", "ball"] && workspace.document == bounce)
    workspace.redo()
    workspace.toggleLayerFlag("background", .locked)
    #expect(picked() == ["shadow", "ball"])
}
