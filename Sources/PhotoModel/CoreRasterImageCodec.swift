// CoreRasterImageCodec.swift (adopt-command-catalog AC-p2): PhotoImageCodec over creative-core's PNG and JPEG
// codecs, for the headless document and Linux. Pixels cross as CoreRaster's premultiplied linear PixelBuffer, as
// core's codecs take them. Until core's PNG lands (IC-4/IC-5 at the pinned commit) a PNG falls back to the small
// reader and writer here (W3C PNG: 8-bit RGB or RGBA, no interlace, the five filters; zlib through core's
// Deflate and Inflate); JPEG refuses with core's reason until IC-jpeg. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster

/// PNG and JPEG through CoreRaster.
public struct CoreRasterImageCodec: PhotoImageCodec {
    /// Core's deflate level for PNG writes. Saves keep 6, so a saved file stays byte for byte; exports pass 1.
    public let pngLevel: Int
    public init(pngLevel: Int = 6) { self.pngLevel = pngLevel }

    public func decode(_ data: Data, longestSide: Int?) throws -> DecodedImage {
        var buffer = try Self.read(data)
        let longest = max(buffer.width, buffer.height)
        if let side = longestSide, side > 0, longest > side {
            let scale = Double(side) / Double(longest)
            buffer = try buffer.resized(width: max(Int((Double(buffer.width) * scale).rounded()), 1),
                                        height: max(Int((Double(buffer.height) * scale).rounded()), 1), filter: .bilinear)
        }
        return DecodedImage(rgba8: try buffer.rgba8(), width: buffer.width, height: buffer.height)
    }

    public func encode(_ image: DecodedImage, as format: ImageFormat, quality: Double) throws -> Data {
        try encode(buffer: PixelBuffer(rgba8: image.rgba8, width: image.width, height: image.height), as: format, quality: quality)
    }

    /// `buffer` as `format`, straight to core's encoder: no 8-bit round trip on the way in.
    public func encode(buffer: PixelBuffer, as format: ImageFormat, quality: Double) throws -> Data {
        switch format {
        case .jpeg: return try JPEG.write(buffer, quality: Int((min(max(quality, 0), 1) * 100).rounded()))
        case .png:
            do { return try PNG.write(buffer, level: pngLevel) } catch CodecError.unsupported { return try Self.writePNG(buffer) }
        }
    }

    static let signature: [UInt8] = [137, 80, 78, 71, 13, 10, 26, 10]

    /// `data` as a premultiplied linear buffer: core's PNG, then this file's, for a PNG; core's JPEG otherwise.
    static func read(_ data: Data) throws -> PixelBuffer {
        guard data.starts(with: signature) else { return try JPEG.read(data) }
        do { return try PNG.read(data) } catch CodecError.unsupported { return try readPNG(data) }
    }

    /// `buffer` as an 8-bit RGBA PNG: straight sRGB rows, filter 0, one IDAT.
    static func writePNG(_ buffer: PixelBuffer) throws -> Data {
        let rgba = try buffer.rgba8(), stride = buffer.width * 4
        var raw = [UInt8](), out = signature
        raw.reserveCapacity(buffer.height * (stride + 1))
        for y in 0..<buffer.height { raw.append(0); raw += rgba[(y * stride)..<((y + 1) * stride)] }
        func chunk(_ type: String, _ body: [UInt8]) {
            let typed = Array(type.utf8) + body
            out += bigEndian(body.count) + typed + bigEndian(Int(crc32(typed)))
        }
        chunk("IHDR", bigEndian(buffer.width) + bigEndian(buffer.height) + [8, 6, 0, 0, 0])
        chunk("IDAT", [UInt8](Deflate.zlib(Data(raw))))
        chunk("IEND", [])
        return Data(out)
    }

    /// An 8-bit RGB or RGBA, non-interlaced PNG; `CodecError` for anything else or a broken file.
    static func readPNG(_ data: Data) throws -> PixelBuffer {
        let b = [UInt8](data)
        func be(_ at: Int) -> Int { b[at..<(at + 4)].reduce(0) { $0 << 8 | Int($1) } }
        var at = 8, idat = [UInt8](), width = 0, height = 0, channels = 0
        while at + 12 <= b.count {
            let length = be(at), type = String(decoding: b[(at + 4)..<(at + 8)], as: UTF8.self)
            guard length >= 0, at + 12 + length <= b.count else { throw CodecError.damaged("a chunk runs past the end") }
            if type == "IHDR", length == 13 {
                (width, height) = (be(at + 8), be(at + 12))
                let form = Array(b[(at + 16)..<(at + 21)])
                guard form == [8, 6, 0, 0, 0] || form == [8, 2, 0, 0, 0] else {
                    throw CodecError.unsupported("PNG depth, colour type or interlace \(form) waits on IC-4")
                }
                channels = form[1] == 6 ? 4 : 3
            }
            if type == "IDAT" { idat += b[(at + 8)..<(at + 8 + length)] }
            at += 12 + length
        }
        guard channels > 0, (1...PNG.maxSide).contains(width), (1...PNG.maxSide).contains(height) else {
            throw CodecError.damaged("no usable IHDR")
        }
        let stride = width * channels, raw = [UInt8](try Inflate.zlib(Data(idat), limit: height * (stride + 1)))
        guard raw.count == height * (stride + 1) else { throw CodecError.damaged("the image data is short") }
        var rows = [UInt8](repeating: 0, count: height * stride)
        for y in 0..<height {
            let filter = raw[y * (stride + 1)], row = y * stride, src = y * (stride + 1) + 1
            guard filter <= 4 else { throw CodecError.damaged("filter type \(filter)") }
            for x in 0..<stride {
                let a = x >= channels ? Int(rows[row + x - channels]) : 0, up = y > 0 ? Int(rows[row - stride + x]) : 0
                let c = x >= channels && y > 0 ? Int(rows[row - stride + x - channels]) : 0
                let p = a + up - c, (pa, pb, pc) = (abs(p - a), abs(p - up), abs(p - c))
                let predictor = switch filter {
                case 1: a
                case 2: up
                case 3: (a + up) / 2
                case 4: pa <= pb && pa <= pc ? a : (pb <= pc ? up : c)
                default: 0
                }
                rows[row + x] = UInt8(truncatingIfNeeded: Int(raw[src + x]) + predictor)
            }
        }
        var rgba = rows
        if channels == 3 {
            rgba = [UInt8](repeating: 255, count: width * height * 4)
            for i in 0..<(width * height) { rgba[(i * 4)..<(i * 4 + 3)] = rows[(i * 3)..<(i * 3 + 3)] }
        }
        return try PixelBuffer(rgba8: rgba, width: width, height: height)
    }

    static func bigEndian(_ value: Int) -> [UInt8] { (0..<4).map { UInt8(truncatingIfNeeded: value >> (24 - 8 * $0)) } }

    static let crcTable: [UInt32] = (0..<256).map { n in
        (0..<8).reduce(UInt32(n)) { c, _ in c & 1 == 1 ? 0xEDB8_8320 ^ (c >> 1) : c >> 1 }
    }

    /// The PNG chunk CRC (ISO 3309, as the W3C PNG spec's annex D gives it).
    static func crc32(_ bytes: [UInt8]) -> UInt32 {
        bytes.reduce(UInt32.max) { crcTable[Int(($0 ^ UInt32($1)) & 0xFF)] ^ ($0 >> 8) } ^ UInt32.max
    }
}
