// AdjustSettingsTests.swift: AdjustSettings' ranges, the curve repair and the
// one Codable form Photo and Library both read (suite-imaging IM-3). Written
// with IM-2's stubs and disabled until IM-3 fills the bodies. The decode keys
// below are IM-2's reading of the packet's intents; IM-3 fixes them with the
// decoder. Mutations (IM-3): SuiteImaging.AdjustSettings.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import Testing
import SuiteImaging

@Suite(.disabled("waits on IM-3")) struct AdjustSettingsTests {
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
