// AdjustSettingsTests.swift: AdjustSettings' ranges, the curve repair and the
// one Codable form Photo and Library both read (suite-imaging IM-3). Neither
// app stores a level as a percent or a byte today (both store 0...1), so the
// percent keys are Photo's field unit (`blackPercent`) and the 0...255 keys
// Library's row unit (`black`), beside both apps' stored keys. Mutations:
// SuiteImaging.AdjustSettings.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import Testing
import SuiteImaging

@Suite struct AdjustSettingsTests {
    static func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }

    static func points(_ xs: [Double]) -> [AdjustCurvePoint] {
        xs.map { AdjustCurvePoint(x: $0, y: $0) }
    }

    @Test func gammaCeiling() {
        var levels = AdjustLevels.neutral
        levels.gamma = 10
        #expect(levels.clamped().gamma == 9.99)
        levels.gamma = 0.01
        #expect(levels.clamped().gamma == 0.1)
    }

    /// Photo's percent and Library's 0...255 keys name the same level.
    @Test func photoPercentKeys() throws {
        let photo = try Self.decode(AdjustLevels.self, #"{"blackPercent": 10}"#)
        let library = try Self.decode(AdjustLevels.self, #"{"black": 25.5}"#)
        #expect(abs(photo.inputBlack - 0.1) < 1e-9)
        #expect(abs(library.inputBlack - 0.1) < 1e-9)
        #expect(photo.inputWhite == 1 && library.gamma == 1)
        let rows = try Self.decode(AdjustLevels.self, #"{"whitePercent": 80, "outputBlack": 51, "outputWhite": 204}"#)
        #expect(abs(rows.inputWhite - 0.8) < 1e-9)
        #expect(abs(rows.outputBlack - 0.2) < 1e-9 && abs(rows.outputWhite - 0.8) < 1e-9)
    }

    /// Both apps' stored keys (0...1) read as they are; Library's keys win.
    @Test func storedKeys() throws {
        let library = try Self.decode(AdjustLevels.self,
                                      #"{"inBlack": 0.1, "inWhite": 0.9, "gamma": 2, "outBlack": 0.05, "outWhite": 0.95}"#)
        #expect(library == AdjustLevels(inputBlack: 0.1, inputWhite: 0.9, gamma: 2, outputBlack: 0.05, outputWhite: 0.95))
        let photo = try Self.decode(AdjustLevels.self, #"{"blackPoint": 0.2, "whitePoint": 0.7, "gamma": 10}"#)
        #expect(photo == AdjustLevels(inputBlack: 0.2, inputWhite: 0.7, gamma: 9.99, outputBlack: 0, outputWhite: 1))
        let both = try Self.decode(AdjustLevels.self, #"{"inBlack": 0.3, "blackPoint": 0.2, "black": 0}"#)
        #expect(both.inputBlack == 0.3)
    }

    /// Levels encode Library's five keys, and read back as themselves.
    @Test func levelsEncodeLibraryKeys() throws {
        let levels = AdjustLevels(inputBlack: 0.25, inputWhite: 0.75, gamma: 1.5, outputBlack: 0, outputWhite: 1)
        let object = try JSONDecoder().decode([String: Double].self, from: JSONEncoder().encode(levels))
        #expect(object == ["inBlack": 0.25, "inWhite": 0.75, "gamma": 1.5, "outBlack": 0, "outWhite": 1])
        #expect(try JSONDecoder().decode(AdjustLevels.self, from: JSONEncoder().encode(levels)) == levels)
    }

    /// A damaged file is read back in range, never refused.
    @Test func decodeClamps() throws {
        let settings = try Self.decode(AdjustSettings.self, #"""
            {"exposure": 9, "levels": {"inBlack": 2, "gamma": 0}, "hueSaturation": {"hue": 400, "saturation": -300},
             "curve": {"points": [{"x": 0.5, "y": 0.5}]}}
            """#)
        #expect(settings.exposure == 5)
        #expect(settings.levels.inputBlack == 1 - AdjustCurve.minGap && settings.levels.gamma == 0.1)
        #expect(settings.hueSaturation == AdjustHueSaturation(hue: 180, saturation: -100, lightness: 0))
        #expect(settings.curve == .identity)
    }

    @Test func blackStaysBelowWhite() {
        let levels = AdjustLevels(inputBlack: 0.8, inputWhite: 0.5, gamma: 1, outputBlack: -1, outputWhite: 2).clamped()
        #expect(levels.inputWhite - levels.inputBlack >= AdjustCurve.minGap - 1e-12)
        #expect(levels.outputBlack == 0 && levels.outputWhite == 1)
    }

    @Test func seventeenPointsKeepSixteen() {
        let curve = AdjustCurve(points: Self.points((0...16).map { Double($0) / 16 }))
        #expect(curve.points.count == AdjustCurve.maxPoints)
        #expect(curve.points.first?.x == 0 && curve.points.last?.x == 1)
    }

    /// Points 1/512 apart merge; points exactly `minGap` apart both stay.
    @Test func nearPointsMerge() {
        #expect(AdjustCurve(points: Self.points([0, 0.5, 0.5 + 1.0 / 512, 1])).points.count == 3)
        #expect(AdjustCurve(points: Self.points([0, AdjustCurve.minGap, 1])).points.count == 3)
    }

    @Test func curveSortsAndClamps() {
        let curve = AdjustCurve(points: [AdjustCurvePoint(x: 1.5, y: 2), AdjustCurvePoint(x: -1, y: 0), AdjustCurvePoint(x: 0.5, y: 0.4)])
        #expect(curve.points.map(\.x) == [0, 0.5, 1])
        #expect(curve.points.allSatisfy { (0...1).contains($0.y) })
    }

    @Test func nanRefused() {
        let curve = AdjustCurve(points: [AdjustCurvePoint(x: 0, y: 0), AdjustCurvePoint(x: .nan, y: 0.5), AdjustCurvePoint(x: 1, y: 1)])
        #expect(curve == .identity)
        let nanY = AdjustCurve(points: [AdjustCurvePoint(x: 0, y: 0), AdjustCurvePoint(x: 0.5, y: .nan), AdjustCurvePoint(x: 1, y: 1)])
        #expect(nanY == .identity)
        var levels = AdjustLevels.neutral
        levels.gamma = .nan
        #expect(levels.clamped() == .neutral)
    }

    @Test func neutralEncodesToEmpty() throws {
        let data = try JSONEncoder().encode(AdjustSettings.neutral)
        #expect(String(decoding: data, as: UTF8.self) == "{}")
        #expect(try Self.decode(AdjustSettings.self, "{}") == .neutral)
        #expect(AdjustSettings.neutral.isNeutral)
    }

    @Test func settingsRoundTrip() throws {
        let settings = AdjustSettings(exposure: 1.25, levels: AdjustLevels(inputBlack: 0.1, inputWhite: 0.9, gamma: 1.4,
                                                                         outputBlack: 0, outputWhite: 1),
                                      curve: AdjustCurve(points: Self.points([0, 0.5, 1])),
                                      hueSaturation: AdjustHueSaturation(hue: 30, saturation: -100, lightness: 0))
        let decoded = try JSONDecoder().decode(AdjustSettings.self, from: JSONEncoder().encode(settings))
        #expect(decoded == settings)
        #expect(!decoded.isNeutral)
    }
}
