// FrameDrawingContractTests.swift: what every FrameDrawing promises (#37),
// run over each conforming type in `frameDrawings`; the live type joins by
// adding itself there. Runs on Linux and macOS.
import HaloModel
import Testing

let frameDrawings: [any FrameDrawing] = [FakeFrameDrawing()]

@Test(arguments: frameDrawings)
func drawListSkipsNullsAndInterpolates(drawing: any FrameDrawing) {
    let list = drawing.drawList(keyedPair(), at: 15)
    #expect(list.items.map(\.layerID) == ["s"])
    #expect((list.width, list.height, list.frame) == (400, 200, 15))
    #expect(list.items.first?.matrix.apply(HaloPoint(x: 50, y: 50)) == HaloPoint(x: 100, y: 50))
}

@Test(arguments: frameDrawings)
func aLayerOutsideItsSpanIsAbsent(drawing: any FrameDrawing) {
    var comp = keyedPair()
    comp.layers[1].inFrame = 20
    comp.layers[1].outFrame = 40
    #expect(drawing.drawList(comp, at: 19).items.isEmpty)
    #expect(drawing.drawList(comp, at: 20).items.map(\.layerID) == ["s"])
    #expect(drawing.drawList(comp, at: 39).items.map(\.layerID) == ["s"])
    #expect(drawing.drawList(comp, at: 40).items.isEmpty)
}

@Test(arguments: frameDrawings)
func drawOrderIsBottomFirst(drawing: any FrameDrawing) {
    var comp = keyedPair()
    let top = HaloLayer(
        id: "t", name: "Solid 2", kind: .solid, inFrame: 0, outFrame: 60, color: HaloLayerColor(red: 0, green: 1, blue: 0))
    comp.layers.insert(top, at: 0)
    #expect(drawing.drawList(comp, at: 0).items.map(\.layerID) == ["s", "t"])
}
