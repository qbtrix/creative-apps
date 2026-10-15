// FrameDrawingContractTests.swift: what every FrameDrawing promises (#37),
// run over each conforming type in `frameDrawings` (the fake and the live
// type), plus the draw list's summary and world box. The fixture lists are
// H-J2's. Runs on Linux and macOS.
import HaloModel
import Testing

let frameDrawings: [any FrameDrawing] = [FakeFrameDrawing(), LiveFrameDrawing(placing: FakeLayerPlacing())]

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

/// The first composition of fixture `name`.
private func fixtureComp(_ name: String) throws -> HaloComposition {
    try #require(HaloFixtures.project(name)?.compositions.first)
}

/// The names of the layers `drawing` lists for `comp` at `frame`, bottom first.
private func drawnNames(_ drawing: any FrameDrawing, _ comp: HaloComposition, at frame: Int) -> [String] {
    drawing.drawList(comp, at: frame).items.compactMap { item in comp.layers.first { $0.id == item.layerID }?.name }
}

@Test(arguments: frameDrawings)
func threeLayersListsWhatIsInSpanBottomFirst(drawing: any FrameDrawing) throws {
    let comp = try fixtureComp("three-layers")
    #expect(drawnNames(drawing, comp, at: 12) == ["Background", "Badge"])
    #expect(drawnNames(drawing, comp, at: 30) == ["Background", "Badge", "Title"])
    #expect(drawing.drawList(comp, at: 30).items.last?.text?.string == "Hello Halo")
}

@Test(arguments: frameDrawings)
func keyedSamplesPositionAndOpacity(drawing: any FrameDrawing) throws {
    let comp = try fixtureComp("keyed")
    for (frame, x, opacity) in [(12, 560.0, 1.0), (6, 360, 0.5)] {
        let ball = try #require(drawing.drawList(comp, at: frame).items.first { $0.layerID == "comp-1-layer-2" })
        let box = ball.bounds
        #expect(ball.matrix.apply(HaloPoint(x: box.x + box.width / 2, y: box.y + box.height / 2)).x == x)
        #expect(ball.opacity == opacity)
    }
}

@Test(arguments: frameDrawings)
func parentedNeverListsTheRig(drawing: any FrameDrawing) throws {
    let comp = try fixtureComp("parented")
    for frame in [0, 24, 47] { #expect(!drawnNames(drawing, comp, at: frame).contains("Rig")) }
}

@Test func liveDrawingMatchesTheFakeAndActs() throws {
    let comp = try fixtureComp("three-layers")
    #expect(LiveFrameDrawing().drawList(comp, at: 30) == FakeFrameDrawing().drawList(comp, at: 30))
    #expect(LiveFrameDrawing().unavailableHelp == nil)
}

@Test func drawnSummaryCountsTheItems() throws {
    let comp = try fixtureComp("three-layers")
    let drawing = FakeFrameDrawing()
    #expect(drawing.drawList(comp, at: 30).drawnSummary == "3 layers drawn")
    var one = comp
    one.layers.removeAll { $0.name != "Badge" }
    #expect(drawing.drawList(one, at: 0).drawnSummary == "1 layer drawn")
    #expect(drawing.drawList(comp, at: 72).drawnSummary == "No layers drawn")
}

@Test func worldBoxIsTheTransformedCornersBox() throws {
    var comp = try fixtureComp("three-layers")
    let badge = try #require(comp.layers.firstIndex { $0.name == "Badge" })
    comp.layers[badge].rect = nil  // the default shape box
    let list = FakeFrameDrawing().drawList(comp, at: 12)
    #expect(list.worldBox(of: comp.layers[badge].id) == HaloLayerRect(x: 860, y: 440, width: 200, height: 200))
    #expect(list.worldBox(of: "comp-1-layer-1") == nil)
}
