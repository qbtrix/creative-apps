// LibraryImagingTests.swift: MJ-IM-library (suite-imaging IM-9 writes it,
// IM-10 turns it on). Library's develop values are SuiteImaging's: every
// catalog fixture decodes to the same develop values through SuiteImaging's
// AdjustLevels and AdjustCurve and re-encodes byte for byte, so a catalog's
// keys never change; LiveDevelop renders what ImagingProgram.adjustments
// renders on the shared CPU backend; Saturation renders instead of waiting
// on creative-core. Disabled until IM-10 makes DevelopLevels, ToneCurve and
// DevelopCurvePoint SuiteImaging's types and LiveDevelop runs the shared
// list. Runs on Linux and macOS.
import CoreRaster
import CoreRender
import Foundation
@testable import LibraryModel
import SuiteImaging
import Testing

@Suite(.disabled("waits on IM-10")) struct LibraryImagingTests {
    /// Develop values as the catalog writes them today (sorted keys): a curve, levels off neutral, and both.
    static let developFixtures = [
        #"{"contrast":0,"curve":{"points":[{"x":0,"y":0},{"x":0.5,"y":0.6},{"x":1,"y":1}]},"exposure":0,"highlights":0,"shadows":0,"temperature":0,"tint":0}"#,
        #"{"contrast":0,"exposure":0,"highlights":0,"levels":{"gamma":1.2,"inBlack":0.1,"inWhite":0.9,"outBlack":0.05,"outWhite":0.95},"shadows":0,"temperature":0,"tint":0}"#,
        #"{"contrast":0,"curve":{"points":[{"x":0,"y":0.1},{"x":0.3,"y":0.2},{"x":1,"y":0.9}]},"exposure":1,"highlights":0,"levels":{"gamma":0.8,"inBlack":0,"inWhite":1,"outBlack":0,"outWhite":1},"saturation":-10,"shadows":0,"temperature":0,"tint":0}"#,
    ]

    static func sorted<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try encoder.encode(value)
    }

    /// Every develop value in the catalog golden and the fixtures above.
    static func catalogDevelops() throws -> [(json: Data, settings: DevelopSettings)] {
        let golden = try LiveCatalogCoding().decode(Data(LibraryPersistGolden.catalogV1.utf8)).map(\.develop)
        let fixtures = try developFixtures.map { try JSONDecoder().decode(DevelopSettings.self, from: Data($0.utf8)) }
        return try zip(developFixtures, fixtures).map { (Data($0.utf8), $1) } + golden.map { (try sorted($0), $0) }
    }

    /// The SuiteImaging value for `s`'s exposure, levels, curve and saturation.
    static func adjust(_ s: DevelopSettings) -> AdjustSettings {
        let l = s.levels
        return AdjustSettings(
            exposure: s.exposure,
            levels: AdjustLevels(inputBlack: l.value(.inBlack), inputWhite: l.value(.inWhite), gamma: l.value(.gamma),
                                 outputBlack: l.value(.outBlack), outputWhite: l.value(.outWhite)),
            curve: AdjustCurve(points: s.curve.points.map { AdjustCurvePoint(x: $0.x, y: $0.y) }),
            hueSaturation: AdjustHueSaturation(hue: 0, saturation: s.saturation, lightness: 0))
    }

    @Test func everyCatalogFixtureDecodesToTheSameValuesAndReencodesByteForByte() throws {
        let develops = try Self.catalogDevelops()
        #expect(develops.count == Self.developFixtures.count + 3)
        for (json, settings) in develops {
            #expect(try Self.sorted(settings) == json, "\(String(decoding: json, as: UTF8.self))")
            let levelsJSON = try Self.sorted(settings.levels), curveJSON = try Self.sorted(settings.curve)
            let levels = try JSONDecoder().decode(AdjustLevels.self, from: levelsJSON)
            let curve = try JSONDecoder().decode(AdjustCurve.self, from: curveJSON)
            #expect(levels == Self.adjust(settings).levels)
            #expect(curve == Self.adjust(settings).curve)
            #expect(try Self.sorted(levels) == levelsJSON, "levels keep the catalog's keys and units")
            #expect(try Self.sorted(curve) == curveJSON, "curve points keep the catalog's keys")
        }
    }

    @Test func liveDevelopRendersWhatTheSharedListRenders() throws {
        let cpu = CPUBackend()
        let image = try developGradient()
        for (_, settings) in try Self.catalogDevelops() {
            let tone = settings.setting(crop: nil)
            let live = try LiveDevelop().render(image, settings: tone)
            var surface = try cpu.surface(image)
            for step in ImagingProgram.adjustments(Self.adjust(tone)) { surface = try cpu.adjusted(surface, step) }
            let shared = try cpu.read(surface)
            #expect(live.width == shared.width && live.height == shared.height)
            for (x, y) in [(0, 0), (16, 12), (32, 24), (48, 36), (63, 47)] {
                let p = try live.pixel(x: x, y: y), q = try shared.pixel(x: x, y: y)
                for (u, w) in [(p.r, q.r), (p.g, q.g), (p.b, q.b)] {
                    #expect(abs(u - w) <= 1.0 / 255, "(\(x), \(y)) of \(tone)")
                }
            }
        }
    }

    @Test func saturationRenders() throws {
        #expect(LiveDevelop.waiting[.saturation] == nil)
        let image = try developGradient()
        let grey = try LiveDevelop().render(image, settings: DevelopSettings.neutral.setting(.saturation, to: -100))
        let before = try image.pixel(x: 63, y: 0), after = try grey.pixel(x: 63, y: 0)
        #expect(abs(before.r - before.g) > 0.5)
        #expect(abs(after.r - after.g) <= 1.0 / 255 && abs(after.g - after.b) <= 1.0 / 255)
    }
}
