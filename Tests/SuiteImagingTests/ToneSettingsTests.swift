// ToneSettingsTests.swift (tone-controls TC-1 written disabled, TC-7 turns it on):
// ToneSettings' coding and clamping. A neutral slider writes no key, Library's
// ten Develop keys decode unchanged, values clamp to the slider's range, NaN
// keeps the old value, and a group's reset leaves the other groups alone.
// Mutations (TC-7): SuiteImaging.ToneSettings (`.neutralWritesNoKey`,
// `.clampsToRange`, `.resetKeepsOtherGroups`).
import Foundation
import Testing
import SuiteImaging

@Suite(.disabled("waits on TC-7")) struct ToneSettingsTests {
    /// The keys `s` encodes to.
    static func keys(_ s: ToneSettings) throws -> Set<String> {
        let data = try JSONEncoder().encode(s)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return Set((object ?? [:]).keys)
    }

    /// Neutral writes `{}`; one slider off neutral writes exactly its key.
    @Test func neutralWritesNoKey() throws {
        #expect(try Self.keys(.neutral).isEmpty)
        let warm = ToneSettings.neutral.setting(.temperature, to: 35)
        #expect(try Self.keys(warm) == ["temperature"])
        #expect(try Self.keys(warm.setting(.temperature, to: 0)).isEmpty)
        #expect(try Self.keys(ToneSettings.neutral.setting(.sharpenRadius, to: 1)).isEmpty)
    }

    /// Library's catalog JSON (its ten Develop keys) decodes to the same values, and a missing key reads neutral.
    @Test func libraryKeysDecode() throws {
        let json = """
            {"exposure": 0.5, "contrast": 10, "highlights": -40, "shadows": 35, "whites": 5, "blacks": -5,
             "temperature": 30, "tint": -10, "vibrance": 20, "saturation": -15}
            """
        let s = try JSONDecoder().decode(ToneSettings.self, from: Data(json.utf8))
        let expected: [ToneSlider: Double] = [.exposure: 0.5, .contrast: 10, .highlights: -40, .shadows: 35, .whites: 5,
                                              .blacks: -5, .temperature: 30, .tint: -10, .vibrance: 20, .saturation: -15]
        for (slider, value) in expected { #expect(s.value(slider) == value, "\(slider)") }
        #expect(s.value(.brightness) == 0 && s.value(.sharpenRadius) == 1)
        let back = try JSONDecoder().decode(ToneSettings.self, from: try JSONEncoder().encode(s))
        #expect(back == s)
    }

    /// −250 clamps to −100, exposure to ±5, radius to 0.5...3.
    @Test func clampsToRange() {
        #expect(ToneSettings.neutral.setting(.shadows, to: -250).value(.shadows) == -100)
        #expect(ToneSettings.neutral.setting(.exposure, to: 9).value(.exposure) == 5)
        #expect(ToneSettings.neutral.setting(.sharpenRadius, to: 0).value(.sharpenRadius) == 0.5)
        #expect(ToneSettings.neutral.setting(.sharpenAmount, to: 400).value(.sharpenAmount) == 300)
    }

    /// NaN keeps the old value.
    @Test func nanKeepsTheOldValue() {
        let s = ToneSettings.neutral.setting(.contrast, to: 20)
        #expect(s.setting(.contrast, to: .nan).value(.contrast) == 20)
    }

    /// `reset(.tone)` clears TONE and leaves white balance; `reset(nil)` clears everything.
    @Test func resetKeepsOtherGroups() {
        let s = ToneSettings.neutral.setting(.temperature, to: 30).setting(.shadows, to: 35).setting(.brightness, to: 10)
        let reset = s.reset(.tone)
        #expect(reset.value(.temperature) == 30 && reset.value(.shadows) == 0 && reset.value(.brightness) == 0)
        #expect(reset.isNeutral(.tone) && !reset.isNeutral(.whiteBalance) && !reset.isNeutral(nil))
        #expect(s.reset(nil) == .neutral && s.reset(nil).isNeutral(nil))
    }

    /// Every slider sits in one group, its neutral in its range, and the groups list them in order.
    @Test func slidersAndGroups() {
        #expect(ToneGroup.allCases.flatMap(\.sliders) == ToneSlider.allCases)
        for slider in ToneSlider.allCases {
            #expect(slider.range.contains(slider.neutral), "\(slider)")
            #expect(ToneSettings.neutral.value(slider) == slider.neutral)
            #expect(!slider.title.isEmpty && slider.step > 0)
        }
        #expect(ToneSlider.exposure.step == 0.01 && ToneSlider.sharpenRadius.neutral == 1)
    }
}
