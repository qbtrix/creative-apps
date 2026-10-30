// SystemImageDecoderTests.swift: SystemImageDecoder reads TIFF and HEIC files the PNG and JPEG readers don't, top
// row first in straight-alpha sRGB, scales down to a longest side (never up), and returns nil for bytes it can't
// read. Fixtures are drawn here with Core Image: a 4 x 2 image, blue on top, red below. On Linux the decoder reads
// nothing and has no extensions.
#if canImport(CoreImage)
import CoreImage
#endif
import Foundation
import SuiteImaging
import Testing

@Suite struct SystemImageDecoderTests {
    #if canImport(CoreImage)
    /// Blue over red, 4 x 2 (Core Image's y runs up, so the blue row is y 1).
    static func blueOverRed() -> CIImage {
        let red = CIImage(color: CIColor(red: 1, green: 0, blue: 0)).cropped(to: CGRect(x: 0, y: 0, width: 4, height: 1))
        let blue = CIImage(color: CIColor(red: 0, green: 0, blue: 1)).cropped(to: CGRect(x: 0, y: 1, width: 4, height: 1))
        return blue.composited(over: red)
    }

    static let space = CGColorSpace(name: CGColorSpace.sRGB)

    /// The RGB of pixel (x, y), y 0 the top row.
    static func rgb(_ image: (rgba8: [UInt8], width: Int, height: Int), _ x: Int, _ y: Int) -> [UInt8] {
        let at = (y * image.width + x) * 4
        return Array(image.rgba8[at..<at + 3])
    }

    @Test func aTIFFReadsTopRowFirst() throws {
        let space = try #require(Self.space)
        let tiff = try #require(CIContext().tiffRepresentation(of: Self.blueOverRed(), format: .RGBA8, colorSpace: space))
        let image = try #require(SystemImageDecoder.decode(tiff, longestSide: nil), "the TIFF didn't decode")
        #expect(image.width == 4 && image.height == 2)
        #expect(Self.rgb(image, 0, 0) == [0, 0, 255], "the top row isn't blue: \(Self.rgb(image, 0, 0))")
        #expect(Self.rgb(image, 3, 1) == [255, 0, 0], "the bottom row isn't red: \(Self.rgb(image, 3, 1))")
        #expect(image.rgba8[3] == 255)
    }

    @Test func aHEICReads() throws {
        let space = try #require(Self.space)
        let big = Self.blueOverRed().transformed(by: CGAffineTransform(scaleX: 16, y: 16))
        let heic = try #require(CIContext().heifRepresentation(of: big, format: .RGBA8, colorSpace: space))
        let image = try #require(SystemImageDecoder.decode(heic, longestSide: nil), "the HEIC didn't decode")
        #expect(image.width == 64 && image.height == 32)
        let top = Self.rgb(image, 32, 4), bottom = Self.rgb(image, 32, 28)
        #expect(top[2] > 200 && top[0] < 50, "the top isn't blue: \(top)")
        #expect(bottom[0] > 200 && bottom[2] < 50, "the bottom isn't red: \(bottom)")
    }

    @Test func aLongestSideScalesDownNeverUp() throws {
        let space = try #require(Self.space)
        let big = Self.blueOverRed().transformed(by: CGAffineTransform(scaleX: 25, y: 25))
        let tiff = try #require(CIContext().tiffRepresentation(of: big, format: .RGBA8, colorSpace: space))
        let half = try #require(SystemImageDecoder.decode(tiff, longestSide: 50))
        #expect(half.width == 50 && half.height == 25)
        let whole = try #require(SystemImageDecoder.decode(tiff, longestSide: 400))
        #expect(whole.width == 100 && whole.height == 50, "scaled up")
    }

    @Test func extensionsNameWhatItReads() {
        #expect(SystemImageDecoder.extensions.isSuperset(of: ["heic", "tiff", "psd"]))
    }
    #endif

    @Test func bytesThatArentAnImageAreNil() {
        #expect(SystemImageDecoder.decode(Data("not an image".utf8), longestSide: nil) == nil)
        #if !canImport(CoreImage)
        #expect(SystemImageDecoder.extensions.isEmpty)
        #endif
    }
}
