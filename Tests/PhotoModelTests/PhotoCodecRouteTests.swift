// PhotoCodecRouteTests.swift (shared-codecs SC-3, MJ-SC-photo): `CoreRasterImageCodec` routes every PNG and JPEG
// to creative-core and nowhere else. A PNG core refuses is refused, not handed to a local fallback reader; PNG
// bytes are `PNG.write`'s; a JPEG is read by `JPEG.read` (not sniffed as a PNG) and turned upright by its Exif
// orientation; a broken file throws instead of decoding to an empty image. Black box through the
// `PhotoImageCodec` surface and core's public codecs, so the file compiled before SC-4 and runs after it.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster
import Testing
import PhotoModel

@Suite struct PhotoCodecRouteTests {
    let codec = CoreRasterImageCodec()

    /// 16 x 8 straight sRGB bytes: the left 8 columns red, the right 8 blue, opaque. Flat 8 x 8 blocks, so a
    /// JPEG keeps each half's colour away from the seam.
    static let halves: DecodedImage = {
        var out = [UInt8]()
        for _ in 0..<8 { for x in 0..<16 { out += x < 8 ? [220, 40, 40, 255] : [40, 60, 220, 255] } }
        return DecodedImage(rgba8: out, width: 16, height: 8)
    }()

    static func buffer(_ image: DecodedImage) throws -> PixelBuffer {
        try PixelBuffer(rgba8: image.rgba8, width: image.width, height: image.height)
    }

    /// `png` with a chunk of `type` holding `body` (and a correct CRC) put just before IEND.
    static func inserting(_ type: String, _ body: [UInt8], into png: Data) -> Data {
        var bytes = [UInt8](png)
        let typed = Array(type.utf8) + body
        let crc = typed.reduce(UInt32.max) { c, byte in
            (0..<8).reduce(c ^ UInt32(byte)) { r, _ in r & 1 == 1 ? 0xEDB8_8320 ^ (r >> 1) : r >> 1 }
        } ^ UInt32.max
        let chunk = bigEndian(UInt32(body.count)) + typed + bigEndian(crc)
        bytes.insert(contentsOf: chunk, at: max(bytes.count - 12, 0))
        return Data(bytes)
    }

    static func bigEndian(_ value: UInt32) -> [UInt8] { (0..<4).map { UInt8(truncatingIfNeeded: value >> (24 - 8 * $0)) } }

    /// `jpeg` with an Exif APP1 after its JFIF APP0 whose IFD0 holds only Orientation (0x0112, SHORT) = `orientation`.
    static func withOrientation(_ orientation: UInt8, _ jpeg: Data) -> Data {
        var bytes = [UInt8](jpeg)
        let tiff: [UInt8] = [0x4D, 0x4D, 0, 0x2A, 0, 0, 0, 8, 0, 1, 0x01, 0x12, 0, 3, 0, 0, 0, 1, 0, orientation, 0, 0,
                             0, 0, 0, 0]
        let payload = Array("Exif".utf8) + [0, 0] + tiff, length = payload.count + 2
        let app1: [UInt8] = [0xFF, 0xE1, UInt8(length >> 8), UInt8(length & 0xFF)] + payload
        let app0End = bytes.count > 5 && bytes[3] == 0xE0 ? 4 + (Int(bytes[4]) << 8 | Int(bytes[5])) : 2
        bytes.insert(contentsOf: app1, at: min(app0End, bytes.count))
        return Data(bytes)
    }

    @Test
    func aPNGCoreRefusesIsRefusedNotReadByAFallback() throws {
        let png = Self.inserting("QUUX", [1, 2, 3], into: try PNG.write(Self.buffer(Self.halves)))
        #expect(throws: CodecError.self) { try PNG.read(png) }
        #expect(throws: CodecError.self, "an unknown critical chunk is core's refusal, not a cue to read it another way") {
            try codec.decode(png, longestSide: nil)
        }
    }

    @Test
    func pngIsCoresBothWays() throws {
        let data = try codec.encode(Self.halves, as: .png, quality: 1)
        #expect(data == (try PNG.write(Self.buffer(Self.halves))), "the PNG is core's bytes")
        #expect(try codec.decode(data, longestSide: nil) == Self.halves)
        let deep = try PNG.write(Self.buffer(Self.halves), bitsPerChannel: 16)
        let core = try PNG.read(deep)
        #expect(try codec.decode(deep, longestSide: nil) == DecodedImage(rgba8: try core.rgba8(), width: core.width, height: core.height),
                "a 16-bit PNG, which only core reads, decodes as core decodes it")
    }

    @Test
    func aJPEGIsReadByCoresJPEGReader() throws {
        let jpeg = try JPEG.write(Self.buffer(Self.halves), quality: 90)
        let core = try JPEG.read(jpeg)
        let got = try codec.decode(jpeg, longestSide: nil)
        #expect(got == DecodedImage(rgba8: try core.rgba8(), width: core.width, height: core.height))
        #expect(try codec.decode(codec.encode(Self.halves, as: .jpeg, quality: 0.9), longestSide: nil).width == 16)
    }

    @Test
    func aJPEGWithExifOrientationSixDecodesUpright() throws {
        let jpeg = Self.withOrientation(6, try JPEG.write(Self.buffer(Self.halves), quality: 95))
        #expect(try JPEG.info(jpeg).orientation == 6, "the fixture carries orientation 6")
        let upright = try JPEG.read(jpeg).rotated(.degrees90)
        let got = try codec.decode(jpeg, longestSide: nil)
        #expect(got.width == 8, "shown 8 wide, not the stored 16")
        #expect(got.height == 16)
        #expect(got == DecodedImage(rgba8: try upright.rgba8(), width: 8, height: 16))
        let top = Array(got.rgba8[((2 * 8 + 4) * 4)..<((2 * 8 + 4) * 4 + 3)])
        let bottom = Array(got.rgba8[((13 * 8 + 4) * 4)..<((13 * 8 + 4) * 4 + 3)])
        #expect(top[0] > 180 && top[2] < 90, "the stored left (red) half is on top: \(top)")
        #expect(bottom[2] > 180 && bottom[0] < 90, "the stored right (blue) half is below: \(bottom)")
        let small = try codec.decode(jpeg, longestSide: 8)
        #expect(small.width == 4, "the shrink keeps the upright shape")
        #expect(small.height == 8)
    }

    @Test
    func aBrokenFileThrowsInsteadOfDecodingEmpty() throws {
        let png = try PNG.write(Self.buffer(Self.halves))
        var badCRC = [UInt8](png)
        badCRC[badCRC.count - 13] ^= 0xFF  // the last byte of IDAT's CRC, just before IEND
        let jpeg = try JPEG.write(Self.buffer(Self.halves), quality: 90)
        let broken: [(String, Data)] = [
            ("empty", Data()), ("not an image", Data([1, 2, 3, 4, 5, 6, 7, 8, 9])), ("a PNG cut short", png.prefix(40)),
            ("a PNG with a bad IDAT CRC", Data(badCRC)), ("a JPEG cut after its headers", jpeg.prefix(180)),
        ]
        for (name, data) in broken {
            #expect(throws: (any Error).self, "\(name) throws") { try codec.decode(data, longestSide: nil) }
        }
    }
}
