// HaloDrawLiftTests.swift: a viewer drag's lift (HaloDrawLift.swift): the
// split around the dragged layer, the blend modes that refuse it, and that
// the lift moved by the drag's delta draws what the offset list draws.
// Runs on Linux and macOS.
import CoreRaster
@testable import HaloModel
import Testing

private func item(_ id: String, blend: BlendMode = .normal, opacity: Double = 1) -> HaloDrawItem {
    HaloDrawItem(
        layerID: id, kind: .solid, bounds: HaloLayerRect(x: 0, y: 0, width: 10, height: 10),
        matrix: .translation(x: 5, y: 0), opacity: opacity, color: HaloLayerKind.solid.defaultColor,
        blendMode: blend)
}

private func list(_ items: [HaloDrawItem]) -> HaloDrawList {
    HaloDrawList(width: 100, height: 80, frame: 3, items: items)
}

@Test func liftSplitsTheFrameAroundTheDraggedLayer() throws {
    let frame = list([item("a"), item("b", opacity: 0.5), item("c"), item("d")])
    let lift = try #require(frame.lift("b"))
    #expect(lift.layerID == "b")
    #expect(lift.below.items.map(\.layerID) == ["a"])
    #expect(lift.lifted.items.map(\.layerID) == ["b"])
    #expect(lift.above.items.map(\.layerID) == ["c", "d"])
    for part in [lift.below, lift.lifted, lift.above] {
        #expect(part.width == 100 && part.height == 80 && part.frame == 3)
    }
    // The parts in order, the lifted one offset, are the offset list.
    let delta = HaloPoint(x: 100, y: -20)
    let moved = lift.lifted.offsetting("b", by: delta)
    #expect(lift.below.items + moved.items + lift.above.items == frame.offsetting("b", by: delta).items)
}

@Test func liftAtTheEdgesOfTheStack() throws {
    let frame = list([item("a"), item("b")])
    #expect(try #require(frame.lift("a")).below.items.isEmpty)
    #expect(try #require(frame.lift("b")).above.items.isEmpty)
}

@Test func liftRefusesWhatGroupingWouldChange() {
    // Under the lifted layer any blend is fine: it is drawn with its own backdrop.
    #expect(list([item("a", blend: .multiply), item("b")]).lift("b") != nil)
    #expect(list([item("a"), item("b", blend: .screen)]).lift("b") == nil)
    #expect(list([item("a"), item("b"), item("c", blend: .difference)]).lift("b") == nil)
    #expect(list([item("a")]).lift("missing") == nil)
    #expect(list([item("a"), item("a")]).lift("a") == nil)
}

@Test func viewerLiftIsTheRestingFrameAroundTheDraggedLayer() throws {
    var model = commandProject("keyed", .live)
    #expect(model.viewerLift == nil)
    model.beginViewerDrag(at: HaloPoint(x: 960, y: 980))
    let id = try #require(model.viewerDrag?.layerID, "the press hit no layer")
    model.moveViewerDrag(to: HaloPoint(x: 1060, y: 1000))
    let lift = try #require(model.viewerLift)
    #expect(lift.layerID == id)
    // Without the drag's offset: the lift moves by the delta on screen.
    let resting = try #require(model.viewerDrawList?.offsetting(id, by: HaloPoint(x: -100, y: -20)))
    #expect(lift.below.items + lift.lifted.items + lift.above.items == resting.items)
}
