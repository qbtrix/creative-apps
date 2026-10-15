// ViewerDraggingContractTests.swift: what every ViewerDragging promises
// (#207), run over the fake and the live type. Fixture layers are looked up
// by name. Runs on Linux and macOS.
import HaloModel
import Testing

let viewerDraggings: [any ViewerDragging] = [FakeViewerDragging(), LiveViewerDragging()]

/// The first composition of fixture `name`.
private func fixtureComp(_ name: String) throws -> HaloComposition {
    try #require(HaloFixtures.project(name)?.compositions.first)
}

/// The id of the layer called `name` in `comp`.
private func layerID(_ name: String, in comp: HaloComposition) throws -> String {
    try #require(comp.layers.first { $0.name == name }).id
}

@Test func liveDraggingIsAvailable() {
    #expect(LiveViewerDragging().unavailableHelp == nil)
    #expect(FakeViewerDragging().unavailableHelp == nil)
}

@Test(arguments: viewerDraggings)
func hitPicksTheTopmostDrawnLayer(dragging: any ViewerDragging) throws {
    let comp = try fixtureComp("three-layers")
    let center = HaloPoint(x: 960, y: 540)
    #expect(dragging.hit(comp, at: 30, point: center) == (try layerID("Title", in: comp)))
    // Before Title's span the topmost layer under the point is Background (Badge sits top left).
    #expect(dragging.hit(comp, at: 12, point: center) == (try layerID("Background", in: comp)))
    #expect(dragging.hit(comp, at: 12, point: HaloPoint(x: 100, y: 100)) == (try layerID("Badge", in: comp)))
}

@Test(arguments: viewerDraggings)
func hitNeverPicksANull(dragging: any ViewerDragging) throws {
    var comp = try fixtureComp("three-layers")
    comp.layers.removeAll { $0.kind != .null }
    // Rig's zero-size box sits exactly on the center.
    #expect(dragging.hit(comp, at: 30, point: HaloPoint(x: 960, y: 540)) == nil)
}

@Test(arguments: viewerDraggings)
func hitOnAnEmptyCompositionIsNil(dragging: any ViewerDragging) throws {
    let comp = try fixtureComp("empty")
    for x in stride(from: -100.0, through: 2000, by: 250) {
        for y in stride(from: -100.0, through: 1200, by: 200) {
            #expect(dragging.hit(comp, at: 0, point: HaloPoint(x: x, y: y)) == nil)
        }
    }
}

@Test(arguments: viewerDraggings)
func dragAddsAKeyOnAnAnimatedPosition(dragging: any ViewerDragging) throws {
    var comp = try fixtureComp("keyed")
    let ball = try layerID("Ball", in: comp)
    try dragging.commitMove(ball, by: HaloPoint(x: 100, y: 0), at: 12, in: &comp)
    let track = try #require(comp.layers.first { $0.id == ball }?.tracks["x"])
    #expect(track.map(\.frame) == [0, 12, 24])
    #expect(track.first { $0.frame == 12 }?.value == 660)
}

@Test(arguments: viewerDraggings)
func dragMovesAStaticPositionWithoutKeying(dragging: any ViewerDragging) throws {
    var comp = try fixtureComp("keyed")
    let floor = try layerID("Floor", in: comp)
    let old = try #require(FakeLayerPlacing().value(.y, of: floor, in: comp, at: 0))
    try dragging.commitMove(floor, by: HaloPoint(x: 0, y: 50), at: 0, in: &comp)
    let track = try #require(comp.layers.first { $0.id == floor }?.tracks["y"])
    #expect(track == [HaloKeyframe(frame: 0, value: old + 50)])
}

@Test(arguments: viewerDraggings)
func aParentedMoveLandsInTheParentsSpace(dragging: any ViewerDragging) throws {
    var comp = try fixtureComp("parented")
    let rig = try layerID("Rig", in: comp), ball = try layerID("Ball", in: comp)
    let rigIndex = try #require(comp.layers.firstIndex { $0.id == rig })
    let ballIndex = try #require(comp.layers.firstIndex { $0.id == ball })
    comp.layers[rigIndex].tracks["scaleX"] = [HaloKeyframe(frame: 0, value: 2)]
    comp.layers[ballIndex].parentID = rig
    let placing = FakeLayerPlacing()
    let (x, y) = (placing.value(.x, of: ball, in: comp, at: 12), placing.value(.y, of: ball, in: comp, at: 12))
    try dragging.commitMove(ball, by: HaloPoint(x: 100, y: 0), at: 12, in: &comp)
    #expect(placing.value(.x, of: ball, in: comp, at: 12) == x.map { $0 + 50 })
    #expect(placing.value(.y, of: ball, in: comp, at: 12) == y)
}

@Test(arguments: viewerDraggings)
func aZeroDragOnAFixtureChangesNothing(dragging: any ViewerDragging) throws {
    var comp = try fixtureComp("keyed")
    let before = comp
    try dragging.commitMove(try layerID("Ball", in: comp), by: HaloPoint(x: 0, y: 0), at: 12, in: &comp)
    #expect(comp == before)
}

@Test(arguments: viewerDraggings)
func dragKeysAnimatedPosition(dragging: any ViewerDragging) throws {
    var comp = keyedPair()
    #expect(dragging.hit(comp, at: 0, point: HaloPoint(x: 50, y: 50)) == "s")
    try dragging.commitMove("s", by: HaloPoint(x: 10, y: 0), at: 15, in: &comp)
    #expect(comp.layers[1].tracks["x"]?.map(\.frame) == [0, 15, 30])
    #expect(FakeLayerPlacing().value(.x, of: "s", in: comp, at: 15) == 110)
}

@Test(arguments: viewerDraggings)
func hitMissesNullsAndEmptySpace(dragging: any ViewerDragging) {
    let comp = keyedPair()
    #expect(dragging.hit(comp, at: 0, point: HaloPoint(x: 350, y: 150)) == nil)
    #expect(dragging.hit(comp, at: 60, point: HaloPoint(x: 50, y: 50)) == nil)
}

@Test(arguments: viewerDraggings)
func aZeroDragChangesNothing(dragging: any ViewerDragging) throws {
    var comp = keyedPair()
    let before = comp
    try dragging.commitMove("s", by: HaloPoint(x: 0, y: 0), at: 15, in: &comp)
    #expect(comp == before)
}

@Test(arguments: viewerDraggings)
func draggingAMissingLayerThrowsAndChangesNothing(dragging: any ViewerDragging) {
    var comp = keyedPair()
    let before = comp
    #expect(throws: HaloEditError.unknownLayer("gone")) {
        try dragging.commitMove("gone", by: HaloPoint(x: 5, y: 5), at: 0, in: &comp)
    }
    #expect(comp == before)
}
