// CorePNGParityTests.swift (shared-codecs SC-1, SC-11): the oracle for the suite's PNG on core. At the pinned
// creative-core, `PNG.write` and `PNG.read` round-trip 8-bit opaque (RGB) and translucent (RGBA) buffers, and
// `PNG.read` decodes the golden files to the pattern they were written from. The golden files (`Fixtures/png-parity/`):
// `halo-*.png` are 8-bit RGBA, filter 0 rows in one IDAT, over `Pattern.rgba8` at 7 x 5 (written by Halo's old frame
// writer, deleted in SC-11); `rgb8-filters.png` is an 8-bit colour-type-2 file whose rows use filters 0 to 4. Files
// by #filePath.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster
import Testing
@testable import PhotoModel

@Suite struct CorePNGParityTests {
    /// The fixtures' pixels: straight sRGB RGBA bytes, alpha cycling through 0, 1, 64, 128, 200, 254 and 255
    /// unless `opaque`.
    enum Pattern {
        static let width = 7, height = 5
        static func rgba8(opaque: Bool) -> [UInt8] {
            let alphas: [UInt8] = [0, 1, 64, 128, 200, 254, 255]
            var out = [UInt8]()
            for y in 0..<height {
                for x in 0..<width {
                    out += [UInt8((x * 53 + y * 17) & 255), UInt8((x * 29 + y * 91 + 7) & 255),
                            UInt8((x * x * 5 + y * 123) & 255), opaque ? 255 : alphas[(x + y * 3) % alphas.count]]
                }
            }
            return out
        }
        static func buffer(opaque: Bool) throws -> PixelBuffer {
            try PixelBuffer(rgba8: rgba8(opaque: opaque), width: width, height: height)
        }
    }

    static let fixtures = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .appendingPathComponent("Fixtures").appendingPathComponent("png-parity")
    static func fixture(_ name: String) throws -> Data { try Data(contentsOf: fixtures.appendingPathComponent(name)) }

    /// Core writes an opaque and a translucent 8-bit buffer and reads back the same pixels, as 8-bit RGBA.
    @Test(arguments: [true, false]) func coreRoundTrips8Bit(opaque: Bool) throws {
        let buffer = try Pattern.buffer(opaque: opaque)
        let file = try PNG.write(buffer)
        #expect(try PNG.info(file) == PNGInfo(width: 7, height: 5, bitDepth: 8, colorType: 6, interlaced: false))
        let back = try PNG.read(file)
        #expect(try back.rgba8() == buffer.rgba8())
        #expect(back == buffer)
    }

/// The golden RGBA files (8-bit RGBA, filter 0, one IDAT) decode in core to the pattern, and to what core makes of
    /// its own `PNG.write` of that pattern.
    @Test(arguments: [("halo-rgba8.png", false), ("halo-opaque8.png", true)])
    func coreReadsGoldenRGBA8(name: String, opaque: Bool) throws {
        let file = try Self.fixture(name), expected = try Pattern.buffer(opaque: opaque)
        #expect(try PNG.info(file) == PNGInfo(width: 7, height: 5, bitDepth: 8, colorType: 6, interlaced: false))
        let core = try PNG.read(file)
        #expect(try core.rgba8() == expected.rgba8())
        #expect(core == expected)
        #expect(core == (try PNG.read(try PNG.write(expected, bitsPerChannel: 8))))
    }

    /// An 8-bit RGB file with every filter type reads in core as the opaque pattern.
    @Test func coreReadsRGB8WithEveryFilter() throws {
        let file = try Self.fixture("rgb8-filters.png")
        #expect(try PNG.info(file) == PNGInfo(width: 7, height: 5, bitDepth: 8, colorType: 2, interlaced: false))
        let core = try PNG.read(file)
        #expect(try core.rgba8() == Pattern.rgba8(opaque: true))
    }

    /// The fixtures are what the doc says: tiny, and the RGBA goldens are the one-IDAT, filter 0 form (one IDAT, filter 0 rows).
    @Test func rgbaGoldensAreOneIDATFiles() throws {
        for name in ["halo-rgba8.png", "halo-opaque8.png"] {
            let bytes = [UInt8](try Self.fixture(name))
            #expect(bytes.count < 1024)
            let idat = [UInt8]("IDAT".utf8)
            let hits = (0...(bytes.count - 4)).filter { Array(bytes[$0..<($0 + 4)]) == idat }
            #expect(hits.count == 1, "\(name): one IDAT")
        }
    }
}
