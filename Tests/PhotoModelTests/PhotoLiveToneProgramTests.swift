// PhotoLiveToneProgramTests.swift: the live route's program comes from SuiteImaging (suite-imaging IM-8,
// slice IM-photo). `toneOperations` is ImagingProgram's step list, as the CPU render runs it, with
// hue/saturation as Photo's own matrix: a file's output levels reach the live GPU picture, a disabled section
// adds nothing, and Blur still sends the region to the dispatcher route. Linux-safe.
import CoreRaster
import CoreRender
import Foundation
import Testing

@testable import PhotoModel

@Suite struct PhotoLiveToneProgramTests {
    /// Settings as a saved file holds them, with output levels off 0 and 1.
    static func settings(blur: Double = 0, enabled: String = #""exposure","levels","curves","hueSaturation","blur""#) throws -> AdjustmentSettings {
        let json = """
            {"exposure": 0.5, "blackPoint": 0.1, "whitePoint": 0.9, "gamma": 1.2, "outputBlack": 0.2, "outputWhite": 0.8,
             "curvePoints": [{"x": 0, "y": 0}, {"x": 0.5, "y": 0.6}, {"x": 1, "y": 1}], "blurSigma": \(blur),
             "hue": 30, "saturation": 20, "lightness": -10, "enabled": [\(enabled)]}
            """
        return try JSONDecoder().decode(AdjustmentSettings.self, from: Data(json.utf8))
    }

    @Test func outputLevelsReachTheLiveRoute() throws {
        let operations = try #require(try Self.settings().toneOperations)
        let levels = operations.compactMap { operation -> ToneAdjustment? in
            if case .adjustment(let step) = operation, case .levels = step { step } else { nil }
        }
        #expect(levels == [.levels(inBlack: 0.1, inWhite: 0.9, gamma: 1.2, outBlack: 0.2, outWhite: 0.8, encoding: .sRGB)])
    }

    @Test func theCPUStepsWithPhotosMatrix() throws {
        let s = try Self.settings()
        let operations = try #require(s.toneOperations)
        let matrix = ToneProgram.Operation.matrix(rows: PixelBuffer.colorMatrix(hue: 30, saturation: 20), lightness: -0.1)
        let expected = s.imagingSteps.dropLast().map(ToneProgram.Operation.adjustment) + [matrix]
        #expect(s.imagingSteps.count == 4)
        #expect(operations == expected)
    }

    @Test func aDisabledSectionAddsNothing() throws {
        let operations = try #require(try Self.settings(enabled: #""exposure","curves""#).toneOperations)
        #expect(operations.count == 2)
        #expect(!operations.contains { if case .matrix = $0 { true } else { false } })
    }

    @Test func blurTakesTheDispatcherRoute() throws {
        #expect(try Self.settings(blur: 2).toneOperations == nil)
    }
}
