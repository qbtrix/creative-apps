// PhotoToneDisplayValuesTests.swift: Levels, Curves and the Curves histogram
// work on display (sRGB-encoded) values, so their numbers mean what the
// screen shows: a curve point at x 0.5 moves the grey that displays halfway
// between black and white, Levels' black point is a display value, and that
// grey sits in the histogram's middle bin. Read through the rendered sRGB
// bytes, as export and the canvas see them. Runs on Linux and macOS.
import CoreRaster
import PhotoModel
import Testing

@Suite struct PhotoToneDisplayValuesTests {
    /// An open 8 x 8 image filled with sRGB grey 128, which displays as 0.502.
    private func midGrey() throws -> PhotoWorkspace {
        var workspace = try whiteImage(8, 8)
        addFilledLayer(&workspace, red: 128, green: 128, blue: 128)
        return workspace
    }

    /// The rendered sRGB red byte of the canvas's top-left pixel.
    private func shownRed(_ workspace: PhotoWorkspace) throws -> UInt8 {
        try workspace.composite().rgba8()[0]
    }

    @Test func aMidtoneCurvePointAtAHalfLandsOnSRGBHalf() throws {
        var workspace = try midGrey()
        #expect(try shownRed(workspace) == 128)
        workspace.adjust(.curvePoints([CurvePoint(x: 0, y: 0), CurvePoint(x: 0.5, y: 0.7), CurvePoint(x: 1, y: 1)]))
        // 0.7 of the way up the display scale is byte 178.5; the point sits a hair below 128/255.
        #expect((178...180).contains(try shownRed(workspace)))
        // A point that keeps x 0.5 at 0.5 keeps the grey, however the rest bends.
        workspace.adjust(.curvePoints([CurvePoint(x: 0, y: 0), CurvePoint(x: 0.5, y: 0.5), CurvePoint(x: 0.8, y: 0.95), CurvePoint(x: 1, y: 1)]))
        #expect(try shownRed(workspace) == 128)
    }

    @Test func levelsBlackPointIsADisplayValue() throws {
        var workspace = try midGrey()
        workspace.adjust(.blackPoint(0.25))
        // (0.502 - 0.25) / 0.75 = 0.336 on the display scale: byte 86.
        #expect((85...87).contains(try shownRed(workspace)))
    }

    @Test func displayMidGreyFillsTheHistogramsMiddleBin() throws {
        let heights = try midGrey().curvesHistogram()
        #expect(heights.firstIndex(of: 1) == 128)
    }
}
