// ServicesEasingTests.swift: `FlareServices.easing` is the per-keyframe `KeyframeEasing`
// (flare.md 6.2/6.3), not the window-level `EasingEditing`. Checks the static type and
// `NotBuilt` itself, never which member `.fake`/`.live` hold today (#405).
import FlareCore
import FlareModel
import Testing

private let fixture = Document(scenes: [FlareScene(id: "scene-1", name: "Scene 1")])

@Test func servicesEasingSlotTakesAnyKeyframeEasing() {
    let slot: any KeyframeEasing = NotBuilt(reason: "Not built yet (test).")
    var services = FlareServices.fake()
    services.easing = slot
    let easing: any KeyframeEasing = services.easing
    #expect(!(easing is any EasingEditing))
    #expect(easing.presets.isEmpty && easing.curve(.easeInOut, count: 0).isEmpty)
    #expect(easing.curve(.linear, count: -1).isEmpty && easing.curve(.ease, count: Int.max).isEmpty)
}

@Test func notBuiltSetEasingThrowsItsReasonAndChangesNothing() {
    let easing: any KeyframeEasing = NotBuilt(reason: "Not connected yet (test).")
    var engine = CommandEngine(document: fixture)
    for key in [KeyRef(layerID: "missing", property: nil, frame: -1), KeyRef(layerID: "", property: "x", frame: Int.max)] {
        #expect(throws: NotBuilt(reason: "Not connected yet (test).")) {
            try easing.setEasing(.hold, at: key, owner: .scene("scene-1"), coalesceKey: "drag", in: &engine)
        }
    }
    #expect(engine.document == fixture && !engine.canUndo)
}
