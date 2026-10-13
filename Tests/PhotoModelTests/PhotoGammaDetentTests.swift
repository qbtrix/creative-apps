// PhotoGammaDetentTests.swift: GammaTrack.snappedGamma, the slider's drag
// mapping. A drag that ends near the midpoint gives exactly gamma 1, so
// Levels is back at its identity; outside the detent it is the log track.
import PhotoModel
import Testing

@Suite struct PhotoGammaDetentTests {
    @Test(arguments: [0, 0.001, -0.001, 0.01, -0.015, 0.02, -0.02])
    func positionsInTheDetentGiveExactlyOne(_ position: Double) {
        #expect(GammaTrack.snappedGamma(atPosition: position) == 1)
    }

    @Test(arguments: [0.021, -0.021, 0.05, -0.3, 0.6, -1, 1, 3, -3])
    func positionsOutsideTheDetentKeepTheLogTrack(_ position: Double) {
        #expect(GammaTrack.snappedGamma(atPosition: position) == GammaTrack.gamma(atPosition: position))
        #expect(GammaTrack.snappedGamma(atPosition: position) != 1)
    }

    @Test func nanGivesTheIdentity() {
        #expect(GammaTrack.snappedGamma(atPosition: .nan) == 1)
    }

    @Test func dragBackToTheMiddleUndoesTheGammaEdit() {
        var settings = AdjustmentSettings()
        settings.apply(.gamma(Float(GammaTrack.snappedGamma(atPosition: -0.4))))
        #expect(!settings.isIdentity(.levels))
        settings.apply(.gamma(Float(GammaTrack.snappedGamma(atPosition: 0.012))))
        #expect(settings.gamma == 1)
        #expect(settings.isIdentity(.levels))
    }
}
