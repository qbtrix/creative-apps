// LivePropertiesTests.swift: KY-1, the live inspector read (docs/blueprints/flare/features/live-keys.md). It agrees with
// FakeProperties on `bounce` for every selection and frame the packet names, reads a symbol's layer the same way, and
// returns no rows when nothing is selected.
import FlareCore
@testable import FlareModel
import Testing

private let scene = LayerOwner.scene("scene-1")
private let wave = LayerOwner.symbol("wave")

@Test(arguments: [["ball"], ["shadow"], ["ball", "shadow"]], [0, 12, 30, 47])
func liveRowsEqualTheFakeOnBounce(layerIDs: [String], frame: Int) {
    let doc = FlareFixtures.bounce
    let live = LiveProperties().properties(doc, owner: scene, layerIDs: layerIDs, frame: frame)
    let fake = FakeProperties().properties(doc, owner: scene, layerIDs: layerIDs, frame: frame)
    #expect(live.count == FakeProperties.rows.count)
    #expect(live == fake)
}

@Test func ballAndShadowAtZeroGiveAMixedNotAnimatedScaleX() {
    let rows = LiveProperties().properties(FlareFixtures.bounce, owner: scene, layerIDs: ["ball", "shadow"], frame: 0)
    let scaleX = rows.first { $0.name == "scaleX" }
    #expect(scaleX != nil)
    #expect(scaleX?.value == nil && scaleX?.keyState == .notAnimated)
}

@Test(arguments: [0, 6, 12, 23])
func aSymbolLayerReadsLikeTheFake(frame: Int) {
    let doc = FlareFixtures.character
    let live = LiveProperties().properties(doc, owner: wave, layerIDs: ["hand"], frame: frame)
    #expect(!live.isEmpty)
    #expect(live == FakeProperties().properties(doc, owner: wave, layerIDs: ["hand"], frame: frame))
}

@Test func theHandRotatesTo25AtFrame12() {
    let rotation = LiveProperties().properties(FlareFixtures.character, owner: wave, layerIDs: ["hand"], frame: 12)
        .first { $0.name == "rotation" }
    #expect(rotation?.value == 25 && rotation?.keyState == .keyedHere)
}

@Test func noSelectionOrAMissingOwnerGivesNoRows() {
    let live = LiveProperties()
    #expect(live.properties(FlareFixtures.bounce, owner: scene, layerIDs: [], frame: 0).isEmpty)
    #expect(live.properties(FlareFixtures.bounce, owner: scene, layerIDs: ["nope"], frame: 0).isEmpty)
    #expect(live.properties(FlareFixtures.bounce, owner: .scene("missing"), layerIDs: ["ball"], frame: 0).isEmpty)
}
