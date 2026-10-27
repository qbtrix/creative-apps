// RasterSizeTests.swift: `SuiteImaging.rasterSize(of:)`, the suite's one PNG/JPEG pixel-size reader (#4913).
// JPEGs are hand-built marker segments (SOI, segments, EOI): no scan data is needed for a size, and a 4-component
// (CMYK) frame, which CoreRaster's decoder refuses, still reads.
import Foundation
import SuiteImaging
import SuiteKernel
import Testing

@Suite struct RasterSizeTests {
    /// A marker segment: 0xFF, `marker`, the big-endian length (body plus its two bytes), then `body`.
    static func segment(_ marker: UInt8, _ body: [UInt8]) -> [UInt8] {
        [0xFF, marker] + TinyPNG.be(body.count + 2, 2) + body
    }

    /// A frame header (SOFn) for `width` x `height` with `components` components, each 1x1 on table 0.
    static func frame(_ marker: UInt8, width: Int, height: Int, components: Int) -> [UInt8] {
        segment(marker, [8] + TinyPNG.be(height, 2) + TinyPNG.be(width, 2) + [UInt8(components)]
                + (1...components).flatMap { [UInt8($0), 0x11, 0] })
    }

    static func jpeg(_ segments: [UInt8]...) -> Data { Data([0xFF, 0xD8] + segments.flatMap { $0 } + [0xFF, 0xD9]) }

    /// A Huffman table segment (one DC code), the marker a careless SOFn check mistakes for a frame.
    static let dht = segment(0xC4, [0x00, 1] + [UInt8](repeating: 0, count: 15) + [0])
    /// An APP1 (EXIF) segment whose payload holds a stray SOF0 for 9 x 9, which a length-skipping reader never sees.
    static let app1 = segment(0xE1, Array("Exif".utf8) + [0, 0] + frame(0xC0, width: 9, height: 9, components: 3))

    @Test func readsAPNGsIHDR() throws {
        #expect(SuiteImaging.rasterSize(of: try TinyPNG.p3Red16()) == Size(width: 8, height: 8))
    }

    @Test func readsABaselineJPEG() {
        let data = Self.jpeg(Self.app1, Self.dht, Self.frame(0xC0, width: 640, height: 480, components: 3))
        #expect(SuiteImaging.rasterSize(of: data) == Size(width: 640, height: 480))
    }

    @Test func readsAProgressiveJPEG() {
        let data = Self.jpeg(Self.dht, Self.frame(0xC2, width: 1200, height: 800, components: 3))
        #expect(SuiteImaging.rasterSize(of: data) == Size(width: 1200, height: 800))
    }

    @Test func readsACMYKJPEG() {
        let data = Self.jpeg(Self.frame(0xC0, width: 300, height: 200, components: 4))
        #expect(SuiteImaging.rasterSize(of: data) == Size(width: 300, height: 200))
    }

    @Test func aTruncatedFileHasNoSize() throws {
        let png = try TinyPNG.p3Red16(), jpeg = Self.jpeg(Self.frame(0xC0, width: 640, height: 480, components: 3))
        #expect(SuiteImaging.rasterSize(of: png.prefix(20)) == nil)
        #expect(SuiteImaging.rasterSize(of: jpeg.prefix(8)) == nil)
        #expect(SuiteImaging.rasterSize(of: Self.jpeg(Self.dht)) == nil)
    }

    @Test func aNonImageHasNoSize() {
        #expect(SuiteImaging.rasterSize(of: Data("<svg xmlns=\"http://www.w3.org/2000/svg\"/>".utf8)) == nil)
        #expect(SuiteImaging.rasterSize(of: Data()) == nil)
        #expect(SuiteImaging.rasterSize(of: Self.jpeg(Self.frame(0xC0, width: 0, height: 480, components: 3))) == nil)
    }
}
