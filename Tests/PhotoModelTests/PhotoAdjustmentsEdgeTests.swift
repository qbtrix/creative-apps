// PhotoAdjustmentsEdgeTests.swift: edge cases and a seeded fuzz run for
// Photo's adjustment settings: infinities, values right at the range edges,
// black and white one step apart, out-of-range levels that clamp onto the
// other point, switches that never touch values, and long random edit runs
// that must keep every value in range. Runs on Linux and macOS.
import PhotoModel
import Testing

/// A small deterministic generator so fuzz failures replay.
private struct SeededRandom: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// Every value in range, finite, and black below white.
private func checkInvariants(_ settings: AdjustmentSettings) {
    #expect(AdjustmentSettings.exposureRange.contains(settings.exposure))
    #expect(AdjustmentSettings.levelsRange.contains(settings.blackPoint))
    #expect(AdjustmentSettings.levelsRange.contains(settings.whitePoint))
    #expect(settings.blackPoint < settings.whitePoint)
    #expect(AdjustmentSettings.gammaRange.contains(settings.gamma))
    #expect(AdjustmentSettings.sigmaRange.contains(settings.blurSigma))
    #expect(AdjustmentSettings.hueRange.contains(settings.hue))
    #expect(AdjustmentSettings.percentRange.contains(settings.saturation))
    #expect(AdjustmentSettings.percentRange.contains(settings.lightness))
}

@Suite struct PhotoAdjustmentsEdgeTests {
    @Test func infinitiesClampToTheRangeEnds() {
        var settings = AdjustmentSettings()
        settings.apply(.exposure(.infinity))
        settings.apply(.gamma(-.infinity))
        settings.apply(.blurSigma(.infinity))
        settings.apply(.hue(-.infinity))
        settings.apply(.saturation(.infinity))
        settings.apply(.lightness(-.infinity))
        #expect(settings.exposure == 5)
        #expect(settings.gamma == 0.1)
        #expect(settings.blurSigma == 20)
        #expect(settings.hue == -180)
        #expect(settings.saturation == 100)
        #expect(settings.lightness == -100)
        checkInvariants(settings)
    }

    @Test func nanIsIgnoredForEveryValue() {
        var settings = AdjustmentSettings()
        let before = settings
        for edit: AdjustmentEdit in [
            .exposure(.nan), .blackPoint(.nan), .whitePoint(.nan), .gamma(.nan),
            .blurSigma(.nan), .hue(.nan), .saturation(.nan), .lightness(.nan),
            .exposure(.signalingNaN), .blurSigma(.signalingNaN),
        ] {
            settings.apply(edit)
        }
        #expect(settings == before)
    }

    @Test func rangeEdgesAreAccepted() {
        var settings = AdjustmentSettings()
        settings.apply(.exposure(-5))
        settings.apply(.gamma(10))
        settings.apply(.blurSigma(20))
        settings.apply(.hue(180))
        #expect(settings.exposure == -5 && settings.gamma == 10)
        #expect(settings.blurSigma == 20 && settings.hue == 180)
    }

    @Test func negativeZeroStillCountsAsIdentity() {
        var settings = AdjustmentSettings()
        settings.apply(.exposure(-0.0))
        settings.apply(.hue(-0.0))
        settings.apply(.blurSigma(-0.0))
        #expect(settings.isIdentity)
    }

    @Test func blackAndWhiteMayBeOneStepApart() {
        var settings = AdjustmentSettings()
        let step = Float(AdjustmentSettings.levelsStep)
        settings.apply(.whitePoint(0.5))
        // One Float step below white snaps onto white: refused.
        settings.apply(.blackPoint(Float(0.5).nextDown))
        #expect(settings.blackPoint == 0)
        settings.apply(.blackPoint(0.5 - step))
        #expect(settings.blackPoint == 0.5 - step)
        settings.apply(.whitePoint(settings.blackPoint))
        #expect(settings.whitePoint == 0.5)
        checkInvariants(settings)
    }

    @Test func outOfRangeLevelsThatClampOntoTheOtherPointAreRefused() {
        var settings = AdjustmentSettings()
        settings.apply(.blackPoint(0.3))
        settings.apply(.whitePoint(0.7))
        // 5 clamps to 1, above black: accepted as 1.
        settings.apply(.whitePoint(5))
        #expect(settings.whitePoint == 1)
        // -3 clamps to 0, below white: accepted as 0.
        settings.apply(.blackPoint(-3))
        #expect(settings.blackPoint == 0)
        // With white at 0.2, a black of 9 clamps to 1, at or above white: refused.
        settings.apply(.whitePoint(0.2))
        settings.apply(.blackPoint(9))
        #expect(settings.blackPoint == 0)
        checkInvariants(settings)
    }

    @Test func switchesNeverTouchValues() {
        var settings = AdjustmentSettings()
        settings.apply(.exposure(2))
        settings.apply(.gamma(3))
        settings.apply(.blurSigma(4))
        settings.apply(.hue(5))
        for kind in AdjustmentKind.allCases {
            settings.apply(.setEnabled(kind, false))
            settings.apply(.setEnabled(kind, false))
        }
        #expect(settings.exposure == 2 && settings.gamma == 3 && settings.blurSigma == 4 && settings.hue == 5)
        #expect(settings.isIdentity)
        #expect(!settings.isIdentity(.exposure))
        for kind in AdjustmentKind.allCases { settings.apply(.setEnabled(kind, true)) }
        #expect(!settings.isIdentity)
    }

    @Test func resetIsIdempotentAndLeavesOtherSections() {
        var settings = AdjustmentSettings()
        settings.apply(.exposure(1))
        settings.apply(.blurSigma(12))
        settings.apply(.saturation(-40))
        settings.apply(.reset(.blur))
        let once = settings
        settings.apply(.reset(.blur))
        #expect(settings == once)
        #expect(settings.blurSigma == 0)
        #expect(settings.exposure == 1 && settings.saturation == -40)
    }

    @Test func resettingEverySectionGivesTheDefaults() {
        var settings = AdjustmentSettings()
        settings.apply(.exposure(-3))
        settings.apply(.blackPoint(0.2))
        settings.apply(.whitePoint(0.4))
        settings.apply(.gamma(0.5))
        settings.apply(.blurSigma(1))
        settings.apply(.hue(-90))
        settings.apply(.saturation(10))
        settings.apply(.lightness(10))
        for kind in AdjustmentKind.allCases { settings.apply(.reset(kind)) }
        #expect(settings == AdjustmentSettings())
    }

    @Test(arguments: [1, 7, 42, 2026])
    func randomEditRunsKeepEveryValueInRange(seed: UInt64) {
        var random = SeededRandom(state: seed)
        var settings = AdjustmentSettings()
        let odd: [Double] = [.nan, .infinity, -.infinity, -0.0, 1e300, -1e300, .ulpOfOne]
        for _ in 0..<1000 {
            let number =
                Bool.random(using: &random)
                ? Double.random(in: -400...400, using: &random)
                : (odd.randomElement(using: &random) ?? 0)
            let kind = AdjustmentKind.allCases.randomElement(using: &random) ?? .exposure
            let edit: AdjustmentEdit =
                switch Int.random(in: 0..<10, using: &random) {
                case 0: .exposure(Float(number))
                case 1: .blackPoint(Float(number / 400))
                case 2: .whitePoint(Float(number / 400))
                case 3: .gamma(Float(number))
                case 4: .blurSigma(number)
                case 5: .hue(number)
                case 6: .saturation(number)
                case 7: .lightness(number)
                case 8: .setEnabled(kind, Bool.random(using: &random))
                default: .reset(kind)
                }
            let before = settings
            settings.apply(edit)
            checkInvariants(settings)
            if case .setEnabled = edit {
                #expect(settings.exposure == before.exposure && settings.hue == before.hue)
            }
        }
    }

    @Test func workspaceAdjustmentsSurviveLayerEdits() throws {
        var workspace = PhotoWorkspace()
        try workspace.newCanvas(width: 2, height: 2)
        workspace.adjust(.exposure(1.5))
        workspace.addLayer()
        workspace.selectTool(.move)
        #expect(workspace.adjustments.exposure == 1.5)
        #expect(throws: (any Error).self) { try workspace.newCanvas(width: 0, height: 0) }
        #expect(workspace.adjustments.exposure == 1.5)
    }
}
