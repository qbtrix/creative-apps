// SystemImageDecoderTests.swift: SystemImageDecoder reads TIFF and HEIC files the PNG and JPEG readers don't, top
// row first in straight-alpha sRGB, scales down to a longest side (never up) in whole pixels, reads a PNG as stored
// (every 8-bit value with alpha above 0 exactly as written), gives a file's size without decoding, and returns nil
// for bytes it can't read. Fixtures are drawn here with Core Image (a 4 x 2 image, blue on top, red below) or
// written as a raw PNG. On Linux the decoder reads nothing and has no extensions.
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

    /// A translucent PNG (every alpha from 1 to 255, any colour) reads back byte for byte as stored.
    @Test func aPNGReadsAsStored() throws {
        let (width, height) = (255, 64)
        var rgba = [UInt8](repeating: 0, count: width * height * 4), seed: UInt32 = 7
        for i in 0..<(width * height) {
            for c in 0..<3 {
                seed = seed &* 1_664_525 &+ 1_013_904_223
                rgba[i * 4 + c] = UInt8(truncatingIfNeeded: seed >> 24)
            }
            rgba[i * 4 + 3] = UInt8(i % width + 1)
        }
        let image = try #require(SystemImageDecoder.decode(Self.png(rgba, width, height), longestSide: nil, asStored: true))
        #expect(image.width == width && image.height == height)
        let differ = zip(image.rgba8, rgba).filter { $0 != $1 }.count
        #expect(differ == 0, "\(differ) bytes differ from the file")
    }

    @Test func aScaledReadIsWholePixels() throws {
        // Opaque grey: a scaled read keeps every edge pixel opaque.
        let rgba: [UInt8] = Array([[UInt8]](repeating: [200, 200, 200, 255], count: 3000 * 7).joined())
        let image = try #require(SystemImageDecoder.decode(Self.png(rgba, 3000, 7), longestSide: 1000, asStored: true))
        #expect(image.width == 1000 && image.height == 2, "\(image.width) x \(image.height)")
        #expect(image.rgba8[(image.width * image.height - 1) * 4 + 3] == 255, "the last pixel is clear")
    }

    @Test func aSizeIsReadWithoutDecoding() throws {
        let space = try #require(Self.space)
        let big = Self.blueOverRed().transformed(by: CGAffineTransform(scaleX: 16, y: 16))
        let heic = try #require(CIContext().heifRepresentation(of: big, format: .RGBA8, colorSpace: space))
        #expect(SystemImageDecoder.size(of: heic).map { [$0.width, $0.height] } == [64, 32])
        #expect(SystemImageDecoder.size(of: Data("not an image".utf8)) == nil)
    }

    /// An 8-bit RGBA PNG of `rgba`: filter 0, one stored (uncompressed) zlib block per 65535 bytes.
    static func png(_ rgba: [UInt8], _ width: Int, _ height: Int) -> Data {
        func be(_ v: Int) -> [UInt8] { (0..<4).map { UInt8(truncatingIfNeeded: v >> (24 - 8 * $0)) } }
        func crc(_ bytes: [UInt8]) -> UInt32 {
            var c = UInt32.max
            for b in bytes {
                c ^= UInt32(b)
                for _ in 0..<8 { c = c & 1 == 1 ? 0xEDB8_8320 ^ (c >> 1) : c >> 1 }
            }
            return c ^ UInt32.max
        }
        var raw = [UInt8]()
        for y in 0..<height { raw.append(0); raw += rgba[(y * width * 4)..<((y + 1) * width * 4)] }
        var zlib: [UInt8] = [0x78, 0x01], at = 0
        repeat {
            let n = min(65535, raw.count - at)
            zlib += [at + n == raw.count ? 1 : 0, UInt8(n & 0xFF), UInt8(n >> 8), UInt8(~n & 0xFF), UInt8((~n >> 8) & 0xFF)]
            zlib += raw[at..<(at + n)]
            at += n
        } while at < raw.count
        var (a, b): (UInt32, UInt32) = (1, 0)
        for x in raw { a = (a + UInt32(x)) % 65521; b = (b + a) % 65521 }
        zlib += be(Int(b << 16 | a))
        var out: [UInt8] = [137, 80, 78, 71, 13, 10, 26, 10]
        for (type, body) in [("IHDR", be(width) + be(height) + [8, 6, 0, 0, 0]), ("IDAT", zlib), ("IEND", [])] {
            let typed = Array(type.utf8) + body
            out += be(body.count) + typed + be(Int(crc(typed)))
        }
        return Data(out)
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
