// PhotoGammaStepTests.swift: GammaTrack.steppedPosition, the discrete step an
// arrow key or VoiceOver's increment and decrement takes on the Gamma track
// (#584). One step from gamma 1 leaves the midpoint detent; a step back into
// the band from outside still gives exactly 1.
import PhotoModel
import Testing

@Suite struct PhotoGammaStepTests {
    private func stepped(from gamma: Double, by delta: Double) -> Double {
        GammaTrack.snappedGamma(atPosition: GammaTrack.steppedPosition(
            from: GammaTrack.position(ofGamma: gamma), by: delta))
    }

    @Test func oneIncrementFromOneLeavesOne() {
        let up = stepped(from: 1, by: GammaTrack.step)
        #expect(up != 1)
        #expect(up > 1.1 && up < 1.13)
    }

    @Test func oneDecrementFromOneLeavesOne() {
        let down = stepped(from: 1, by: -GammaTrack.step)
        #expect(down != 1)
        #expect(down < 0.91 && down > 0.88)
    }

    /// Option's tenth of a step also leaves the band, to just past its edge.
    @Test(arguments: [0.001, -0.001, 0.1, -0.1])
    func anyStepFromOneLeavesTheDetent(_ delta: Double) {
        let position = GammaTrack.steppedPosition(from: 0, by: delta)
        #expect(abs(position) > GammaTrack.detent)
        #expect((position > 0) == (delta > 0))
        #expect(GammaTrack.snappedGamma(atPosition: position) != 1)
    }

    @Test func aStepBackIntoTheBandGivesExactlyOne() {
        let up = stepped(from: 1, by: GammaTrack.step)
        #expect(stepped(from: up, by: -GammaTrack.step) == 1)
        let down = stepped(from: 1, by: -GammaTrack.step)
        #expect(stepped(from: down, by: GammaTrack.step) == 1)
    }

    @Test func stepsOutsideTheBandMoveOneStep() {
        #expect(GammaTrack.steppedPosition(from: 0.5, by: GammaTrack.step) == 0.5 + GammaTrack.step)
        #expect(GammaTrack.steppedPosition(from: -0.5, by: -GammaTrack.step) == -0.5 - GammaTrack.step)
    }

    @Test func stepsClampToTheTrack() {
        #expect(GammaTrack.steppedPosition(from: 1, by: GammaTrack.step) == 1)
        #expect(GammaTrack.steppedPosition(from: -1, by: -GammaTrack.step) == -1)
        #expect(GammaTrack.steppedPosition(from: 0, by: 5) == 1)
    }

    @Test(arguments: [Double.nan, 0, .infinity, -.infinity])
    func degenerateStepsStayPut(_ delta: Double) {
        #expect(GammaTrack.steppedPosition(from: 0.3, by: delta) == 0.3)
        #expect(GammaTrack.steppedPosition(from: .nan, by: delta) == 0)
    }

    @Test func aKeyedStepFromOneChangesTheSettings() {
        var settings = AdjustmentSettings()
        settings.apply(.gamma(Float(stepped(from: Double(settings.gamma), by: GammaTrack.step))))
        #expect(!settings.isIdentity(.levels))
    }
}
