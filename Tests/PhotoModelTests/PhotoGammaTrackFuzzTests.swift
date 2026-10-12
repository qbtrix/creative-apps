// PhotoGammaTrackFuzzTests.swift: adversarial input for GammaTrack, the Levels
// gamma slider's log10 track: NaN payloads and signs, signed zero, subnormals,
// the floats either side of the ends, random bit patterns, monotonicity, equal
// travel either side of the midpoint, and the round trip through the Float that
// AdjustmentSettings stores. Runs on Linux and macOS.
import PhotoModel
import Testing

@Suite struct PhotoGammaTrackFuzzTests {
    @Test(arguments: [
        -Double.nan,
        Double.signalingNaN,
        Double(nan: 0x1234, signaling: false),
        -Double(nan: 0x1234, signaling: true),
        Double(bitPattern: 0x7FFF_FFFF_FFFF_FFFF),
        Double(bitPattern: 0xFFF0_0000_0000_0001),
    ])
    func everyNaNGivesTheIdentity(input: Double) {
        #expect(GammaTrack.gamma(atPosition: input) == 1)
        #expect(GammaTrack.position(ofGamma: input) == 0)
    }

    @Test(arguments: [
        (-0.0, 1.0),
        (Double.leastNonzeroMagnitude, 1.0),
        (-Double.leastNonzeroMagnitude, 1.0),
        ((-1.0).nextDown, 0.1),
        (1.0.nextUp, 10.0),
        (Double.greatestFiniteMagnitude, 10.0),
        (-Double.greatestFiniteMagnitude, 0.1),
        (-Double.infinity, 0.1),
    ])
    func edgePositionsMapIntoTheGammaRange(position: Double, expected: Double) {
        #expect(abs(GammaTrack.gamma(atPosition: position) - expected) <= expected * 1e-12)
    }

    @Test(arguments: [
        (-0.0, -1.0),
        (Double.leastNonzeroMagnitude, -1.0),
        (Double.leastNormalMagnitude, -1.0),
        (-Double.leastNonzeroMagnitude, -1.0),
        (0.1.nextDown, -1.0),
        (10.0.nextUp, 1.0),
        (Double.greatestFiniteMagnitude, 1.0),
        (-Double.infinity, -1.0),
    ])
    func edgeGammasMapOntoTheTrack(gamma: Double, expected: Double) {
        #expect(GammaTrack.position(ofGamma: gamma) == expected)
    }

    @Test func randomBitPatternsStayInRange() {
        var generator = SystemRandomNumberGenerator()
        for _ in 0..<10_000 {
            let input = Double(bitPattern: UInt64.random(in: .min ... .max, using: &generator))
            let gamma = GammaTrack.gamma(atPosition: input)
            let position = GammaTrack.position(ofGamma: input)
            #expect((0.1...10).contains(gamma), "input bits \(input.bitPattern)")
            #expect(GammaTrack.positionRange.contains(position), "input bits \(input.bitPattern)")
        }
    }

    @Test func bothDirectionsAreMonotonic() {
        var generator = SystemRandomNumberGenerator()
        let positions = (0..<2_000).map { _ in Double.random(in: -1.5...1.5, using: &generator) }.sorted()
        let gammas = positions.map { GammaTrack.gamma(atPosition: $0) }
        #expect(zip(gammas, gammas.dropFirst()).allSatisfy { $0 <= $1 })
        let inputs = (0..<2_000).map { _ in Double.random(in: 0.01...20, using: &generator) }.sorted()
        let back = inputs.map { GammaTrack.position(ofGamma: $0) }
        #expect(zip(back, back.dropFirst()).allSatisfy { $0 <= $1 })
    }

    @Test func mirroredPositionsGiveReciprocalGammas() {
        for step in 0...100 {
            let t = Double(step) / 100
            let product = GammaTrack.gamma(atPosition: t) * GammaTrack.gamma(atPosition: -t)
            #expect(abs(product - 1) < 1e-12, "t \(t)")
        }
    }

    @Test func aDragThroughTheStoredFloatComesBackToTheSameSpot() {
        var settings = AdjustmentSettings()
        for step in -500...500 {
            let position = Double(step) / 500
            settings.apply(.gamma(Float(GammaTrack.gamma(atPosition: position))))
            #expect(AdjustmentSettings.gammaRange.contains(settings.gamma))
            let back = GammaTrack.position(ofGamma: Double(settings.gamma))
            #expect(GammaTrack.positionRange.contains(back))
            #expect(abs(back - position) < 1e-6, "position \(position)")
        }
    }

    @Test func storedEndsSitAtTheTrackEnds() {
        var settings = AdjustmentSettings()
        settings.apply(.gamma(-5))
        #expect(abs(GammaTrack.position(ofGamma: Double(settings.gamma)) + 1) < 1e-7)
        settings.apply(.gamma(500))
        #expect(GammaTrack.position(ofGamma: Double(settings.gamma)) == 1)
        settings.apply(.gamma(1))
        #expect(GammaTrack.position(ofGamma: Double(settings.gamma)) == 0)
    }
}
