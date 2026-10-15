// KeyEasingContractTests.swift: what every KeyEasing promises (#428), run
// over each conforming type in `keyEasings`; the live type joins by adding
// itself there. Runs on Linux and macOS.
import HaloModel
import Testing

let keyEasings: [any KeyEasing] = [FakeKeyEasing()]

@Test(arguments: keyEasings)
func easeInBendsTheCurve(easing: any KeyEasing) throws {
    var comp = keyedPair()
    let key = HaloKeyRef(layerID: "s", property: .x, frame: 0)
    try easing.setEasing(.easeIn, on: [key], in: &comp)
    #expect((FakeLayerPlacing().value(.x, of: "s", in: comp, at: 15) ?? 0) < 100)
    #expect(HaloEasingPreset(easing.easing(of: key, in: comp) ?? .linear) == .easeIn)
}

@Test(arguments: keyEasings)
func keysListEveryDiamondByPropertyThenFrame(easing: any KeyEasing) {
    let comp = keyedPair()
    #expect(easing.keys(of: "s", in: comp).map(\.frame) == [0, 30])
    #expect(easing.keys(of: "n", in: comp).isEmpty)
    #expect(easing.easing(of: HaloKeyRef(layerID: "s", property: .x, frame: 7), in: comp) == nil)
}

@Test(arguments: keyEasings)
func noSelectedKeyThrows(easing: any KeyEasing) {
    var comp = keyedPair()
    #expect(throws: HaloEditError.noKeySelected) { try easing.setEasing(.easeOut, on: [], in: &comp) }
}

@Test(arguments: keyEasings)
func aMissingKeyThrowsAndChangesNothing(easing: any KeyEasing) {
    var comp = keyedPair()
    let before = comp
    let keys: Set = [
        HaloKeyRef(layerID: "s", property: .x, frame: 0), HaloKeyRef(layerID: "s", property: .x, frame: 7),
    ]
    #expect(throws: HaloEditError.unknownLayer("s")) { try easing.setEasing(.easeOut, on: keys, in: &comp) }
    #expect(comp == before)
}
