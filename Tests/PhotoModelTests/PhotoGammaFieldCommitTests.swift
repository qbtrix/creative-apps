// PhotoGammaFieldCommitTests.swift: the Levels Gamma field's commit
// (AdjustmentEdit.gammaField). A click and click away, or Return, re-sends the
// field's own text, gamma rounded to gammaDecimals; that keeps gamma
// bit-exact and records no undo step. A typed value that differs is one
// "Levels" step, as before (#463).
import PhotoModel
import Testing

@Suite struct PhotoGammaFieldCommitTests {
    /// Gamma as the field shows it: rounded to gammaDecimals, halves away from zero.
    private func shown(_ gamma: Float) -> Double {
        var scale = 1.0
        for _ in 0..<AdjustmentSettings.gammaDecimals { scale *= 10 }
        return (Double(gamma) * scale).rounded() / scale
    }

    /// An open image with gamma set from the slider at `position`, then an
    /// Exposure edit, so a later Levels edit can't coalesce into the drag.
    private func slidGamma(at position: Double) throws -> PhotoWorkspace {
        var workspace = try whiteImage(8, 8)
        workspace.adjust(.gamma(Float(GammaTrack.snappedGamma(atPosition: position))))
        workspace.adjust(.exposure(1))
        return workspace
    }

    @Test func committingTheShownTextKeepsGammaAndRecordsNothing() throws {
        var workspace = try slidGamma(at: 0.0915)
        let before = workspace
        #expect(workspace.adjustments.gamma == 1.2345253)
        workspace.adjust(.gammaField(1.23))
        #expect(workspace.adjustments.gamma.bitPattern == before.adjustments.gamma.bitPattern)
        #expect(workspace == before)
        #expect(workspace.undoActionName == "Undo Exposure")
    }

    @Test(arguments: [-1, -0.73, -0.4, -0.05, 0.0915, 0.13, 0.37, 0.5, 0.81, 1])
    func anyTrackPositionSurvivesItsOwnShownText(_ position: Double) throws {
        var workspace = try slidGamma(at: position)
        let before = workspace
        workspace.adjust(.gammaField(shown(workspace.adjustments.gamma)))
        #expect(workspace == before)
    }

    @Test func aTypedChangeIsOneLevelsStep() throws {
        var workspace = try slidGamma(at: 0.0915)
        let slid = workspace.adjustments.gamma
        workspace.adjust(.gammaField(1.5))
        #expect(workspace.adjustments.gamma == 1.5)
        #expect(workspace.undoActionName == "Undo Levels")
        workspace.undo()
        #expect(workspace.adjustments.gamma.bitPattern == slid.bitPattern)
        #expect(workspace.undoActionName == "Undo Exposure")
    }

    @Test func aTypedValueOneHundredthAwayStillCommits() {
        var settings = AdjustmentSettings()
        settings.apply(.gamma(1.2345253))
        settings.apply(.gammaField(1.24))
        #expect(settings.gamma == 1.24)
        settings.apply(.gammaField(1.22))
        #expect(settings.gamma == 1.22)
    }

    @Test func outOfRangeAndNaNCommitsClampOrKeepGamma() {
        var settings = AdjustmentSettings()
        settings.apply(.gammaField(.nan))
        #expect(settings.gamma == 1)
        settings.apply(.gammaField(50))
        #expect(settings.gamma == AdjustmentSettings.gammaRange.upperBound)
        settings.apply(.gammaField(10))
        #expect(settings.gamma == AdjustmentSettings.gammaRange.upperBound)
    }
}
