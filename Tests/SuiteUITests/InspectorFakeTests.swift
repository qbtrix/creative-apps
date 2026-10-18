// InspectorFakeTests.swift: the six inspector Fakes (UC1 ValueScrubbing, UC2
// HexColorEditing, UC3 KeyframeFacing, UC4 PresetNavigating, UC15
// CurvePointEditing, UC15b EasingHandleNudging) give the contracts' main.swift
// results and keep the gap each one has on purpose: no snapping, no #RGB,
// presets wrap, curve points unsorted and never refused, easing x unclamped.
// The live rules' tests rely on these gaps. No SwiftUI. macOS only.
import SuiteUI
import Testing

private let spec = ScrubSpec(range: 0...360, step: 1, unit: "°")

@Test func fakeScrubbingGivesMainSwiftsResults() {
    let s = FakeValueScrubbing()
    #expect(s.dragged(from: 0, by: 40, modifiers: [], spec: spec) == 40)
    #expect(s.dragged(from: 0, by: 4, modifiers: .shift, spec: spec) == 40)
    #expect(s.dragged(from: 0, by: 10, modifiers: .option, spec: spec) == 1)
    #expect(s.committed("abc", opening: "72", old: 72, spec: spec) == 72)
    #expect(s.committed("400", opening: "72", old: 72, spec: spec) == 360)
    #expect(s.pressed(.end, from: 3, modifiers: [], spec: spec, track: nil) == 360)
    #expect(s.pressed(.home, from: 3, modifiers: [], spec: spec, track: nil) == 0)
    #expect(s.pressed(.increment, from: 3, modifiers: .shift, spec: spec, track: nil) == 13)
    #expect(s.fraction(90, spec: spec) == 0.25)
}

@Test func fakeScrubbingNeverSnapsToTheStep() {
    let s = FakeValueScrubbing()
    #expect(s.dragged(from: 0, by: 0.5, modifiers: [], spec: spec) == 0.5)
    #expect(s.committed("12.34", opening: "0", old: 0, spec: spec) == 12.34)
}

@Test func fakeHexGivesMainSwiftsResultsAndRefusesShorthand() {
    let hex = FakeHexColorEditing()
    #expect(hex.format(hex.committed("FF3B30", old: RGB8(0, 0, 0))) == "#FF3B30")
    #expect(hex.committed("zz", old: RGB8(1, 2, 3)) == RGB8(1, 2, 3))
    #expect(hex.parse("#0a0B0c") == RGB8(10, 11, 12))
    #expect(hex.format(RGB8(1, 2, 3)) == "#010203")
    #expect(hex.parse("#F00") == nil)
    #expect(hex.committed("F00", old: RGB8(1, 2, 3)) == RGB8(1, 2, 3))
}

@Test func fakeKeyframeFacesEachPresence() {
    let f = FakeKeyframeFacing()
    #expect(f.face(for: .keyedHere).spoken == "Keyed at this frame")
    #expect(f.face(for: .keyedHere).diamondAction == .remove)
    #expect(f.face(for: .animated).spoken == "Animated")
    #expect(f.face(for: .animated).diamondAction == .add)
    #expect(f.face(for: .idle).spoken == "Not animated")
    #expect(f.face(for: .idle).diamondSymbol == nil)
}

@Test func fakePresetsGiveMainSwiftsNeighbourAndWrapAtEdges() {
    let p = FakePresetNavigating()
    #expect(p.neighbor(of: 0, .right, count: 6, columns: 2) == 1)
    #expect(p.neighbor(of: 0, .down, count: 6, columns: 2) == 2)
    #expect(p.neighbor(of: 5, .right, count: 6, columns: 2) == 0)
    #expect(p.neighbor(of: 0, .left, count: 6, columns: 2) == 5)
    #expect(p.neighbor(of: 0, .up, count: 6, columns: 2) == 4)
    #expect(p.neighbor(of: 6, .right, count: 6, columns: 2) == nil)
    #expect(p.neighbor(of: 0, .right, count: 0, columns: 2) == nil)
}

@Test func fakeCurveAppendsUnsortedAndNeverRefusesRemoval() {
    let c = FakeCurvePointEditing()
    let ends = [PlanePoint(x: 0, y: 0), PlanePoint(x: 1, y: 1)]
    #expect(c.removed(0, from: [PlanePoint(x: 0, y: 0)])?.isEmpty == true)
    #expect(c.removed(0, from: ends) == [PlanePoint(x: 1, y: 1)])
    #expect(c.removed(2, from: ends) == nil)
    let added = c.added(PlanePoint(x: 0.5, y: 0.5), to: ends)
    #expect(added?.index == 2)
    #expect(added?.points == ends + [PlanePoint(x: 0.5, y: 0.5)])
    #expect(c.moved(0, to: PlanePoint(x: 2, y: 2), in: ends)[0] == PlanePoint(x: 2, y: 2))
    #expect(c.nudged(1, dx: 0, dy: -1, coarse: true, in: ends)[1] == PlanePoint(x: 1, y: 0.9))
    #expect(c.isOutOfWell(PlanePoint(x: -1, y: 5), extent: PlaneExtent(width: 180, height: 180)))
    #expect(!c.isOutOfWell(PlanePoint(x: 180, y: 0), extent: PlaneExtent(width: 180, height: 180)))
}

@Test func fakeEasingGivesMainSwiftsNudgeAndLeavesXUnclamped() {
    let e = FakeEasingHandleNudging()
    #expect(e.nudged(PlanePoint(x: 0.5, y: 1), dx: 0, dy: 1, coarse: true).y == 1.1)
    #expect(e.nudged(PlanePoint(x: 1, y: 0), dx: 1, dy: 0, coarse: true).x > 1)
    #expect(e.nudged(PlanePoint(x: 0, y: 0), dx: -1, dy: 0, coarse: false).x < 0)
    #expect(e.describe(PlanePoint(x: 0.5, y: 1)) == "0.5, 1.0")
}
