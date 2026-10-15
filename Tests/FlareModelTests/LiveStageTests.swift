// LiveStageTests.swift: ST-1 of live-stage (docs/blueprints/flare/features/live-stage.md). `LiveStage` draws
// `bounce` item for item like the hand-built stage at frames 0, 12 and 47, drops a hidden layer, keeps every cubic
// of a shape's outline a cubic (QB-V1), lists text with an empty path and counts it, and gives a 0 × 0 list with no
// items for a scene id that doesn't exist.
import FlareCore
import FlareModel
import Testing

private let live = LiveStage()
private let reference = FlareServices.fake().stage
private let bounce = FlareFixtures.bounce

private func near(_ a: Matrix, _ b: Matrix) -> Bool {
    zip([a.a, a.b, a.c, a.d, a.tx, a.ty], [b.a, b.b, b.c, b.d, b.tx, b.ty]).allSatisfy { abs($0 - $1) <= 1e-9 }
}

@Test(arguments: [0, 12, 47])
func bounceEqualsTheReferenceStageItemForItem(frame: Int) {
    let got = live.drawList(bounce, sceneID: "scene-1", frame: frame, editing: nil)
    let want = reference.drawList(bounce, sceneID: "scene-1", frame: frame, editing: nil)
    #expect(got.width == want.width && got.height == want.height && got.background == want.background)
    #expect(got.hiddenTextCount == want.hiddenTextCount && got.items.count == want.items.count && got.items.count == 3)
    for (g, w) in zip(got.items, want.items) {
        #expect(g.address == w.address && g.path == w.path && g.fill == w.fill && g.stroke == w.stroke)
        #expect(near(g.transform, w.transform) && abs(g.opacity - w.opacity) <= 1e-9 && g.isText == w.isText)
    }
}

@Test func aHiddenLayerIsAbsent() {
    var doc = bounce
    doc.scenes[0].layers[1].isVisible = false
    let list = live.drawList(doc, sceneID: "scene-1", frame: 0, editing: nil)
    #expect(list.items.map(\.address.layerID) == ["background", "ball"])
}

@Test func cubicsKept() throws {
    let list = live.drawList(bounce, sceneID: "scene-1", frame: 12, editing: nil)
    let shapes = try #require(bounce.scenes.first).layers.flatMap(\.shapes)
    #expect(list.items.count == shapes.count)
    var cubics = 0
    for (item, shape) in zip(list.items, shapes) {
        let want = shape.outline.elements
        #expect(item.path.elements.count == want.count)
        for (g, w) in zip(item.path.elements, want) {
            if case .cubic = w {
                cubics += 1
                guard case .cubic = g else { Issue.record("a cubic became \(g)"); continue }
            }
            #expect(g == w)
        }
    }
    #expect(cubics == 8)  // Shadow and Ball are four cubic quarters each.
}

@Test func layerOpacityIsCarried() {
    var doc = bounce
    doc.scenes[0].layers[2].tracks["opacity"] = [Keyframe(frame: 0, value: 0.4)]
    let list = live.drawList(doc, sceneID: "scene-1", frame: 0, editing: nil)
    #expect(list.items.map(\.opacity) == [1, 1, 0.4])
}

@Test func textIsListedWithAnEmptyPathAndCounted() {
    var doc = bounce
    doc.scenes[0].layers[2].texts = [TextShape(string: "Hi", fontFamily: "Helvetica", fontSize: 12, position: Point(x: 0, y: 0))]
    let list = live.drawList(doc, sceneID: "scene-1", frame: 0, editing: nil)
    #expect(list.hiddenTextCount == 1 && list.items.count == 4)
    let text = list.items.last
    #expect(text?.isText == true && text?.path.elements.isEmpty == true && text?.address.item == .text(0))
    #expect(text?.address.layerID == "ball")
}

@Test func noSceneWithThatIDGivesAnEmptyZeroSizedList() {
    let list = live.drawList(bounce, sceneID: "nope", frame: 0, editing: nil)
    #expect(list == reference.drawList(bounce, sceneID: "nope", frame: 0, editing: nil))
    #expect(list.width == 0 && list.height == 0 && list.items.isEmpty && list.hiddenTextCount == 0)
}

@Test func anEmptySceneDrawsOnlyItsBackground() {
    let list = live.drawList(FlareFixtures.empty, sceneID: "scene-1", frame: 0, editing: nil)
    #expect(list.items.isEmpty && list.width > 0 && list.height > 0)
    let usedAsContract: any StageRendering = live
    #expect(usedAsContract.drawList(bounce, sceneID: "scene-1", frame: 0, editing: nil).items.count == 3)
}
