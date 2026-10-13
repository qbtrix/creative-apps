// PhotoAdjustmentsTests.swift: AdjustmentSettings and PhotoWorkspace.adjust:
// clamping, the black-below-white rule, enable switches, reset and identity.
// Runs on Linux and macOS.
import PhotoModel
import Testing

@Suite struct PhotoAdjustmentsTests {
    @Test func defaultsAreIdentity() {
        let settings = AdjustmentSettings()
        #expect(settings.exposure == 0)
        #expect(settings.blackPoint == 0 && settings.whitePoint == 1 && settings.gamma == 1)
        #expect(settings.blurSigma == 0)
        #expect(settings.hue == 0 && settings.saturation == 0 && settings.lightness == 0)
        #expect(AdjustmentKind.allCases.allSatisfy(settings.isEnabled))
        #expect(settings.isIdentity)
    }

    @Test func eachValueClampsToItsRange() {
        var settings = AdjustmentSettings()
        settings.apply(.exposure(7))
        settings.apply(.gamma(0.01))
        settings.apply(.blurSigma(250))
        settings.apply(.hue(-200))
        settings.apply(.saturation(150))
        settings.apply(.lightness(-101))
        #expect(settings.exposure == 5)
        #expect(settings.gamma == 0.1)
        #expect(settings.blurSigma == 20)
        #expect(settings.hue == -180)
        #expect(settings.saturation == 100)
        #expect(settings.lightness == -100)
        settings.apply(.gamma(12))
        settings.apply(.exposure(-9))
        #expect(settings.gamma == 10)
        #expect(settings.exposure == -5)
    }

    @Test func levelsClampToZeroThroughOne() {
        var settings = AdjustmentSettings()
        settings.apply(.whitePoint(1.5))
        settings.apply(.blackPoint(-0.2))
        #expect(settings.whitePoint == 1)
        #expect(settings.blackPoint == 0)
    }

    @Test func blackAtOrAboveWhiteIsRefused() {
        var settings = AdjustmentSettings()
        settings.apply(.whitePoint(0.6))
        settings.apply(.blackPoint(0.25))
        settings.apply(.blackPoint(0.6))
        #expect(settings.blackPoint == 0.25)
        settings.apply(.blackPoint(0.9))
        #expect(settings.blackPoint == 0.25)
        settings.apply(.whitePoint(0.25))
        #expect(settings.whitePoint == 0.6)
        settings.apply(.whitePoint(0.1))
        #expect(settings.whitePoint == 0.6)
    }

    @Test func notANumberKeepsTheOldValue() {
        var settings = AdjustmentSettings()
        settings.apply(.exposure(1.5))
        settings.apply(.exposure(.nan))
        settings.apply(.blurSigma(.nan))
        settings.apply(.blackPoint(.nan))
        #expect(settings.exposure == 1.5)
        #expect(settings.blurSigma == 0)
        #expect(settings.blackPoint == 0)
    }

    @Test func resetReturnsOneSectionToItsDefaults() {
        var settings = AdjustmentSettings()
        settings.apply(.exposure(2))
        settings.apply(.blackPoint(0.1))
        settings.apply(.whitePoint(0.8))
        settings.apply(.gamma(2.2))
        settings.apply(.setEnabled(.levels, false))
        settings.apply(.reset(.levels))
        #expect(settings.blackPoint == 0 && settings.whitePoint == 1 && settings.gamma == 1)
        #expect(!settings.isEnabled(.levels))
        #expect(settings.exposure == 2)
        settings.apply(.reset(.exposure))
        #expect(settings.exposure == 0)
    }

    @Test func identityIgnoresDisabledSections() {
        var settings = AdjustmentSettings()
        settings.apply(.hue(30))
        #expect(!settings.isIdentity)
        #expect(!settings.isIdentity(.hueSaturation))
        #expect(settings.isIdentity(.blur))
        settings.apply(.setEnabled(.hueSaturation, false))
        #expect(settings.isIdentity)
        settings.apply(.setEnabled(.hueSaturation, true))
        #expect(!settings.isIdentity)
    }

    @Test func workspaceAdjustsAndANewCanvasStartsFresh() throws {
        var workspace = PhotoWorkspace()
        workspace.adjust(.exposure(1))
        #expect(workspace.adjustments.exposure == 1)
        try workspace.newCanvas(width: 2, height: 2)
        #expect(workspace.adjustments == AdjustmentSettings())
    }
}
