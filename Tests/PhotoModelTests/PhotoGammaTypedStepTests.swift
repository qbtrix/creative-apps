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

/// A coarse (Shift-sized) step from a typed in-band gamma toward 1 stops at 1
/// instead of ending past the band on the far side (#597).
@Suite struct PhotoGammaTypedCoarseStepTests {
    private func stepped(from gamma: Double, by delta: Double) -> Double {
        GammaTrack.snappedGamma(atPosition: GammaTrack.steppedPosition(
            from: GammaTrack.position(ofGamma: gamma), by: delta))
    }

    @Test func aShiftDecrementFromJustAboveOneStopsAtOne() {
        #expect(stepped(from: 1.05, by: -10 * GammaTrack.step) == 1)
        #expect(stepped(from: 1.09, by: -0.08) == 1)
    }

    @Test func aShiftIncrementFromJustBelowOneStopsAtOne() {
        #expect(stepped(from: 0.95, by: 10 * GammaTrack.step) == 1)
        #expect(stepped(from: 0.92, by: 0.08) == 1)
    }

    @Test(arguments: [0.1, -0.1, 0.5, -0.5, 2, -2])
    func aCoarseStepFromATypedValueNeverCrossesOne(_ delta: Double) {
        for gamma in [1.05, 0.95] {
            let result = stepped(from: gamma, by: delta)
            #expect(delta > 0 ? result >= gamma : result <= gamma)
            #expect(gamma > 1 ? result >= 1 : result <= 1)
        }
    }

    @Test func aShiftStepAwayFromOneStillLeavesTheBand() {
        #expect(stepped(from: 1.05, by: 10 * GammaTrack.step) > 1.1)
        #expect(stepped(from: 0.95, by: -10 * GammaTrack.step) < 0.91)
    }
}

/// A Shift-sized step toward 1 from just outside the band (1.11, 0.9) stops
/// at 1 instead of crossing it to the far side (#618).
@Suite struct PhotoGammaOutsideBandCoarseStepTests {
    private func stepped(from gamma: Double, by delta: Double) -> Double {
        GammaTrack.snappedGamma(atPosition: GammaTrack.steppedPosition(
            from: GammaTrack.position(ofGamma: gamma), by: delta))
    }

    @Test(arguments: [1.10, 1.11, 1.12])
    func aShiftDecrementFromJustAboveTheBandStopsAtOne(_ gamma: Double) {
        #expect(stepped(from: gamma, by: -10 * GammaTrack.step) == 1)
    }

    @Test(arguments: [0.91, 0.90])
    func aShiftIncrementFromJustBelowTheBandStopsAtOne(_ gamma: Double) {
        #expect(stepped(from: gamma, by: 10 * GammaTrack.step) == 1)
    }

    @Test func aStepRightThenShiftLeftReturnsToOne() {
        let right = GammaTrack.steppedPosition(from: 0, by: GammaTrack.step)
        let back = GammaTrack.steppedPosition(from: right, by: -10 * GammaTrack.step)
        #expect(back == 0)
    }

    @Test func aStepThatStopsShortOfOneStillMovesOneStep() {
        #expect(GammaTrack.steppedPosition(from: 0.5, by: -0.1) == 0.5 - 0.1)
        #expect(GammaTrack.steppedPosition(from: -0.5, by: 0.1) == -0.5 + 0.1)
    }

    @Test func aShiftStepFromOneStillLeavesTheDetent() {
        #expect(stepped(from: 1, by: 10 * GammaTrack.step) > 1.1)
        #expect(stepped(from: 1, by: -10 * GammaTrack.step) < 0.91)
    }
}
