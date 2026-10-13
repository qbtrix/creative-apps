// PhotoExportTests.swift: export as PNG or JPEG (#196), and opening a file's
// bytes (#190). Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster
import PhotoModel
import Testing

@Suite struct PhotoExportTests {
    /// 2x1: opaque red, then fully transparent.
    private func redThenClear() throws -> PhotoWorkspace {
        var workspace = PhotoWorkspace()
        try workspace.open(rgba8: [255, 0, 0, 255, 0, 0, 0, 0], width: 2, height: 1, name: "two.png")
        return workspace
    }

    @Test func pngKeepsTransparencyAndJpegLiesOnWhite() throws {
        let workspace = try redThenClear()
        #expect(try workspace.exportPixels(as: .png).rgba8 == [255, 0, 0, 255, 0, 0, 0, 0])
        #expect(try workspace.exportPixels(as: .jpeg).rgba8 == [255, 0, 0, 255, 255, 255, 255, 255])
    }

    @Test func aHiddenLayerIsNotExported() throws {
        var workspace = try redThenClear()
        addFilledLayer(&workspace, red: 0, green: 255, blue: 0)
        workspace.toggleVisibility(try #require(workspace.selectedLayerID))
        #expect(try workspace.exportPixels(as: .png).rgba8 == [255, 0, 0, 255, 0, 0, 0, 0])
    }

    @Test func exportingWithNoImageThrows() {
        #expect(throws: RasterError.self) { try PhotoWorkspace().exportPixels(as: .png) }
    }

    @Test func exportGoesThroughTheCodecWithTheQuality() async throws {
        let data = try await redThenClear().export(as: .jpeg, quality: 0.8, codec: RawCodec())
        #expect([UInt8](data) == [0, 2, 0, 1, 2, 80, 0, 0, 255, 0, 0, 255, 255, 255, 255, 255])
    }

    @Test func aParallelExportMatchesTheFlatOne() async throws {
        var workspace = try whiteImage(300, 280)
        stroke(&workspace, .eraser, from: point(10, 10), to: point(290, 270))
        for format in ImageFormat.allCases {
            let data = try await workspace.export(as: format, codec: RawCodec())
            #expect(Array([UInt8](data)[8...]) == (try workspace.exportPixels(as: format)).rgba8)
        }
    }

    @Test func formatsFromFileNames() {
        #expect(ImageFormat(fileName: "a.PNG") == .png)
        #expect(ImageFormat(fileName: "beach.jpeg") == .jpeg)
        #expect(ImageFormat(fileName: "photo.JPG") == .jpeg)
        #expect(ImageFormat(fileName: "scan.heic") == nil)
        #expect(ImageFormat.jpeg.fileExtension == "jpg")
    }

    @Test func openingBytesMakesOneBackgroundLayer() throws {
        var workspace = try whiteImage(4, 4)
        workspace.adjust(.exposure(1))
        try workspace.open(rgba8: [255, 0, 0, 255, 0, 0, 255, 128], width: 2, height: 1, name: "beach.png")
        #expect(workspace.canvas == CanvasSize(width: 2, height: 1))
        #expect(try canvasPixel(workspace, 0, 0) == RGBA(r: 1, g: 0, b: 0, a: 1))
        #expect(abs(try canvasPixel(workspace, 1, 0).a - 128.0 / 255) < 1e-3)
        #expect(workspace.layers.map(\.name) == ["Background"])
        #expect(workspace.selectedLayer?.name == "Background")
        #expect(workspace.documentName == "beach.png")
        #expect(workspace.adjustments == AdjustmentSettings())
        #expect(!workspace.canUndo)
    }

    @Test func aBadByteCountThrowsAndKeepsTheOpenImage() throws {
        var workspace = try whiteImage(4, 4)
        let before = workspace
        #expect(throws: RasterError.self) {
            try workspace.open(rgba8: [1, 2, 3, 4, 5, 6, 7], width: 2, height: 1, name: "bad.png")
        }
        #expect(workspace == before)
    }

    @Test func openingAFileGoesThroughTheCodec() throws {
        var workspace = PhotoWorkspace()
        try workspace.open(Data([0, 1, 0, 1, 0, 0, 0, 0, 10, 20, 30, 255]), name: "one.raw", codec: RawCodec())
        #expect(workspace.canvas == CanvasSize(width: 1, height: 1))
        #expect(try workspace.exportPixels(as: .png).rgba8 == [10, 20, 30, 255])
        #expect(throws: RawCodec.Unreadable.self) { try workspace.open(Data([1]), name: "x", codec: RawCodec()) }
        #expect(workspace.documentName == "one.raw")
    }

    @Test func bigPhotosDecodeSmaller() {
        #expect(PhotoWorkspace.decodeLongestSide(width: 4000, height: 3000) == nil)
        // 48 MP at 4:3 keeps 16 MP: 4729 x 3547.
        let side = PhotoWorkspace.decodeLongestSide(width: 8000, height: 6000)
        #expect(side == 4729)
        #expect(PhotoWorkspace.decodeLongestSide(width: 0, height: 10) == nil)
    }
}
