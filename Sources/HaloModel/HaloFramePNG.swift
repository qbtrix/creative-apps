// HaloFramePNG.swift (adopt-command-catalog AC-h2): the PNG bytes of one rendered frame on every platform. Core's
// `PNG.write` throws `unsupported` at the pinned commit (IC-5), so until it lands the frame is written here as the W3C
// PNG spec gives it: an 8-bit RGBA IHDR, every row with filter 0, one zlib IDAT through core's `Deflate`, then IEND,
// each chunk with its CRC (annex D). Linux-safe: no UI imports.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster

/// A rendered frame as a PNG file.
enum HaloFramePNG {
    /// `pixels` as a PNG: core's writer when it has one, this file's 8-bit RGBA writer while it refuses.
    static func data(_ pixels: PixelBuffer) throws -> Data {
        do { return try PNG.write(pixels) } catch CodecError.unsupported { return try fallback(pixels) }
    }

    /// `pixels` as straight sRGB RGBA rows, filter 0, in one IDAT.
    static func fallback(_ pixels: PixelBuffer) throws -> Data {
        let rgba = try pixels.rgba8(), rowBytes = pixels.width * 4
        var scanlines = [UInt8]()
        scanlines.reserveCapacity(pixels.height * (rowBytes + 1))
        for row in 0..<pixels.height {
            scanlines.append(0)
            scanlines.append(contentsOf: rgba[(row * rowBytes)..<((row + 1) * rowBytes)])
        }
        let header = word(pixels.width) + word(pixels.height) + [8, 6, 0, 0, 0]
        let file: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
            + chunk("IHDR", header) + chunk("IDAT", [UInt8](Deflate.zlib(Data(scanlines)))) + chunk("IEND", [])
        return Data(file)
    }

    /// One chunk: its length, its type and body, and the CRC of type and body.
    static func chunk(_ type: String, _ body: [UInt8]) -> [UInt8] {
        let tagged = [UInt8](type.utf8) + body
        return word(body.count) + tagged + word(Int(checksum(tagged)))
    }

    /// `value`'s low 32 bits, most significant byte first.
    static func word(_ value: Int) -> [UInt8] { [24, 16, 8, 0].map { UInt8(truncatingIfNeeded: value >> $0) } }

    /// The PNG chunk CRC-32 (polynomial 0xEDB88320, reflected), bit by bit.
    static func checksum(_ bytes: [UInt8]) -> UInt32 {
        var crc = UInt32.max
        for byte in bytes {
            crc ^= UInt32(byte)
            for _ in 0..<8 { crc = crc & 1 == 0 ? crc >> 1 : (crc >> 1) ^ 0xEDB8_8320 }
        }
        return ~crc
    }
}
