// LibraryImagingTests.swift: MJ-IM-library (suite-imaging IM-9 writes it,
// IM-10 turns it on). Library's develop values are SuiteImaging's: every
// catalog fixture decodes to the same develop values through SuiteImaging's
// AdjustLevels and AdjustCurve and re-encodes byte for byte, so a catalog's
// keys never change; LiveDevelop renders what ImagingProgram.adjustments
// renders on the shared CPU backend; Saturation renders instead of waiting
// on creative-core. IM-10 made DevelopLevels and DevelopCurvePoint
// SuiteImaging's types and gave ToneCurve its AdjustCurve conversions, so the
// catalog cases run; IM-10b runs the shared list in LiveDevelop and turns
// on the rest. Runs on Linux and macOS.
import CoreRaster
import CoreRender
import Foundation
@testable import LibraryModel
import SuiteImaging
import Testing

struct LibraryImagingTests {
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
            curve: s.curve.adjustCurve,
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

    /// Library's levels are SuiteImaging's: the catalog's five keys in 0...1,
    /// and a row's 0...255 value is written as its 0...1 key.
    @Test func catalogKeysUnchanged() throws {
        #expect(DevelopLevels.self == AdjustLevels.self && DevelopCurvePoint.self == AdjustCurvePoint.self)
        let rows = DevelopLevels.neutral.setting(.inBlack, row: 51).setting(.inWhite, row: 204)
            .setting(.gamma, row: 1.5).setting(.outBlack, row: 25.5).setting(.outWhite, row: 229.5)
        let json = String(decoding: try Self.sorted(rows), as: UTF8.self)
        #expect(json == #"{"gamma":1.5,"inBlack":0.2,"inWhite":0.8,"outBlack":0.1,"outWhite":0.9}"#)
        for field in DevelopLevels.Field.allCases {
            #expect(abs(rows.row(field) - rows.value(field) * (field == .gamma ? 1 : 255)) < 1e-9, "\(field)")
        }
        #expect(try JSONDecoder().decode(DevelopLevels.self, from: Data(json.utf8)) == rows)
        #expect(rows.inBlack == 0.2 && rows.inWhite == 0.8 && rows.outBlack == 0.1 && rows.outWhite == 0.9)
    }

    /// ToneCurve to AdjustCurve and back keeps every catalog curve's points;
    /// an AdjustCurve's ends are pinned to x = 0 and 1 and its points under
    /// ToneCurve's 0.01 gap dropped, as ToneCurve's own init does.
    @Test func curveRoundTrip() throws {
        for (_, settings) in try Self.catalogDevelops() {
            let curve = settings.curve, adjust = curve.adjustCurve
            #expect(adjust.points == curve.points)
            #expect(ToneCurve(adjust) == curve)
        }
        let shared = AdjustCurve(points: [.init(x: 0.1, y: 0.2), .init(x: 0.5, y: 0.6), .init(x: 0.505, y: 0.7), .init(x: 0.9, y: 0.8)])
        #expect(shared.points.count == 4)
        #expect(ToneCurve(shared).points == [.init(x: 0, y: 0.2), .init(x: 0.5, y: 0.6), .init(x: 1, y: 0.8)])
        #expect(ToneCurve(.identity) == .identity)
    }

    @Test func liveDevelopRendersWhatTheSharedListRenders() throws {
        let cpu = CPUBackend()
        let image = try developGradient()
        // Library's own passes (white balance, contrast, highlights and
        // shadows, whites and blacks) aren't in the shared list: compare the shared controls.
        let own: [DevelopSlider] = [.temperature, .tint, .contrast, .highlights, .shadows, .whites, .blacks]
        for (_, settings) in try Self.catalogDevelops() {
            let tone = own.reduce(settings.setting(crop: nil)) { $0.setting($1, to: 0) }
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

    /// Library runs levels before the curve, as Photo does: a curve-plus-levels
    /// edit renders the list Photo's live route runs for the same settings
    /// (`ImagingProgram.adjustments`, PhotoImagingTests), not Library's old
    /// curve-then-levels order (the supervisor's ruling on #3715).
    @Test func curvePlusLevelsRendersAsPhotoDoes() throws {
        let curve = try #require(ToneCurve(points: [.init(x: 0, y: 0), .init(x: 0.5, y: 0.7), .init(x: 1, y: 1)]))
        let levels = DevelopLevels.neutral.setting(.inBlack, to: 0.1).setting(.gamma, to: 1.3).setting(.outWhite, to: 0.9)
        let settings = DevelopSettings.neutral.setting(curve: curve).setting(levels: levels)
        let steps = ImagingProgram.adjustments(Self.adjust(settings))
        #expect(steps.count == 2)
        guard case .levels = steps.first, case .curves = steps.last else {
            Issue.record("the shared list runs levels, then the curve: \(steps)")
            return
        }
        let cpu = CPUBackend(), image = try developGradient()
        var surface = try cpu.surface(image)
        for step in steps { surface = try cpu.adjusted(surface, step) }
        let live = try LiveDevelop().render(image, settings: settings)
        #expect(live == (try cpu.read(surface)))
        let old = try image.curves(points: curve.points.map { CurvePoint(x: Float($0.x), y: Float($0.y)) }, encoding: .sRGB)
            .levels(inBlack: 0.1, inWhite: 1, gamma: 1.3, outBlack: 0, outWhite: 0.9, encoding: .sRGB)
        #expect(live != old)
    }
}
