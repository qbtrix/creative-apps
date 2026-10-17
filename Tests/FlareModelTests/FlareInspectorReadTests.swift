// FlareInspectorReadTests.swift: the inspector header and info card (inspector-timeline IT-1) on `.fake()`. Nothing
// selected reads the scene; Ball at frame 12 reads its name, kind, frame, squashed size and five keys; Ball and Shadow
// read "2 layers" with no key count; inside the symbol "wave" the hand reads its own keys.
import FlareCore
@testable import FlareModel
import Testing

private func bounce() -> FlareWorkspace {
    var w = FlareWorkspace(services: .fake())
    w.load(FlareFixtures.bounce)
    return w
}

@Test func inspectorSummaryWithNothingSelectedShowsTheScene() {
    let summary = bounce().inspectorSummary
    #expect(summary == InspectorSummary(title: "Scene 1", kind: "Scene", frame: 0, size: "550 × 400 px", keys: nil,
                                        showsScene: true))
}

@Test func inspectorSummaryReadsOneLayerAtThePlayhead() {
    var w = bounce()
    w.selectLayer("ball")
    w.currentFrame = 12
    // Ball is a 60 pt circle, squashed to 1.25 × 0.75 at frame 12, keyed at 0, 12, 24, 36 and 47.
    #expect(w.inspectorSummary == InspectorSummary(title: "Ball", kind: "Shape", frame: 12, size: "75 × 45 px",
                                                   keys: 5, showsScene: false))
    w.selectLayer("shadow")
    #expect(w.inspectorSummary.title == "Shadow" && w.inspectorSummary.keys == 0 && w.inspectorSummary.size == "80 × 16 px")
}

@Test func inspectorSummaryReadsSeveralLayersWithoutKeys() {
    var w = bounce()
    w.currentFrame = 12
    w.setSelection([StageAddress(owner: .scene("scene-1"), layerID: "ball", item: .shape(0)),
                    StageAddress(owner: .scene("scene-1"), layerID: "shadow", item: .shape(0))])
    let summary = w.inspectorSummary
    #expect(summary.title == "2 layers" && summary.keys == nil && !summary.showsScene)
    #expect(summary.kind == "Shape" && summary.frame == 12)
}

@Test func inspectorSummaryInsideAnEditedSymbolReadsTheChildsKeys() {
    var w = FlareWorkspace(services: .fake())
    w.load(FlareFixtures.character)
    w.selectLayer("arms")
    #expect(w.inspectorSummary.kind == "Instance" && w.inspectorSummary.keys == 0)
    w.editSymbol("wave")
    w.selectLayer("hand")
    let hand = w.inspectorSummary
    #expect(hand.title == "Hand" && hand.kind == "Shape" && hand.keys == 3 && !hand.showsScene)
}

@Test func inspectorKindTellsShapesInstancesAndGroups() {
    let shape = FlareShape(points: [Point(x: 0, y: 0), Point(x: 1, y: 1)], fill: .solid(FlareColor(r: 0, g: 0, b: 0)))
    let instance = Instance(symbolID: "wave", transform: Transform())
    #expect(FlareWorkspace.inspectorKind(Layer(id: "a", name: "A", shapes: [shape])) == "Shape")
    #expect(FlareWorkspace.inspectorKind(Layer(id: "b", name: "B", instances: [instance])) == "Instance")
    #expect(FlareWorkspace.inspectorKind(Layer(id: "c", name: "C", shapes: [shape], instances: [instance])) == "Group")
}
