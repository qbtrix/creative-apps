// PhotoImagingTests.swift: Photo's AdjustmentSettings on SuiteImaging's
// AdjustSettings (suite-imaging IM-6, turned on by IM-7). Every .ora fixture
// opens with the adjustment values it was saved with and saves again byte for
// byte; Photo's settings give ImagingProgram's step list, a disabled section
// adding no step; a file from before output levels (adjust-legacy.ora) opens
// with neutral output levels, and output levels a file does carry come back
// out of a save.
import CoreRaster
import CoreRender
import Foundation
import SuiteImaging
import Testing

@testable import PhotoModel

@Suite struct PhotoImagingTests {
    static let fixtures = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    static let root = fixtures.deletingLastPathComponent()

    static let legacy = fixtures.appendingPathComponent("Fixtures/adjust-legacy.ora")
    static let all = [
        legacy,
        root.appendingPathComponent("RealJobs/photo/fade-layers/input/four-layers.ora"),
        root.appendingPathComponent("RealJobs/photo/free-transform/input/logo-on-photo.ora"),
    ]

    /// The adjustments adjust-legacy.ora was saved with.
    static func legacySettings() -> AdjustmentSettings {
        var settings = AdjustmentSettings()
        for edit: AdjustmentEdit in [.exposure(0.25), .blackPoint(0.05), .whitePoint(0.9), .gamma(1.2),
                                     .curvePoints([CurvePoint(x: 0, y: 0), CurvePoint(x: 0.4, y: 0.5), CurvePoint(x: 1, y: 1)]),
                                     .hue(20), .saturation(-15), .lightness(5), .blurSigma(0.5),
                                     .setEnabled(.blur, false)] {
            settings.apply(edit)
        }
        return settings
    }

    @Test(arguments: all)
    func aFixtureOpensWithItsValuesAndSavesByteForByte(_ url: URL) throws {
        let data = try Data(contentsOf: url)
        let opened = try PhotoHeadless.open(data, name: url.lastPathComponent)
        let saved = try opened.save()
        let again = try PhotoHeadless.open(saved, name: url.lastPathComponent)
        #expect(again.workspace.adjustments == opened.workspace.adjustments)
        #expect(again.workspace.layers == opened.workspace.layers)
        #expect(try again.save() == saved, "a second save wrote other bytes")
        if url == Self.legacy {
            #expect(saved == data, "adjust-legacy.ora saved again with other bytes")
            #expect(opened.workspace.adjustments == Self.legacySettings())
        }
    }

    @Test func photosSettingsGiveImagingProgramsSteps() {
        let settings = Self.legacySettings()
        let curve = [CurvePoint(x: 0, y: 0), CurvePoint(x: 0.4, y: 0.5), CurvePoint(x: 1, y: 1)]
        let expected: [ToneAdjustment] = [
            .exposure(stops: 0.25),
            .levels(inBlack: 0.05, inWhite: 0.9, gamma: 1.2, outBlack: 0, outWhite: 1, encoding: .sRGB),
            .curves(points: curve, encoding: .sRGB),
            .hueSaturation(hue: 20, saturation: -15, lightness: 5),
        ]
        #expect(ImagingProgram.adjustments(settings.imaging) == expected)
        #expect(settings.imagingSteps == expected)
        var levelsOff = settings
        levelsOff.apply(.setEnabled(.levels, false))
        #expect(levelsOff.imagingSteps == expected.enumerated().filter { $0.offset != 1 }.map(\.element))
        #expect(AdjustmentSettings().imagingSteps.isEmpty)
    }

    @Test func aLegacyFileGainsNeutralOutputLevels() throws {
        let opened = try PhotoHeadless.open(try Data(contentsOf: Self.legacy), name: "adjust-legacy.ora")
        let settings = opened.workspace.adjustments
        #expect(settings.outputBlack == 0)
        #expect(settings.outputWhite == 1)
        #expect(settings.imaging.levels.outputBlack == 0 && settings.imaging.levels.outputWhite == 1)
        let layers = opened.workspace.layers.compactMap { layer -> AdjustmentSettings? in
            if case .adjustment(let settings) = layer.kind { return settings }
            return nil
        }
        #expect(!layers.isEmpty)
        #expect(layers.allSatisfy { $0.outputBlack == 0 && $0.outputWhite == 1 })
    }

    @Test func outputLevelsAFileCarriesComeBackOut() throws {
        let neutral = try JSONEncoder().encode(AdjustmentSettings())
        var text = try #require(String(data: neutral, encoding: .utf8))
        #expect(!text.contains("output"), "neutral output levels are not written")
        text = text.replacingOccurrences(of: "\"gamma\":", with: "\"outputBlack\":0.1,\"outputWhite\":0.8,\"gamma\":")
        let decoded = try JSONDecoder().decode(AdjustmentSettings.self, from: Data(text.utf8))
        #expect(decoded.outputBlack == 0.1)
        #expect(decoded.outputWhite == 0.8)
        let levels: [ToneAdjustment] = [
            .levels(inBlack: 0, inWhite: 1, gamma: 1, outBlack: 0.1, outWhite: 0.8, encoding: .sRGB),
        ]
        #expect(decoded.imagingSteps == levels)
        let again = try JSONDecoder().decode(AdjustmentSettings.self, from: try JSONEncoder().encode(decoded))
        #expect(again == decoded)
    }
}
