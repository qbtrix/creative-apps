// LibraryToneTests.swift (tone-controls LT-1 writes it, LT-4 turns on MJ-LT).
// `LibraryToneCodingTests` is LT-1's acceptance: `DevelopSettings` holds
// SuiteImaging's `ToneSettings`, and its coding flattens the tone into the
// develop object, so every catalog fixture decodes to the same develop values
// and re-encodes byte for byte; it fails when a catalog's keys change.
// `LibraryToneTests` is MJ-LT, the Model walk of the loupe's tone route,
// disabled by name until LT-4 hands `ToneRules.unsharp` and the tone program to
// the loupe (its checks fail on TC-1's empty `ToneRules` stubs). The test
// target declares no resources, so the fixtures are the Swift literals the
// persist golden and the imaging tests already hold, plus one with every key.
// Runs on Linux and macOS.
import CoreRaster
import CoreRender
import Foundation
@testable import LibraryModel
import SuiteImaging
import Testing

private func sortedJSON<T: Encodable>(_ value: T) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .sortedKeys
    return try encoder.encode(value)
}

@Suite struct LibraryToneCodingTests {
    /// Every key a develop object can hold today, off neutral, as the catalog writes it (sorted keys).
    static let everyKey = #"{"blacks":-5,"contrast":12,"crop":{"angle":2,"aspect":"Free","rect":{"height":1,"width":1,"x":0,"y":0}},"curve":{"points":[{"x":0,"y":0},{"x":0.5,"y":0.6},{"x":1,"y":1}]},"exposure":0.5,"highlights":-30,"levels":{"gamma":1.2,"inBlack":0,"inWhite":1,"outBlack":0,"outWhite":1},"saturation":-10,"shadows":25,"temperature":8,"tint":-3,"vibrance":15,"whites":20}"#
    /// The values `everyKey` holds, by slider.
    static let everyKeyValues: [ToneSlider: Double] = [
        .exposure: 0.5, .contrast: 12, .highlights: -30, .shadows: 25, .whites: 20, .blacks: -5,
        .temperature: 8, .tint: -3, .vibrance: 15, .saturation: -10,
    ]
    /// A catalog from before any newer key: only the six original sliders.
    static let sixKeys = #"{"contrast":0,"exposure":1,"highlights":0,"shadows":0,"temperature":0,"tint":0}"#

    /// Every develop fixture: the new one, the six-key one and the imaging tests' curve and levels ones.
    static var fixtures: [String] { [everyKey, sixKeys] + LibraryImagingTests.developFixtures }

    @Test func everyFixtureReencodesByteForByte() throws {
        for json in Self.fixtures {
            let settings = try JSONDecoder().decode(DevelopSettings.self, from: Data(json.utf8))
            #expect(String(decoding: try sortedJSON(settings), as: UTF8.self) == json)
        }
    }

    @Test func fixturesDecodeToTheSameDevelopValues() throws {
        let every = try JSONDecoder().decode(DevelopSettings.self, from: Data(Self.everyKey.utf8))
        for slider in ToneSlider.allCases {
            #expect(every.tone.value(slider) == Self.everyKeyValues[slider] ?? slider.neutral, "\(slider)")
            #expect(every.value(slider) == every.tone.value(slider))
        }
        #expect(every.curve.points.count == 3 && every.levels.gamma == 1.2 && every.crop?.angle == 2)
        let six = try JSONDecoder().decode(DevelopSettings.self, from: Data(Self.sixKeys.utf8))
        #expect(six == DevelopSettings.neutral.setting(.exposure, to: 1))
        #expect(six.tone == ToneSettings.neutral.setting(.exposure, to: 1))
    }

    @Test func theCatalogGoldenOpensAsItDid() throws {
        let coding = LiveCatalogCoding()
        let golden = Data(LibraryPersistGolden.catalogV1.utf8)
        let photos = try coding.decode(golden)
        #expect(photos == LibraryPersistGolden.photos)
        let first = try #require(photos.first)
        #expect(first.develop.tone.value(.exposure) == 1 && first.develop.tone.value(.contrast) == -20)
        #expect(try coding.encode(photos) == golden)
    }

    /// The tone is flat in the develop object: no "tone" key, the slider's own key, neutral writes none.
    @Test func toneKeysStayFlat() throws {
        let sharpened = DevelopSettings.neutral.setting(.brightness, to: 10).setting(.sharpenAmount, to: 60)
        let json = String(decoding: try sortedJSON(sharpened), as: UTF8.self)
        #expect(json == #"{"brightness":10,"contrast":0,"exposure":0,"highlights":0,"shadows":0,"sharpenAmount":60,"temperature":0,"tint":0}"#)
        #expect(try JSONDecoder().decode(DevelopSettings.self, from: Data(json.utf8)) == sharpened)
        let missing = #"{"contrast":0,"highlights":0,"shadows":0,"temperature":0,"tint":0}"#
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(DevelopSettings.self, from: Data(missing.utf8)) }
    }

    /// Develop's rows keep their ten sliders, labels and ranges; NaN gives neutral; the new sliders clamp.
    @Test func developSlidersAreToneSliders() {
        #expect(ToneSlider.develop == DevelopGroup.tone.sliders + DevelopGroup.color.sliders)
        #expect(ToneSlider.develop.map(\.title) == ["Exposure", "Contrast", "Highlights", "Shadows", "Whites", "Blacks",
                                                     "Temperature", "Tint", "Vibrance", "Saturation"])
        #expect(DevelopSettings.neutral.setting(.sharpenAmount, to: 900).value(.sharpenAmount) == 300)
        #expect(DevelopSettings.neutral.setting(.sharpenRadius, to: .nan).value(.sharpenRadius) == 1)
        #expect(!DevelopSettings.neutral.setting(.sharpenAmount, to: 60).isAdjustmentNeutral)
    }
}

/// A 4 x 1 linear grey ramp.
private func ramp() throws -> PixelBuffer {
    var b = try PixelBuffer(width: 4, height: 1)
    for x in 0..<4 { let v = Float(x + 1) / 5; try b.setPixel(x: x, y: 0, RGBA(r: v, g: v, b: v, a: 1)) }
    return b
}

/// MJ-LT: the loupe's tone route against export. LT-4 turns it on with the tone half of
/// `LibraryDevelop+Imaging.swift`; until then `ToneRules` is TC-1's stubs and these fail.
@Suite(.disabled("waits on LT-4")) struct LibraryToneTests {
    static let developed = DevelopSettings.neutral.setting(.exposure, to: 0.5).setting(.shadows, to: 30)
        .setting(.whites, to: 10).setting(.saturation, to: 20)

    /// The tone program on the CPU (`ToneProgram.map`) equals LiveDevelop's export within 2 levels.
    @Test func matchesExport() throws {
        let input = try ramp(), s = Self.developed
        let program = try ToneProgram(operations: ToneRules.program(s.tone))
        #expect(!program.isEmpty)
        let exported = try LiveDevelop().render(input, settings: s)
        for x in 0..<input.width {
            let gpu = program.map(try input.pixel(x: x, y: 0)), cpu = try exported.pixel(x: x, y: 0)
            #expect(abs(gpu.r - cpu.r) <= 2 / 255 && abs(gpu.g - cpu.g) <= 2 / 255 && abs(gpu.b - cpu.b) <= 2 / 255)
        }
    }

    /// A Shadows step changes only the program: the unsharp pass, and so the cached base, stays.
    @Test func stepIsOneWrite() {
        let before = Self.developed.setting(.sharpenAmount, to: 60)
        let after = before.setting(.shadows, to: 31)
        #expect(ToneRules.program(after.tone) != ToneRules.program(before.tone))
        #expect(ToneRules.unsharp(after.tone)?.amount == ToneRules.unsharp(before.tone)?.amount)
        #expect(ToneRules.unsharp(after.tone) != nil)
    }

    /// A Sharpen step changes the unsharp pass, so the base is re-run once.
    @Test func sharpenStepRerunsTheBase() {
        let before = Self.developed.setting(.sharpenAmount, to: 60)
        let after = before.setting(.sharpenAmount, to: 80)
        #expect(ToneRules.unsharp(after.tone)?.amount != ToneRules.unsharp(before.tone)?.amount)
        #expect(ToneRules.unsharp(Self.developed.tone) == nil)
    }
}
