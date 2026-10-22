// TinyPNG.swift: test support (shared-raw SR-1). Writes `p3-red-16.png`
// from the PNG specification (W3C, third edition): 8 x 8, 16-bit RGB, the
// left half pure Display P3 red (outside sRGB), the right half white, with
// core's Display P3 profile in an iCCP chunk. Every zlib stream is stored
// (deflate block type 0), so the bytes never depend on a compressor.
import CoreColor
import Foundation

enum TinyPNG {
    static let name = "p3-red-16.png"
    static let side = 8

    static func p3Red16() throws -> Data {
        var rows: [UInt8] = []
        for _ in 0..<side {
            rows.append(0)  // filter: none
            for x in 0..<side {
                let rgb: [UInt8] = x < side / 2 ? [0xFF, 0xFF, 0, 0, 0, 0] : Array(repeating: 0xFF, count: 6)
                rows += rgb
            }
        }
        let icc = [UInt8](try ColorProfile.displayP3.iccData())
        var out: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        out += chunk("IHDR", be(side, 4) + be(side, 4) + [16, 2, 0, 0, 0])
        out += chunk("iCCP", Array("Display P3".utf8) + [0, 0] + stored(icc))
        out += chunk("IDAT", stored(rows))
        out += chunk("IEND", [])
        return Data(out)
    }

    static func be(_ value: Int, _ size: Int) -> [UInt8] {
        (0..<size).reversed().map { UInt8(truncatingIfNeeded: value >> (8 * $0)) }
    }

    static func chunk(_ type: String, _ body: [UInt8]) -> [UInt8] {
        let typed = Array(type.utf8) + body
        return be(body.count, 4) + typed + be(Int(crc32(typed)), 4)
    }

    /// A zlib stream of stored deflate blocks (RFC 1950, RFC 1951 3.2.4).
    static func stored(_ data: [UInt8]) -> [UInt8] {
        var out: [UInt8] = [0x78, 0x01]
        var start = 0
        repeat {
            let end = min(start + 65535, data.count), length = end - start
            out += [end == data.count ? 1 : 0, UInt8(length & 0xFF), UInt8(length >> 8),
                    UInt8(~length & 0xFF), UInt8((~length >> 8) & 0xFF)]
            out += data[start..<end]
            start = end
        } while start < data.count
        var a = 1, b = 0
        for byte in data { a = (a + Int(byte)) % 65521; b = (b + a) % 65521 }
        return out + be(b << 16 | a, 4)
    }

    static func crc32(_ bytes: [UInt8]) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in bytes {
            crc ^= UInt32(byte)
            for _ in 0..<8 { crc = crc & 1 == 1 ? (crc >> 1) ^ 0xEDB8_8320 : crc >> 1 }
        }
        return ~crc
    }
}
