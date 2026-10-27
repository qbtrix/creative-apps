// RasterSize.swift: the suite's one PNG/JPEG pixel-size reader (#4913, lead.md rule 20). Every app's place adapter
// sizes a dropped picture through `SuiteImaging.rasterSize(of:)`, never its own header code. Linux-safe.
//   PNG goes through CoreRaster's `PNG.info` (IHDR, CRC checked).
//   JPEG walks the markers to the first frame header (SOFn) itself, because CoreRaster's `JPEG.info` is its
//   decoder's gate and refuses frames it can't decode (CMYK, 12-bit, lossless, arithmetic) that ImageIO draws.
//   If creative-core grows a lenient JPEG size call, this branch becomes one line to it.
// Sizes are as stored, before any EXIF rotation.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster
import SuiteKernel

extension SuiteImaging {
    /// A PNG's or JPEG's pixel size from its header, without decoding pixels; nil for anything else, a cut-off
    /// header, or a zero side.
    public static func rasterSize(of data: Data) -> Size? {
        if let png = try? PNG.info(data) { return Size(width: Double(png.width), height: Double(png.height)) }
        let b = [UInt8](data.prefix(1 << 20))
        guard b.count > 2, b[0] == 0xFF, b[1] == 0xD8 else { return nil }
        var at = 2
        while at + 3 < b.count {
            guard b[at] == 0xFF else { return nil }
            let marker = b[at + 1]
            if marker == 0xFF { at += 1; continue }
            if marker == 0x01 || (0xD0...0xD7).contains(marker) { at += 2; continue }
            if marker == 0xD9 || marker == 0xDA { return nil }
            let length = Int(b[at + 2]) << 8 | Int(b[at + 3])
            guard length >= 2, at + 2 + length <= b.count else { return nil }
            // SOF0...SOF15 except DHT (C4), JPG (C8) and DAC (CC): precision, height, width.
            if (0xC0...0xCF).contains(marker), ![0xC4, 0xC8, 0xCC].contains(marker) {
                guard length >= 7 else { return nil }
                let height = Int(b[at + 5]) << 8 | Int(b[at + 6]), width = Int(b[at + 7]) << 8 | Int(b[at + 8])
                return width > 0 && height > 0 ? Size(width: Double(width), height: Double(height)) : nil
            }
            at += 2 + length
        }
        return nil
    }
}
