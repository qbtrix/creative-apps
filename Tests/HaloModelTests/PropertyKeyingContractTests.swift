// PropertyKeyingContractTests.swift: what every PropertyKeying promises
// (#38), run over each conforming type in `propertyKeyings`; the live type
// joins by adding itself there. Positions are measured with
// FakeLayerPlacing, which the live keying must agree with. Runs on Linux and
// macOS.
import HaloModel
import Testing

let propertyKeyings: [any PropertyKeying] = [FakePropertyKeying()]

@Test(arguments: propertyKeyings)
func rowsFollowPropertyOrderAndKeyState(keying: any PropertyKeying) {
    let comp = keyedPair()
    let rows = keying.rows(for: "s", in: comp, at: 30)
    #expect(rows.map(\.property) == HaloProperty.allCases)
    #expect(rows.first?.keyState == .keyedHere)
    #expect(keying.rows(for: "s", in: comp, at: 15).first?.keyState == .animated)
    #expect(rows.last?.keyState == .notAnimated)
    #expect(keying.rows(for: "gone", in: comp, at: 0).isEmpty)
}

@Test(arguments: propertyKeyings)
func parentingFollowsAndRefusesCycles(keying: any PropertyKeying) throws {
    var comp = keyedPair()
    let placing = FakeLayerPlacing()
    let before = placing.worldMatrix(of: "s", in: comp, at: 0)?.apply(HaloPoint(x: 50, y: 50))
    try keying.setParent("n", of: "s", at: 0, in: &comp)
    #expect(placing.worldMatrix(of: "s", in: comp, at: 0)?.apply(HaloPoint(x: 50, y: 50)) == before)
    #expect(placing.parentCandidates(for: "n", in: comp).isEmpty)
    #expect(throws: HaloEditError.parentCycle("Null 1")) { try keying.setParent("s", of: "n", at: 0, in: &comp) }
    try keying.setValue(300, for: .x, of: "n", at: 0, in: &comp)
    #expect(placing.worldMatrix(of: "s", in: comp, at: 0)?.apply(HaloPoint(x: 50, y: 50)).x == (before?.x ?? 0) + 100)
}

@Test(arguments: propertyKeyings)
func opacityHasOneStaticHome(keying: any PropertyKeying) throws {
    var comp = keyedPair()
    try keying.setValue(0.5, for: .opacity, of: "s", at: 10, in: &comp)
    #expect(comp.layers[1].opacity == 0.5 && comp.layers[1].tracks["opacity"] == nil)
    try keying.toggleAnimation(.opacity, of: "s", at: 10, in: &comp)
    #expect(comp.layers[1].tracks["opacity"]?.map(\.frame) == [10, 59])
    try keying.toggleAnimation(.opacity, of: "s", at: 10, in: &comp)
    #expect(comp.layers[1].opacity == 0.5 && comp.layers[1].tracks["opacity"] == nil)
}

@Test(arguments: propertyKeyings)
func stopwatchOnKeysThePlayheadAndTheLastFrame(keying: any PropertyKeying) throws {
    var comp = keyedPair()
    try keying.toggleAnimation(.rotation, of: "s", at: 12, in: &comp)
    #expect(comp.layers[1].tracks["rotation"]?.map(\.frame) == [12, 59])
    try keying.toggleAnimation(.y, of: "s", at: 59, in: &comp)
    #expect(comp.layers[1].tracks["y"]?.map(\.frame) == [0, 59])
    #expect(keying.rows(for: "s", in: comp, at: 12).first { $0.property == .rotation }?.keyState == .keyedHere)
}

@Test(arguments: propertyKeyings)
func aValueThatIsNotANumberThrowsAndChangesNothing(keying: any PropertyKeying) {
    var comp = keyedPair()
    let before = comp
    #expect(throws: HaloEditError.notANumber(.rotation)) {
        try keying.setValue(.nan, for: .rotation, of: "s", at: 0, in: &comp)
    }
    #expect(throws: HaloEditError.notANumber(.x)) { try keying.setValue(.infinity, for: .x, of: "s", at: 15, in: &comp) }
    #expect(comp == before)
}
