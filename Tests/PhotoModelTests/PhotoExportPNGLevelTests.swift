// PhotoExportPNGLevelTests.swift: a headless PNG export is written at deflate level 1 (core's level 6 was most of a
// scale-2 export's time, creative-core #728) and stays lossless. Saves keep level 6; the byte-for-byte .ora and
// sample tests pin that side. Runs on Linux and macOS.
import CoreRaster
import Foundation
import PhotoModel
import SuiteKernel
import Testing

@Suite struct PhotoExportPNGLevelTests {
    @Test func aPNGExportIsLosslessAtLevelOne() throws {
        let (width, height) = (64, 48)
        var workspace = PhotoWorkspace()
        let bytes = PhotoBudgetTests.photoLike(width, height)
        try workspace.open(rgba8: bytes, width: width, height: height, name: "n.png")
        let data = try #require(try PhotoHeadless(workspace: workspace).export("png", options: .object([:])).first?.data)
        let decoded = try PhotoHeadless.codec.decode(data, longestSide: nil)
        #expect(decoded.rgba8 == bytes)
        let buffer = try PixelBuffer(rgba8: decoded.rgba8, width: width, height: height)
        #expect(data == (try PNG.write(buffer, level: 1)))
        #expect(data != (try PNG.write(buffer, level: 6)))
    }
}
