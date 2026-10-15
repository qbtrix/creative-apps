// LiveStageNestingTests.swift: ST-2 of live-stage (docs/blueprints/flare/features/live-stage.md). On a test-built
// scene whose layer holds an instance of "outer", which holds two instances of "inner", `LiveStage` draws every leaf
// shape in paint order with its opacity multiplied down the chain and its offset added up, addressed by the top
// instance with the deeper index in `instancePath` (the fake stops one level deep, so the expected values are
// computed here). Editing a symbol in place lists only that symbol's layers, owned by `.symbol`; a text item inside
// an instance is listed with an empty path and counted in `hiddenTextCount`.
import FlareCore
import FlareModel
import Testing

private let live = LiveStage()

private func solid(_ r: Double) -> Fill { .solid(FlareColor(r: r, g: 0, b: 0)) }

private func square(_ fill: Fill) -> FlareShape {
    FlareShape(points: [Point(x: 0, y: 0), Point(x: 4, y: 0), Point(x: 4, y: 4), Point(x: 0, y: 4)], fill: fill)
}

private let topOpacity = 0.5, outerOpacity = 0.8, innerOpacity = 0.6

/// Scene layer "top" (opacity 0.5): shape A, then an instance of "outer" at (100, 50). "outer"'s layer (0.8): shape
/// B, then instances of "inner" at (1, 1) and (10, 20). "inner"'s layer (0.6): shapes C and D.
private func nestedScene(outerTexts: [TextShape] = []) -> Document {
    let inner = Symbol(id: "inner", name: "Inner", layers: [
        Layer(id: "i-layer", name: "Inner", shapes: [square(solid(0.3)), square(solid(0.4))],
              tracks: ["opacity": [Keyframe(frame: 0, value: innerOpacity)]]),
    ])
    let outer = Symbol(id: "outer", name: "Outer", layers: [
        Layer(id: "o-layer", name: "Outer", shapes: [square(solid(0.2))],
              tracks: ["opacity": [Keyframe(frame: 0, value: outerOpacity)]],
              instances: [Instance(symbolID: "inner", transform: Transform(x: 1, y: 1)),
                          Instance(symbolID: "inner", transform: Transform(x: 10, y: 20))],
              texts: outerTexts),
    ])
    let top = Layer(id: "top", name: "Top", shapes: [square(solid(0.1))],
                    tracks: ["opacity": [Keyframe(frame: 0, value: topOpacity)]],
                    instances: [Instance(symbolID: "outer", transform: Transform(x: 100, y: 50))])
    return Document(scenes: [FlareScene(id: "scene-1", name: "Scene 1", layers: [top])], symbols: [outer, inner])
}

@Test func twoDeepInstancesDrawEveryLeafWithTheMultipliedOpacity() {
    let list = live.drawList(nestedScene(), sceneID: "scene-1", frame: 0, editing: nil)
    let deep = topOpacity * outerOpacity * innerOpacity
    let instance = StageAddress.Item.instance(0)
    func nested(_ path: [Int]) -> StageAddress {
        StageAddress(owner: .scene("scene-1"), layerID: "top", item: instance, instancePath: path)
    }
    // (fill, opacity, offset, address) of each leaf, in paint order: A, B, then C and D under each inner instance.
    let want: [(Fill, Double, (Double, Double), StageAddress)] = [
        (solid(0.1), topOpacity, (0, 0), StageAddress(owner: .scene("scene-1"), layerID: "top", item: .shape(0))),
        (solid(0.2), topOpacity * outerOpacity, (100, 50),
         StageAddress(owner: .scene("scene-1"), layerID: "top", item: instance)),
        (solid(0.3), deep, (101, 51), nested([0])),
        (solid(0.4), deep, (101, 51), nested([0])),
        (solid(0.3), deep, (110, 70), nested([1])),
        (solid(0.4), deep, (110, 70), nested([1])),
    ]
    #expect(list.items.count == want.count && list.hiddenTextCount == 0)
    for (got, (fill, opacity, offset, address)) in zip(list.items, want) {
        #expect(got.fill == fill && got.address == address && !got.isText)
        #expect(abs(got.opacity - opacity) <= 1e-12)
        #expect(abs(got.transform.tx - offset.0) <= 1e-9 && abs(got.transform.ty - offset.1) <= 1e-9)
        #expect(got.path.elements.count == 5)  // four corners and a close, as stored
    }
}

@Test func editingWaveInCharacterListsOnlyTheSymbolsLayers() {
    let doc = FlareFixtures.character
    let scene = live.drawList(doc, sceneID: "scene-1", frame: 6, editing: nil)
    #expect(scene.items.count == 5)  // two legs, the body, the hand through the instance, the head
    let list = live.drawList(doc, sceneID: "scene-1", frame: 6, editing: "wave")
    #expect(list.items.map(\.address) == [StageAddress(owner: .symbol("wave"), layerID: "hand", item: .shape(0))])
    #expect(list.width == scene.width && list.height == scene.height && list.hiddenTextCount == 0)
}

@Test func editingANestingSymbolListsItsLayersAndItsInstancesOnly() {
    let list = live.drawList(nestedScene(), sceneID: "scene-1", frame: 0, editing: "outer")
    #expect(list.items.allSatisfy { $0.address.owner == .symbol("outer") && $0.address.layerID == "o-layer" })
    #expect(list.items.map(\.address.item) == [.shape(0), .instance(0), .instance(0), .instance(1), .instance(1)])
    #expect(list.items.allSatisfy { $0.address.instancePath.isEmpty })
    let opacities = list.items.map(\.opacity)
    let want = [outerOpacity] + Array(repeating: outerOpacity * innerOpacity, count: 4)
    #expect(zip(opacities, want).allSatisfy { abs($0 - $1) <= 1e-12 })
}

@Test func aTextItemInsideAnInstanceIsCountedWithAnEmptyPath() {
    let text = TextShape(string: "Hi", fontFamily: "Helvetica", fontSize: 12, position: Point(x: 0, y: 0))
    let list = live.drawList(nestedScene(outerTexts: [text]), sceneID: "scene-1", frame: 0, editing: nil)
    #expect(list.hiddenTextCount == 1 && list.items.count == 7)
    let texts = list.items.filter(\.isText)
    #expect(texts.count == 1)
    #expect(texts.first?.path.elements.isEmpty == true && texts.first?.fill == nil)
    #expect(texts.first?.address == StageAddress(owner: .scene("scene-1"), layerID: "top", item: .instance(0)))
    #expect(abs((texts.first?.opacity ?? 0) - topOpacity * outerOpacity) <= 1e-12)
}
