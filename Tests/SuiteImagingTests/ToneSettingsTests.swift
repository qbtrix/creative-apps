// ToneSettingsTests.swift (tone-controls TC-1 written disabled, TC-7 turns it on):
// ToneSettings' coding and clamping. Mutations (TC-7): SuiteImaging.ToneSettings
// (`.neutralWritesNoKey`, `.clampsToRange`, `.resetKeepsOtherGroups`).
import Foundation
import Testing
import SuiteImaging

@Suite(.disabled("waits on TC-7")) struct ToneSettingsTests {
    static func keys(_ s: ToneSettings) throws -> Set<String> {
        Set((try JSONSerialization.jsonObject(with: JSONEncoder().encode(s)) as? [String: Any] ?? [:]).keys)
    }

    /// Neutral writes `{}`; one slider off neutral writes exactly its key.
    @Test func neutralWritesNoKey() throws {
        #expect(try Self.keys(.neutral).isEmpty)
        let warm = ToneSettings.neutral.setting(.temperature, to: 35)
        #expect(try Self.keys(warm) == ["temperature"])
        #expect(try Self.keys(warm.setting(.temperature, to: 0)).isEmpty)
    }

    /// Library's catalog JSON (its ten Develop keys) decodes to the same values; a missing key reads neutral.
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
        #expect(try JSONDecoder().decode(ToneSettings.self, from: JSONEncoder().encode(s)) == s)
    }

    /// −250 clamps to −100, exposure to ±5, radius to 0.5...3; NaN keeps the old value.
    @Test func clampsToRange() {
        #expect(ToneSettings.neutral.setting(.shadows, to: -250).value(.shadows) == -100)
        #expect(ToneSettings.neutral.setting(.exposure, to: 9).value(.exposure) == 5)
        #expect(ToneSettings.neutral.setting(.sharpenRadius, to: 0).value(.sharpenRadius) == 0.5)
        #expect(ToneSettings.neutral.setting(.contrast, to: 20).setting(.contrast, to: .nan).value(.contrast) == 20)
    }

    /// `reset(.tone)` clears TONE and leaves white balance; `reset(nil)` clears everything.
    @Test func resetKeepsOtherGroups() {
        let s = ToneSettings.neutral.setting(.temperature, to: 30).setting(.shadows, to: 35)
        let reset = s.reset(.tone)
        #expect(reset.value(.temperature) == 30 && reset.value(.shadows) == 0)
        #expect(reset.isNeutral(.tone) && !reset.isNeutral(.whiteBalance) && !reset.isNeutral(nil))
        #expect(s.reset(nil) == .neutral)
    }
}
