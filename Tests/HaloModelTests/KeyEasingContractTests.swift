// KeyEasingContractTests.swift: what every KeyEasing promises (#428, packet
// EZ-1), run over the fake and the live type, which share HaloEasingRules, on
// the `keyed` fixture (Ball: x 160 at 0 and 960 at 24, opacity 0 at 0 and 1
// at 12). Runs on Linux and macOS.
import HaloModel
import Testing

let keyEasings: [any KeyEasing] = [FakeKeyEasing(), LiveKeyEasing()]

/// The `keyed` fixture's composition and Ball's id, looked up by name.
private func keyedBall() throws -> (comp: HaloComposition, ball: String) {
    let comp = try #require(HaloFixtures.project("keyed")?.compositions.first)
    return (comp, try #require(comp.layers.first { $0.name == "Ball" }).id)
}

@Test(arguments: keyEasings)
func keysListEveryDiamondByPropertyThenFrame(easing: any KeyEasing) throws {
    let (comp, ball) = try keyedBall()
    let keys = easing.keys(of: ball, in: comp)
    #expect(keys.map(\.property) == [.x, .x, .opacity, .opacity])
    #expect(keys.map(\.frame) == [0, 24, 0, 12])
    #expect(keys.allSatisfy { $0.layerID == ball })
    #expect(easing.keys(of: "gone", in: comp).isEmpty)
    #expect(easing.easing(of: HaloKeyRef(layerID: ball, property: .x, frame: 7), in: comp) == nil)
}

@Test(arguments: keyEasings)
func easeInBendsPositionX(easing: any KeyEasing) throws {
    let (start, ball) = try keyedBall()
    var comp = start
    let x0 = HaloKeyRef(layerID: ball, property: .x, frame: 0)
    #expect(easing.easing(of: x0, in: comp) == .linear)
    try easing.setEasing(.easeIn, on: [x0], in: &comp)
    #expect(easing.easing(of: x0, in: comp) == .easeIn)
    #expect(easing.easing(of: HaloKeyRef(layerID: ball, property: .opacity, frame: 0), in: comp) == .linear)
    #expect((LiveLayerPlacing().value(.x, of: ball, in: comp, at: 12) ?? 560) < 560)
}

@Test(arguments: keyEasings)
func noSelectedKeyThrows(easing: any KeyEasing) throws {
    var comp = try keyedBall().comp
    #expect(throws: HaloEditError.noKeySelected) { try easing.setEasing(.easeOut, on: [], in: &comp) }
}

@Test(arguments: keyEasings)
func aMissingKeyThrowsAndChangesNothing(easing: any KeyEasing) throws {
    let (start, ball) = try keyedBall()
    var comp = start
    let before = comp
    let keys: Set = [
        HaloKeyRef(layerID: ball, property: .x, frame: 0), HaloKeyRef(layerID: ball, property: .x, frame: 7),
    ]
    #expect(throws: HaloEditError.unknownLayer(ball)) { try easing.setEasing(.easeOut, on: keys, in: &comp) }
    #expect(comp == before)
}

@Test(arguments: keyEasings)
func aCustomCurveClampsHandleXAndKeepsY(easing: any KeyEasing) throws {
    let (start, ball) = try keyedBall()
    var comp = start
    let x0 = HaloKeyRef(layerID: ball, property: .x, frame: 0)
    try easing.setEasing(.cubicBezier(x1: 1.4, y1: 0, x2: 0.58, y2: 1), on: [x0], in: &comp)
    #expect(easing.easing(of: x0, in: comp) == .cubicBezier(x1: 1.0, y1: 0, x2: 0.58, y2: 1))
    try easing.setEasing(.cubicBezier(x1: 0.2, y1: -0.5, x2: -3, y2: 1.6), on: [x0], in: &comp)
    #expect(easing.easing(of: x0, in: comp) == .cubicBezier(x1: 0.2, y1: -0.5, x2: 0, y2: 1.6))
}

@Test(arguments: keyEasings)
func aNonFiniteCurveThrowsAndChangesNothing(easing: any KeyEasing) throws {
    let (start, ball) = try keyedBall()
    var comp = start
    let before = comp
    let keys: Set = [
        HaloKeyRef(layerID: ball, property: .x, frame: 0), HaloKeyRef(layerID: ball, property: .opacity, frame: 0),
    ]
    #expect(throws: HaloEditError.notANumber(.x)) {
        try easing.setEasing(.cubicBezier(x1: .nan, y1: 0, x2: 0.58, y2: 1), on: keys, in: &comp)
    }
    #expect(throws: HaloEditError.notANumber(.x)) {
        try easing.setEasing(.cubicBezier(x1: 0.42, y1: 0, x2: 0.58, y2: .infinity), on: keys, in: &comp)
    }
    #expect(comp == before)
}

@Test func liveKeyEasingIsBuilt() {
    #expect(LiveKeyEasing().unavailableHelp == nil)
}
