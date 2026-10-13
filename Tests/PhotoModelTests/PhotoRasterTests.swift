// PhotoRasterTests.swift: the adjustments change the rendered image (#27):
// exposure, levels, hue/saturation and blur, each skipped while disabled.
// Runs on Linux and macOS.
import CoreRaster
import PhotoModel
import Testing

@Suite struct PhotoRasterTests {
    /// A 4x4 image of mid gray (linear 0.5... after sRGB decoding of byte 188).
    private func gray() throws -> PhotoWorkspace {
        var workspace = PhotoWorkspace()
        try workspace.open(rgba8: [UInt8](repeating: 188, count: 64).enumerated().map { $0.offset % 4 == 3 ? 255 : $0.element },
                           width: 4, height: 4, name: "gray.png")
        return workspace
    }

    @Test func zeroStopsAndZeroBlurLeaveTheImageAlone() throws {
        var workspace = try gray()
        let before = try workspace.composite()
        workspace.adjust(.exposure(0))
        workspace.adjust(.blurSigma(0))
        #expect(try workspace.composite() == before)
    }

    @Test func oneStopDoublesTheLinearValue() throws {
        var workspace = try gray()
        let before = try canvasPixel(workspace, 1, 1)
        workspace.adjust(.exposure(1))
        let after = try canvasPixel(workspace, 1, 1)
        #expect(abs(after.r - 2 * before.r) < 1e-5 && after.a == 1)
        #expect(workspace.undoActionName == "Undo Exposure")
    }

    @Test func aDisabledSectionIsSkipped() throws {
        var workspace = try gray()
        let before = try workspace.composite()
        workspace.adjust(.exposure(2))
        workspace.adjust(.setEnabled(.exposure, false))
        #expect(try workspace.composite() == before)
    }

    @Test func levelsStretchBetweenBlackAndWhite() throws {
        var workspace = try gray()
        let before = try canvasPixel(workspace, 0, 0).r
        workspace.adjust(.whitePoint(before))
        // White snaps to levelsStep, so the pixel lands within a step of 1.
        let white = workspace.adjustments.whitePoint
        #expect(abs(white - before) <= Float(AdjustmentSettings.levelsStep) / 2)
        #expect(abs(try canvasPixel(workspace, 0, 0).r - min(1, before / white)) < 1e-4)
    }

    @Test func saturationToGrayAndLightnessToWhite() throws {
        var workspace = try whiteImage(2, 2)
        addFilledLayer(&workspace, red: 255, green: 0, blue: 0)
        workspace.adjust(.saturation(-100))
        let gray = try canvasPixel(workspace, 0, 0)
        #expect(abs(gray.r - gray.g) < 1e-4 && abs(gray.g - gray.b) < 1e-4)
        workspace.adjust(.lightness(100))
        let white = try canvasPixel(workspace, 0, 0)
        #expect(abs(white.r - 1) < 1e-4 && abs(white.b - 1) < 1e-4)
    }

    @Test func aHalfTurnOfHueMovesRedTowardCyan() throws {
        var workspace = try whiteImage(2, 2)
        addFilledLayer(&workspace, red: 255, green: 0, blue: 0)
        workspace.adjust(.hue(180))
        let turned = try canvasPixel(workspace, 0, 0)
        #expect(turned.r < turned.g && turned.r < turned.b)
    }

    @Test func blurSoftensAnEdge() throws {
        var workspace = try whiteImage(16, 16)
        workspace.addLayer()
        stroke(&workspace, .marquee, from: point(0, 0), to: point(8, 16))
        workspace.fillSelection()
        workspace.adjust(.blurSigma(2))
        let edge = try canvasPixel(workspace, 8, 8)
        #expect(edge.r > 0.05 && edge.r < 0.95)
    }

    @Test func aNaNExposureChangesNothing() throws {
        var workspace = try gray()
        let before = workspace
        workspace.adjust(.exposure(.nan))
        #expect(workspace == before)
    }

    @Test func aRunOfOneSlidersEditsIsOneUndoStep() throws {
        var workspace = try gray()
        for stops in stride(from: 0.1, through: 1.0, by: 0.1) { workspace.adjust(.exposure(Float(stops))) }
        workspace.adjust(.blurSigma(1))
        workspace.undo()
        #expect(workspace.adjustments.blurSigma == 0 && workspace.adjustments.exposure > 0.9)
        workspace.undo()
        #expect(workspace.adjustments == AdjustmentSettings())
        #expect(!workspace.canUndo)
    }
}
