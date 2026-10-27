// ToneRulesTests.swift (tone-controls TC-1 written disabled, TC-5 turns it on):
// ToneSettings turned into one tone program, the same CPU steps, one unsharp
// pass and Auto's values. Mutations (TC-5): SuiteImaging.ToneRules
// (`.neutralIsEmpty`, `.whitesBrighten`, `.brightnessLifts`, `.unsharpThreshold`, `.vibranceWaits`).
import CoreRaster
import CoreRender
import Testing
import SuiteImaging

@Suite struct ToneRulesTests {
    static func set(_ values: [ToneSlider: Double]) -> ToneSettings {
        values.reduce(ToneSettings.neutral) { $0.setting($1.key, to: $1.value) }
    }

    /// Neutral gives no step and no unsharp pass; temperature 30 is one white balance step.
    @Test func neutralIsEmpty() {
        #expect(ToneRules.program(.neutral).isEmpty && ToneRules.adjustments(.neutral).isEmpty)
        #expect(ToneRules.unsharp(.neutral) == nil)
        #expect(ToneRules.adjustments(Self.set([.temperature: 30])) == [.whiteBalance(temperature: 30, tint: 0)])
    }

    /// The live program and the export list are the same steps in the same order.
    @Test func programMatchesAdjustments() {
        let s = Self.set([.temperature: 20, .exposure: 0.5, .brightness: 30, .contrast: 15, .highlights: -40,
                          .shadows: 35, .whites: 10, .blacks: -10, .saturation: 20])
        let cpu = ToneRules.adjustments(s)
        #expect(cpu.count == 8 && ToneRules.program(s) == cpu.map(ToneProgram.Operation.adjustment))
    }

    /// Whites 100 moves the white point to 0.75 (never more); Blacks 100 lifts the black output to 0.25.
    @Test func whitesBrighten() {
        #expect(ToneRules.adjustments(Self.set([.whites: 100]))
            == [.levels(inBlack: 0, inWhite: 0.75, gamma: 1, outBlack: 0, outWhite: 1, encoding: .sRGB)])
        #expect(ToneRules.adjustments(Self.set([.whites: -100]))
            == [.levels(inBlack: 0, inWhite: 1, gamma: 1, outBlack: 0, outWhite: 0.75, encoding: .sRGB)])
        #expect(ToneRules.adjustments(Self.set([.blacks: 100]))
            == [.levels(inBlack: 0, inWhite: 1, gamma: 1, outBlack: 0.25, outWhite: 1, encoding: .sRGB)])
    }

    /// Brightness 100 is one levels step with gamma 2, black 0 and white 1 fixed; −100 is gamma 0.5.
    @Test func brightnessLifts() {
        #expect(ToneRules.adjustments(Self.set([.brightness: 100]))
            == [.levels(inBlack: 0, inWhite: 1, gamma: 2, outBlack: 0, outWhite: 1, encoding: .sRGB)])
        #expect(ToneRules.adjustments(Self.set([.brightness: -100]))
            == [.levels(inBlack: 0, inWhite: 1, gamma: 0.5, outBlack: 0, outWhite: 1, encoding: .sRGB)])
    }

    /// Amount 80, Radius 1.5, Threshold 4 give (0.8, 1.5, 4/255); Amount 0 gives none.
    @Test func unsharpThreshold() throws {
        let u = try #require(ToneRules.unsharp(Self.set([.sharpenAmount: 80, .sharpenRadius: 1.5, .sharpenThreshold: 4])))
        #expect(abs(u.amount - 0.8) < 1e-12 && u.sigma == 1.5 && abs(u.threshold - 4.0 / 255) < 1e-12)
        #expect(ToneRules.unsharp(Self.set([.sharpenRadius: 2])) == nil)
    }

    /// The identity suggestion keeps the settings; a warm one sets white balance and keeps the rest.
    @Test func autoKeepsOtherSliders() {
        let s = Self.set([.contrast: 25])
        #expect(ToneRules.auto(AutoTone(inBlack: 0, inWhite: 1, gamma: 1, temperature: 0, tint: 0), keeping: s) == s)
        let out = ToneRules.auto(AutoTone(inBlack: 0, inWhite: 1, gamma: 1, temperature: 12, tint: -4), keeping: s)
        #expect(out.value(.temperature) == 12 && out.value(.tint) == -4 && out.value(.contrast) == 25)
    }

    /// Auto reads the levels back into Whites, Blacks and Exposure: a white point below 1 brightens, a black
    /// point above 0 darkens, a gamma over 1 adds exposure; each stays in its slider's range.
    @Test func autoReadsLevels() {
        let out = ToneRules.auto(AutoTone(inBlack: 0.01, inWhite: 0.8, gamma: 2, temperature: 0, tint: 0), keeping: .neutral)
        #expect(out.value(.whites) > 0 && out.value(.whites) <= 100)
        #expect(out.value(.blacks) < 0 && out.value(.blacks) >= -100)
        #expect(out.value(.exposure) > 0 && out.value(.exposure) <= 5)
        let far = ToneRules.auto(AutoTone(inBlack: 0.09, inWhite: 0.1, gamma: 10, temperature: 0, tint: 0), keeping: .neutral)
        #expect(far.value(.whites) == 100 && far.value(.blacks) == -100)
    }

    /// Vibrance waits with its reason and is never in either list while it does.
    @Test func vibranceWaits() {
        #expect(ToneRules.waiting[.vibrance]?.isEmpty == false)
        #expect(ToneRules.program(Self.set([.vibrance: 50])).isEmpty && ToneRules.adjustments(Self.set([.vibrance: 50])).isEmpty)
    }
}
