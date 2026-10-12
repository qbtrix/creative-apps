// PhotoGammaTrackTests.swift: GammaTrack, the log10 mapping between the Levels
// gamma slider's track and gamma: endpoints, the identity at the midpoint, the
// round trip and clamping. Runs on Linux and macOS.
import PhotoModel
import Testing

@Suite struct PhotoGammaTrackTests {
    @Test func endpointsMapToTheGammaRange() {
        #expect(GammaTrack.positionRange == -1...1)
        #expect(GammaTrack.gamma(atPosition: -1) == 0.1)
        #expect(GammaTrack.gamma(atPosition: 1) == 10)
        #expect(GammaTrack.position(ofGamma: 0.1) == -1)
        #expect(GammaTrack.position(ofGamma: 10) == 1)
        #expect(Float(GammaTrack.gamma(atPosition: -1)) == AdjustmentSettings.gammaRange.lowerBound)
        #expect(Float(GammaTrack.gamma(atPosition: 1)) == AdjustmentSettings.gammaRange.upperBound)
    }

    @Test func identitySitsAtTheMidpoint() {
        #expect(GammaTrack.position(ofGamma: 1) == 0)
        #expect(GammaTrack.gamma(atPosition: 0) == 1)
        #expect(GammaTrack.position(ofGamma: Double(AdjustmentSettings().gamma)) == 0)
    }

    @Test func halfwayEachSideIsTheSquareRootOfTen() {
        #expect(abs(GammaTrack.gamma(atPosition: 0.5) - 3.1622776601683795) < 1e-12)
        #expect(abs(GammaTrack.gamma(atPosition: -0.5) - 0.31622776601683794) < 1e-12)
        #expect(abs(GammaTrack.position(ofGamma: 2) - 0.3010299956639812) < 1e-12)
    }

    @Test(arguments: [-1, -0.75, -0.3, 0, 0.01, 0.25, 0.6, 0.999, 1])
    func positionRoundTrips(_ position: Double) {
        let back = GammaTrack.position(ofGamma: GammaTrack.gamma(atPosition: position))
        #expect(abs(back - position) < 1e-12)
    }

    @Test(arguments: [0.1, 0.15, 0.5, 1, 1.8, 2.2, 5, 9.99, 10])
    func gammaRoundTrips(_ gamma: Double) {
        let back = GammaTrack.gamma(atPosition: GammaTrack.position(ofGamma: gamma))
        #expect(abs(back - gamma) <= gamma * 1e-12)
    }

    @Test func outOfRangeInputClamps() {
        #expect(GammaTrack.gamma(atPosition: -3) == 0.1)
        #expect(GammaTrack.gamma(atPosition: 2.5) == 10)
        #expect(GammaTrack.gamma(atPosition: .infinity) == 10)
        #expect(GammaTrack.position(ofGamma: 0.01) == -1)
        #expect(GammaTrack.position(ofGamma: 250) == 1)
        #expect(GammaTrack.position(ofGamma: 0) == -1)
        #expect(GammaTrack.position(ofGamma: -4) == -1)
        #expect(GammaTrack.position(ofGamma: .infinity) == 1)
    }

    @Test func nanGivesTheIdentity() {
        #expect(GammaTrack.gamma(atPosition: .nan) == 1)
        #expect(GammaTrack.position(ofGamma: .nan) == 0)
    }

    @Test func aTrackEditStoresGammaWithinItsRange() {
        var settings = AdjustmentSettings()
        settings.apply(.gamma(Float(GammaTrack.gamma(atPosition: -1))))
        #expect(settings.gamma == 0.1)
        settings.apply(.gamma(Float(GammaTrack.gamma(atPosition: 0.5))))
        #expect(abs(settings.gamma - 3.1622777) < 1e-6)
        #expect(abs(GammaTrack.position(ofGamma: Double(settings.gamma)) - 0.5) < 1e-6)
    }
}
