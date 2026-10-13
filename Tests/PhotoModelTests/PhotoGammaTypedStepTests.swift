// PhotoGammaTypedStepTests.swift: GammaTrack.steppedPosition from a typed
// gamma inside the midpoint detent but off 1, such as 1.05 or 0.95 (#593).
// One step goes from the typed value: toward 1 it lands on 1, away from 1 it
// leaves the band on the typed value's own grid, and it never crosses 1.
import PhotoModel
import Testing

@Suite struct PhotoGammaTypedStepTests {
    private func stepped(from gamma: Double, by delta: Double) -> Double {
        GammaTrack.snappedGamma(atPosition: GammaTrack.steppedPosition(
            from: GammaTrack.position(ofGamma: gamma), by: delta))
    }

    @Test(arguments: [1.02, 1.05, 1.09])
    func anIncrementFromJustAboveOneMovesUp(_ gamma: Double) {
        let up = stepped(from: gamma, by: GammaTrack.step)
        #expect(up > gamma)
        #expect(up < 1.13)
    }

    @Test(arguments: [1.02, 1.05, 1.09])
    func aDecrementFromJustAboveOneLandsOnOne(_ gamma: Double) {
        #expect(stepped(from: gamma, by: -GammaTrack.step) == 1)
    }

    @Test(arguments: [0.98, 0.95, 0.92])
    func aDecrementFromJustBelowOneMovesDown(_ gamma: Double) {
        let down = stepped(from: gamma, by: -GammaTrack.step)
        #expect(down < gamma)
        #expect(down > 0.88)
    }

    @Test(arguments: [0.98, 0.95, 0.92])
    func anIncrementFromJustBelowOneLandsOnOne(_ gamma: Double) {
        #expect(stepped(from: gamma, by: GammaTrack.step) == 1)
    }

    /// Leaving the band keeps the typed value's grid: whole steps from it.
    @Test func aStepAwayFromOneStaysOnTheTypedGrid() {
        let start = GammaTrack.position(ofGamma: 1.05)
        let position = GammaTrack.steppedPosition(from: start, by: GammaTrack.step)
        #expect(position > GammaTrack.detent)
        let steps = (position - start) / GammaTrack.step
        #expect(abs(steps - steps.rounded()) < 1e-9)
        #expect(position - GammaTrack.step <= GammaTrack.detent)
    }

    @Test(arguments: [0.001, -0.001, 0.01, -0.01])
    func aStepFromATypedValueNeverCrossesOne(_ delta: Double) {
        for gamma in [1.05, 0.95] {
            let result = stepped(from: gamma, by: delta)
            #expect(delta > 0 ? result >= gamma : result <= gamma)
            #expect(gamma > 1 ? result >= 1 : result <= 1)
        }
    }

    @Test func aVanishingStepStaysFiniteAndNeverMovesDown() {
        let start = GammaTrack.position(ofGamma: 1.05)
        let position = GammaTrack.steppedPosition(from: start, by: .leastNonzeroMagnitude)
        #expect(position.isFinite)
        #expect(position >= start)
    }
}
