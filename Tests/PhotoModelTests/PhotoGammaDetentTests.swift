// PhotoGammaDetentTests.swift: GammaTrack.snappedGamma, the slider's drag
// mapping. A drag that ends near the midpoint gives exactly gamma 1, so
// Levels is back at its identity; outside the detent it is the log track.
import PhotoModel
import Testing

@Suite struct PhotoGammaDetentTests {
    @Test(arguments: [0, 0.001, -0.001, 0.01, -0.015, 0.02, -0.02, 0.03, -0.04, 0.04])
    func positionsInTheDetentGiveExactlyOne(_ position: Double) {
        #expect(GammaTrack.snappedGamma(atPosition: position) == 1)
    }

    @Test(arguments: [0.041, -0.041, 0.05, -0.05, -0.3, 0.6, -1, 1, 3, -3])
    func positionsOutsideTheDetentKeepTheLogTrack(_ position: Double) {
        #expect(GammaTrack.snappedGamma(atPosition: position) == GammaTrack.gamma(atPosition: position))
        #expect(GammaTrack.snappedGamma(atPosition: position) != 1)
    }

    /// #231: the band is detentPoints of drag either side of the centre, so a
    /// release a few points off the middle (one step per point) is exactly 1,
    /// and one point past the band is the log track again.
    @Test(arguments: [1.0, 2, 3, 4])
    func aReleaseAFewPointsFromTheCentreSnaps(_ points: Double) {
        #expect(GammaTrack.detentPoints == 4)
        #expect(GammaTrack.snappedGamma(atPosition: points * GammaTrack.step) == 1)
        #expect(GammaTrack.snappedGamma(atPosition: -points * GammaTrack.step) == 1)
    }

    @Test(arguments: [5.0, 6, 10])
    func aReleaseJustPastTheBandKeepsTheLogTrack(_ points: Double) {
        let right = GammaTrack.snappedGamma(atPosition: points * GammaTrack.step)
        let left = GammaTrack.snappedGamma(atPosition: -points * GammaTrack.step)
        #expect(right > 1.1 && right == GammaTrack.gamma(atPosition: points * GammaTrack.step))
        #expect(left < 0.9 && left == GammaTrack.gamma(atPosition: -points * GammaTrack.step))
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
