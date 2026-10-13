// PhotoGammaDetentFuzzTests.swift: adversarial input for GammaTrack's
// midpoint detent (snappedGamma): signed zero, the floats either side of the
// band's edges, NaN payloads, infinities, monotonicity across the whole track,
// symmetry, and the round trip through the Float that AdjustmentSettings
// stores. Runs on Linux and macOS.
import PhotoModel
import Testing

@Suite struct PhotoGammaDetentFuzzTests {
    @Test(arguments: [
        -0.0,
        Double.leastNonzeroMagnitude,
        -Double.leastNonzeroMagnitude,
        GammaTrack.detent,
        -GammaTrack.detent,
        GammaTrack.detent.nextDown,
        (-GammaTrack.detent).nextUp,
    ])
    func edgesOfTheBandSnapToOne(position: Double) {
        #expect(GammaTrack.snappedGamma(atPosition: position) == 1)
    }

    @Test(arguments: [GammaTrack.detent.nextUp, (-GammaTrack.detent).nextDown])
    func justOutsideTheBandIsTheLogTrack(position: Double) {
        let gamma = GammaTrack.snappedGamma(atPosition: position)
        #expect(gamma == GammaTrack.gamma(atPosition: position))
        #expect(Float(gamma) != 1)
    }

    @Test(arguments: [
        -Double.nan,
        Double.signalingNaN,
        Double(nan: 0x1234, signaling: false),
        -Double(nan: 0x1234, signaling: true),
    ])
    func everyNaNSnapsToOne(position: Double) {
        #expect(GammaTrack.snappedGamma(atPosition: position) == 1)
    }

    @Test(arguments: [
        (Double.infinity, 10.0),
        (-Double.infinity, 0.1),
        (Double.greatestFiniteMagnitude, 10.0),
        (-Double.greatestFiniteMagnitude, 0.1),
        (1.0, 10.0),
        (-1.0, 0.1),
    ])
    func theEndsStayExact(position: Double, expected: Double) {
        #expect(GammaTrack.snappedGamma(atPosition: position) == expected)
    }

    @Test func snappingNeverRunsBackwardsAlongTheTrack() {
        var previous = GammaTrack.snappedGamma(atPosition: -1.5)
        for step in -1500...1500 {
            let gamma = GammaTrack.snappedGamma(atPosition: Double(step) / 1000)
            #expect(gamma >= previous, "step \(step)")
            previous = gamma
        }
    }

    @Test func theBandIsSymmetric() {
        for step in 0...2000 {
            let position = Double(step) / 1000
            let up = GammaTrack.snappedGamma(atPosition: position)
            let down = GammaTrack.snappedGamma(atPosition: -position)
            #expect(abs(up * down - 1) <= 1e-12, "position \(position)")
        }
    }

    /// Whatever a drag stores, the stored Float is in gammaRange, and is 1
    /// exactly when the drag ended inside the band.
    @Test func everyDragStoresAValidFloat() {
        var generator = SystemRandomNumberGenerator()
        for _ in 0..<5000 {
            let position = Double.random(in: -1.2...1.2, using: &generator)
            var settings = AdjustmentSettings()
            settings.apply(.gamma(Float(GammaTrack.snappedGamma(atPosition: position))))
            #expect(AdjustmentSettings.gammaRange.contains(settings.gamma), "position \(position)")
            #expect((settings.gamma == 1) == (abs(position) <= GammaTrack.detent), "position \(position)")
            #expect(settings.isIdentity(.levels) == (abs(position) <= GammaTrack.detent), "position \(position)")
        }
    }

    /// Dragging into the band from either side and then out again: the
    /// last position wins, and the band only ever restores the identity.
    @Test func aDragThroughTheBandEndsWhereItIsReleased() {
        var settings = AdjustmentSettings()
        var last = 0.0
        for position in stride(from: -0.5, through: 0.5, by: 0.001) {
            settings.apply(.gamma(Float(GammaTrack.snappedGamma(atPosition: position))))
            last = position
        }
        #expect(settings.gamma == Float(GammaTrack.gamma(atPosition: last)))
        for position in stride(from: last, through: 0.0, by: -0.001) {
            settings.apply(.gamma(Float(GammaTrack.snappedGamma(atPosition: position))))
        }
        #expect(settings.gamma == 1)
        #expect(settings.isIdentity(.levels))
    }

    /// Wiggling the thumb inside the band at gamma 1 records no undo step;
    /// a drag out and back is one step, and undoing it keeps gamma 1.
    @Test func wigglingInTheBandLeavesNoUndoStep() throws {
        var workspace = PhotoWorkspace()
        try workspace.newCanvas(width: 4, height: 4)
        for position in [0.019, -0.02, 0.0, 0.005, -0.0] {
            workspace.adjust(.gamma(Float(GammaTrack.snappedGamma(atPosition: position))))
        }
        #expect(!workspace.canUndo)
        for position in [0.1, 0.4, 0.2, 0.015] {
            workspace.adjust(.gamma(Float(GammaTrack.snappedGamma(atPosition: position))))
        }
        #expect(workspace.adjustments.isIdentity)
        workspace.undo()
        #expect(workspace.adjustments.gamma == 1)
        #expect(!workspace.canUndo)
    }
}
