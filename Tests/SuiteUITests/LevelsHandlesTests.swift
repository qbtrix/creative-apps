// LevelsHandlesTests.swift: LevelsHandles' handle math (#3633): where each
// handle sits on its ramp, the value a drag to a spot asks for (the midtone
// as the gamma that puts it there), and the readings its handles speak.
// Pure statics, no window. macOS only.
import SuiteModel
import SuiteUI
import Testing

private let values = LevelsValues(inBlack: 0.2, gamma: 1, inWhite: 0.6, outBlack: 0.1, outWhite: 0.9)

@Test func handlesSitAtTheirValuesAndTheMidtoneBetweenThePoints() {
    #expect(LevelsHandles.position(.inBlack, values) == 0.2)
    #expect(LevelsHandles.position(.outWhite, values) == 0.9)
    #expect(abs(LevelsHandles.position(.gamma, values) - 0.4) < 1e-12)
    #expect(LevelsHandles.position(.outBlack, LevelsValues(inBlack: 0, gamma: 1, inWhite: 1)) == 0)
}

@Test func aDragAsksForThePointUnderItOrTheGammaThatPutsTheMidtoneThere() {
    #expect(LevelsHandles.value(.inWhite, at: 0.75, values, gammaRange: 0.1...9.99) == 0.75)
    #expect(LevelsHandles.value(.inBlack, at: -3, values, gammaRange: 0.1...9.99) == 0)
    #expect(LevelsHandles.value(.outWhite, at: .nan, values, gammaRange: 0.1...9.99) == 0)
    let gamma = LevelsHandles.value(.gamma, at: 0.3, values, gammaRange: 0.1...9.99)
    #expect(abs(gamma - 2) < 1e-9)  // a quarter of the way from 0.2 to 0.6 is 0.5^2
}

@Test func handlesReadAsLevelsAndGammaToTwoPlaces() {
    #expect(LevelsHandles.reading(.inBlack, values) == "51")
    #expect(LevelsHandles.reading(.inWhite, values) == "153")
    #expect(LevelsHandles.reading(.gamma, LevelsValues(inBlack: 0, gamma: 1.2, inWhite: 1)) == "1.20")
    #expect(LevelsHandles.reading(.gamma, values) == "1.00")
}
