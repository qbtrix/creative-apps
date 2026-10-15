// ViewerDraggingContractTests.swift: what every ViewerDragging promises
// (#207), run over each conforming type in `viewerDraggings`; the live type
// joins by adding itself there. Runs on Linux and macOS.
import HaloModel
import Testing

let viewerDraggings: [any ViewerDragging] = [FakeViewerDragging()]

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
