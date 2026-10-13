// PhotoCurvesTests.swift: the Curves adjustment: its default end points, the
// point lists it refuses, the enable switch, Reset, its place after Levels in
// the render, its undo name, one undo step per gesture (endAdjust), and the
// samples, histogram and histogram key the curve editor uses. Runs on Linux
// and macOS.
import CoreRaster
import PhotoModel
import Testing

@Suite struct PhotoCurvesTests {
    private static let ends = [CurvePoint(x: 0, y: 0), CurvePoint(x: 1, y: 1)]
    /// A three-point curve through (0.5, 0.7): lifts the mid-tones.
    private static let lift = [CurvePoint(x: 0, y: 0), CurvePoint(x: 0.5, y: 0.7), CurvePoint(x: 1, y: 1)]

    /// An open 8 x 8 image filled with sRGB mid-grey (128).
    private func grey() throws -> PhotoWorkspace {
        var workspace = try whiteImage(8, 8)
        addFilledLayer(&workspace, red: 128, green: 128, blue: 128)
        return workspace
    }

    @Test func defaultPointsRenderTheImageUnchanged() throws {
        var workspace = try grey()
        #expect(workspace.adjustments.curvePoints == Self.ends)
        #expect(workspace.adjustments.isIdentity(.curves))
        let withCurves = try workspace.composite()
        workspace.adjust(.setEnabled(.curves, false))
        #expect(try workspace.composite() == withCurves)
    }

    @Test func aThreePointCurveBrightensMidGreyAsCurvesDoes() throws {
        var workspace = try grey()
        let before = try workspace.composite()
        workspace.adjust(.curvePoints(Self.lift))
        #expect(workspace.adjustments.curvePoints == Self.lift)
        let after = try workspace.composite()
        let expected = try before.curves(points: Self.lift, encoding: .sRGB)
        #expect(after == expected)
        #expect(try after.pixel(x: 4, y: 4).r > before.pixel(x: 4, y: 4).r)
    }

    @Test func aRefusedPointListKeepsTheOldPointsAndPixels() throws {
        var workspace = try grey()
        workspace.adjust(.curvePoints(Self.lift))
        let pixels = try workspace.composite()
        let refused: [[CurvePoint]] = [
            [CurvePoint(x: 0.5, y: 0.5)],
            (0...16).map { CurvePoint(x: Float($0) / 16, y: Float($0) / 16) },
            [CurvePoint(x: 0, y: 0), CurvePoint(x: 1.5, y: 1)],
            [CurvePoint(x: -0.1, y: 0), CurvePoint(x: 1, y: 1)],
            [CurvePoint(x: 0, y: 0), CurvePoint(x: 0.6, y: 0.5), CurvePoint(x: 0.4, y: 0.6), CurvePoint(x: 1, y: 1)],
            [CurvePoint(x: 0, y: 0), CurvePoint(x: 0.5, y: 0.5), CurvePoint(x: 0.5, y: 0.7), CurvePoint(x: 1, y: 1)],
            [CurvePoint(x: 0, y: .nan), CurvePoint(x: 1, y: 1)],
            [CurvePoint(x: .infinity, y: 0), CurvePoint(x: 1, y: 1)],
            [CurvePoint(x: 0, y: 0), CurvePoint(x: 1, y: -.infinity)],
        ]
        for points in refused { workspace.adjust(.curvePoints(points)) }
        #expect(workspace.adjustments.curvePoints == Self.lift)
        #expect(try workspace.composite() == pixels)
        // A y outside 0...1 is not refused: it clamps, as the other values do.
        workspace.adjust(.curvePoints([CurvePoint(x: 0, y: -1), CurvePoint(x: 1, y: 2)]))
        #expect(workspace.adjustments.curvePoints == Self.ends)
    }

    @Test func turningCurvesOffRendersAsIdentity() throws {
        var workspace = try grey()
        let plain = try workspace.composite()
        workspace.adjust(.curvePoints(Self.lift))
        #expect(!workspace.adjustments.isIdentity)
        workspace.adjust(.setEnabled(.curves, false))
        #expect(workspace.adjustments.isIdentity)
        #expect(workspace.adjustments.curvePoints == Self.lift)
        #expect(try workspace.composite() == plain)
    }

    @Test func resetRestoresTheEndPoints() {
        var settings = AdjustmentSettings()
        settings.apply(.exposure(1))
        settings.apply(.curvePoints(Self.lift))
        #expect(!settings.isIdentity(.curves))
        settings.apply(.reset(.curves))
        #expect(settings.curvePoints == Self.ends)
        #expect(settings.isIdentity(.curves))
        #expect(settings.exposure == 1)
    }

    @Test func levelsAreAppliedBeforeCurves() throws {
        var workspace = try grey()
        let plain = try workspace.composite()
        workspace.adjust(.blackPoint(0.1))
        workspace.adjust(.curvePoints(Self.lift))
        let black = workspace.adjustments.blackPoint
        let levelsThenCurves = try plain.levels(inBlack: black, inWhite: 1, gamma: 1, outBlack: 0, outWhite: 1, encoding: .sRGB)
            .curves(points: Self.lift, encoding: .sRGB)
        let curvesThenLevels = try plain.curves(points: Self.lift, encoding: .sRGB)
            .levels(inBlack: black, inWhite: 1, gamma: 1, outBlack: 0, outWhite: 1, encoding: .sRGB)
        #expect(levelsThenCurves != curvesThenLevels)
        #expect(try workspace.composite() == levelsThenCurves)
    }

    @Test func oneCurveDragIsOneUndoStepNamedCurves() throws {
        var workspace = try grey()
        let plain = try workspace.composite()
        workspace.adjust(.curvePoints(Self.lift))
        workspace.adjust(.curvePoints([CurvePoint(x: 0, y: 0), CurvePoint(x: 0.5, y: 0.8), CurvePoint(x: 1, y: 1)]))
        #expect(workspace.undoActionName == "Undo Curves")
        workspace.undo()
        #expect(workspace.adjustments.curvePoints == Self.ends)
        #expect(try workspace.composite() == plain)
    }

    @Test func samplesAreTheCurveTheRenderApplies() {
        var settings = AdjustmentSettings()
        settings.apply(.curvePoints(Self.lift))
        #expect(settings.curveSamples(count: 3) == Self.lift)
        let samples = settings.curveSamples()
        #expect(samples.count == 256)
        #expect(samples.first == CurvePoint(x: 0, y: 0) && samples.last == CurvePoint(x: 1, y: 1))
        #expect(samples[128].y > samples[128].x)
        #expect(settings.curveSamples(count: 1).isEmpty)
    }

    @Test func histogramIsTheLuminanceCurvesMaps() throws {
        var workspace = try grey()
        let plainBin = try Histogram(of: workspace.composite(), encoding: .sRGB).luminance.firstIndex { $0 > 0 }
        workspace.adjust(.exposure(1))
        workspace.adjust(.curvePoints(Self.lift))
        let heights = workspace.curvesHistogram()
        var input = workspace
        input.adjust(.setEnabled(.curves, false))
        let counts = try Histogram(of: input.composite(), encoding: .sRGB).luminance
        let tallest = Double(counts.max() ?? 0)
        #expect(heights == counts.map { Double($0) / tallest })
        #expect(heights.firstIndex(of: 1) != plainBin)
        #expect(PhotoWorkspace().curvesHistogram().isEmpty)
    }

    @Test func endAdjustMakesEachCurveGestureItsOwnUndoStep() throws {
        var workspace = try grey()
        let first = [CurvePoint(x: 0, y: 0), CurvePoint(x: 0.5, y: 0.6), CurvePoint(x: 1, y: 1)]
        workspace.adjust(.curvePoints(first))
        workspace.adjust(.curvePoints(Self.lift))
        workspace.endAdjust()
        workspace.adjust(.curvePoints([CurvePoint(x: 0, y: 0), CurvePoint(x: 0.5, y: 0.8), CurvePoint(x: 1, y: 1)]))
        workspace.endAdjust()
        workspace.undo()
        #expect(workspace.adjustments.curvePoints == Self.lift)
        #expect(workspace.undoActionName == "Undo Curves")
        workspace.undo()
        #expect(workspace.adjustments.curvePoints == Self.ends)
        #expect(workspace.undoActionName != "Undo Curves")
    }

    @Test func endAdjustMakesEachSliderRunItsOwnUndoStep() throws {
        var workspace = try grey()
        workspace.adjust(.exposure(0.5))
        workspace.adjust(.exposure(1))
        workspace.endAdjust()
        workspace.adjust(.exposure(2))
        workspace.undo()
        #expect(workspace.adjustments.exposure == 1)
        #expect(workspace.undoActionName == "Undo Exposure")
        workspace.undo()
        #expect(workspace.adjustments.exposure == 0)
    }

    @Test func histogramKeyMovesOnlyWithTheHistogramsInput() throws {
        var workspace = try grey()
        let key = workspace.curvesHistogramKey
        workspace.adjust(.curvePoints(Self.lift))
        workspace.adjust(.hue(40))
        workspace.adjust(.blurSigma(2))
        workspace.undo()
        #expect(workspace.curvesHistogramKey == key)
        workspace.adjust(.exposure(1))
        let exposed = workspace.curvesHistogramKey
        #expect(exposed != key)
        workspace.adjust(.setEnabled(.levels, false))
        #expect(workspace.curvesHistogramKey == exposed)
        workspace.adjust(.whitePoint(0.8))
        #expect(workspace.curvesHistogramKey == exposed)
        workspace.adjust(.setEnabled(.levels, true))
        #expect(workspace.curvesHistogramKey != exposed)
        let levelled = workspace.curvesHistogramKey
        addFilledLayer(&workspace, red: 10, green: 200, blue: 30)
        #expect(workspace.curvesHistogramKey != levelled)
    }
}
