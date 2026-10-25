// CorePNGParityTests.swift (shared-codecs SC-1): the oracle for deleting the two hand-rolled PNG writers (Halo's
// `HaloFramePNG`, SC-11) and Photo's fallback reader and writer in `CoreRasterImageCodec` (SC-4). At the pinned
// creative-core, `PNG.write` and `PNG.read` round-trip 8-bit opaque (RGB) and translucent (RGBA) buffers, and
// `PNG.read` decodes what each local writer writes to the same pixels the local reader gives. PhotoModelTests
// can't link HaloModel, so HaloFramePNG's output is read from fixtures it wrote (`Fixtures/png-parity/`,
// `halo-*.png`, from `HaloFramePNG.fallback` over `Pattern.rgba8` at 7 x 5); `rgb8-filters.png` is an 8-bit
// colour-type-2 file whose rows use filters 0 to 4, the other form the local reader takes. Files by #filePath.
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

    /// HaloFramePNG's files (8-bit RGBA, filter 0, one IDAT) decode in core to the pixels it was given, and to
    /// exactly what Photo's local reader makes of them.
    @Test(arguments: [("halo-rgba8.png", false), ("halo-opaque8.png", true)])
    func coreReadsHaloFramePNG(name: String, opaque: Bool) throws {
        let file = try Self.fixture(name), expected = try Pattern.buffer(opaque: opaque)
        #expect(try PNG.info(file) == PNGInfo(width: 7, height: 5, bitDepth: 8, colorType: 6, interlaced: false))
        let core = try PNG.read(file)
        #expect(try core.rgba8() == expected.rgba8())
        #expect(core == expected)
        #expect(core == (try CoreRasterImageCodec.readPNG(file)))
    }

    /// `CoreRasterImageCodec.writePNG`'s output decodes in core to the buffer it wrote and to what the local
    /// reader reads.
    @Test(arguments: [true, false]) func coreReadsPhotoWritePNG(opaque: Bool) throws {
        let buffer = try Pattern.buffer(opaque: opaque)
        let file = try CoreRasterImageCodec.writePNG(buffer)
        let core = try PNG.read(file)
        #expect(try core.rgba8() == buffer.rgba8())
        #expect(core == buffer)
        #expect(core == (try CoreRasterImageCodec.readPNG(file)))
    }

    /// An 8-bit RGB file with every filter type reads in core as the opaque pattern, the same as the local reader.
    @Test func coreReadsRGB8WithEveryFilter() throws {
        let file = try Self.fixture("rgb8-filters.png")
        #expect(try PNG.info(file) == PNGInfo(width: 7, height: 5, bitDepth: 8, colorType: 2, interlaced: false))
        let core = try PNG.read(file)
        #expect(try core.rgba8() == Pattern.rgba8(opaque: true))
        #expect(core == (try CoreRasterImageCodec.readPNG(file)))
    }

    /// The fixtures are what the doc says: tiny, and Halo's are the fallback's form (one IDAT, filter 0 rows).
    @Test func haloFixturesAreFallbackShaped() throws {
        for name in ["halo-rgba8.png", "halo-opaque8.png"] {
            let bytes = [UInt8](try Self.fixture(name))
            #expect(bytes.count < 1024)
            let idat = [UInt8]("IDAT".utf8)
            let hits = (0...(bytes.count - 4)).filter { Array(bytes[$0..<($0 + 4)]) == idat }
            #expect(hits.count == 1, "\(name): one IDAT")
        }
    }
}
