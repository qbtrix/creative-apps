// FakeThumbnails.swift: the in-memory ThumbnailPublishing (UC-15). Writes
// `thumbnails/<SuiteDocumentRef.fileKey(fileID)>.png` (packet correction 1:
// a file id has slashes, so it never names a file). With `unavailable:` set,
// `publish` throws `.notAvailable(that sentence)` and `preview` is nil.
// `seeded:` refs start with a fixture preview (`fixturePNG(for:)`, a valid
// 1x1 PNG whose colour comes from the ref's file key), so a home or grid test
// has pictures without publishing first (shared-thumbnails ST-2).
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public actor FakeThumbnails: ThumbnailPublishing {
    public private(set) var written: [String: Data] = [:]
    let unavailable: String?
    public init(unavailable: String? = nil, seeded: [SuiteDocumentRef] = []) {
        self.unavailable = unavailable
        for ref in seeded { written[Self.path(for: ref)] = Self.fixturePNG(for: ref) }
    }

    public func publish(png: Data, for ref: SuiteDocumentRef) throws(SuiteError) -> String {
        if let unavailable { throw .notAvailable(unavailable) }
        let path = Self.path(for: ref)
        written[path] = png
        return path
    }

    public func preview(for ref: SuiteDocumentRef) -> Data? {
        if unavailable != nil { return nil }
        return written[Self.path(for: ref)]
    }

    static func path(for ref: SuiteDocumentRef) -> String { "thumbnails/\(SuiteDocumentRef.fileKey(ref.fileID)).png" }

    /// A valid 1x1 RGB PNG for `ref`: the same bytes every run, one colour per file key.
    public static func fixturePNG(for ref: SuiteDocumentRef) -> Data {
        let hash = SuiteDocumentRef.fileKey(ref.fileID).utf8.reduce(UInt32(2_166_136_261)) { ($0 ^ UInt32($1)) &* 16_777_619 }
        let raw: [UInt8] = [0] + Array(bigEndian(hash).dropFirst())  // filter byte "none", then one RGB pixel
        // zlib: header, one stored block (final, length, its complement), the bytes, Adler-32.
        let length = UInt16(raw.count)
        var zlib: [UInt8] = [0x78, 0x01, 0x01, UInt8(length & 0xff), UInt8(length >> 8), UInt8(~length & 0xff), UInt8(~length >> 8)]
        zlib += raw + bigEndian(adler32(raw))
        var png: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        png += chunk("IHDR", bigEndian(1) + bigEndian(1) + [8, 2, 0, 0, 0])
        png += chunk("IDAT", zlib)
        png += chunk("IEND", [])
        return Data(png)
    }

    private static func chunk(_ type: String, _ body: [UInt8]) -> [UInt8] {
        let tagged = Array(type.utf8) + body
        return bigEndian(UInt32(body.count)) + tagged + bigEndian(crc32(tagged))
    }

    private static func bigEndian(_ value: UInt32) -> [UInt8] {
        [UInt8(value >> 24 & 0xff), UInt8(value >> 16 & 0xff), UInt8(value >> 8 & 0xff), UInt8(value & 0xff)]
    }

    private static func adler32(_ bytes: [UInt8]) -> UInt32 {
        var a: UInt32 = 1, b: UInt32 = 0
        for byte in bytes { a = (a + UInt32(byte)) % 65_521; b = (b + a) % 65_521 }
        return b << 16 | a
    }

    private static func crc32(_ bytes: [UInt8]) -> UInt32 {
        var crc: UInt32 = 0xffff_ffff
        for byte in bytes {
            crc ^= UInt32(byte)
            for _ in 0..<8 { crc = crc & 1 == 1 ? 0xedb8_8320 ^ (crc >> 1) : crc >> 1 }
        }
        return ~crc
    }
}
