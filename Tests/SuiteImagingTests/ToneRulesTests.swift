// ToneRulesTests.swift (tone-controls TC-1 written disabled, TC-5 turns it on):
// ToneSettings turned into one tone program, the same CPU steps, one unsharp
// pass and Auto's values. Mutations (TC-5): SuiteImaging.ToneRules
// (`.neutralIsEmpty`, `.whitesBrighten`, `.brightnessLifts`,
// `.unsharpThreshold`, `.vibranceWaits`).
import CoreRaster
import CoreRender
import Testing
import SuiteImaging

@Suite(.disabled("waits on TC-5")) struct ToneRulesTests {
    static func set(_ values: [ToneSlider: Double]) -> ToneSettings {
        values.reduce(ToneSettings.neutral) { $0.setting($1.key, to: $1.value) }
    }

    /// Neutral settings give no step and no unsharp pass.
    @Test func neutralIsEmpty() {
        #expect(ToneRules.program(.neutral).isEmpty)
        #expect(ToneRules.adjustments(.neutral).isEmpty)
        #expect(ToneRules.unsharp(.neutral) == nil)
    }

    /// Temperature 30 is one white balance step.
    @Test func temperatureIsOneStep() {
        #expect(ToneRules.adjustments(Self.set([.temperature: 30])) == [.whiteBalance(temperature: 30, tint: 0)])
    }

    /// The live program and the export list are the same steps in the same order.
    @Test func programMatchesAdjustments() {
        let s = Self.set([.temperature: 20, .exposure: 0.5, .brightness: 30, .contrast: 15, .highlights: -40,
                          .shadows: 35, .whites: 10, .blacks: -10, .saturation: 20])
        let cpu = ToneRules.adjustments(s)
        #expect(cpu.count == 8)
        #expect(ToneRules.program(s) == cpu.map(ToneProgram.Operation.adjustment))
    }

    /// Whites 100 moves the white point to 0.75 (a quarter of the range, never more).
    @Test func whitesBrighten() {
        let steps = ToneRules.adjustments(Self.set([.whites: 100]))
        #expect(steps == [.levels(inBlack: 0, inWhite: 0.75, gamma: 1, outBlack: 0, outWhite: 1, encoding: .sRGB)])
    }

    /// Brightness 100 is one levels step with gamma 2, black 0 and white 1.
    @Test func brightnessLifts() {
        let steps = ToneRules.adjustments(Self.set([.brightness: 100]))
        #expect(steps == [.levels(inBlack: 0, inWhite: 1, gamma: 2, outBlack: 0, outWhite: 1, encoding: .sRGB)])
    }

    /// Amount 80, Radius 1.5, Threshold 4 give (0.8, 1.5, 4/255).
    @Test func unsharpThreshold() throws {
        let u = try #require(ToneRules.unsharp(Self.set([.sharpenAmount: 80, .sharpenRadius: 1.5, .sharpenThreshold: 4])))
        #expect(abs(u.amount - 0.8) < 1e-12 && u.sigma == 1.5 && abs(u.threshold - 4.0 / 255) < 1e-12)
        #expect(ToneRules.unsharp(Self.set([.sharpenRadius: 2])) == nil)
    }

    /// The identity suggestion keeps the settings.
    @Test func autoIdentityKeeps() {
        let s = Self.set([.contrast: 25, .shadows: 10])
        let identity = AutoTone(inBlack: 0, inWhite: 1, gamma: 1, temperature: 0, tint: 0)
        #expect(ToneRules.auto(identity, keeping: s) == s)
    }

    /// Auto takes temperature and tint from the suggestion and keeps every other slider.
    @Test func autoTakesWhiteBalance() {
        let s = Self.set([.contrast: 25])
        let warm = AutoTone(inBlack: 0, inWhite: 1, gamma: 1, temperature: 12, tint: -4)
        let out = ToneRules.auto(warm, keeping: s)
        #expect(out.value(.temperature) == 12 && out.value(.tint) == -4 && out.value(.contrast) == 25)
    }

    /// Vibrance waits with its reason and is never in the program while it does.
    @Test func vibranceWaits() {
        #expect(ToneRules.waiting[.vibrance]?.isEmpty == false)
        #expect(ToneRules.program(Self.set([.vibrance: 50])).isEmpty)
        #expect(ToneRules.adjustments(Self.set([.vibrance: 50])).isEmpty)
    }
}
