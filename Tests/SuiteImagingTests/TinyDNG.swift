// TinyDNG.swift: test support (shared-raw SR-1). Writes the tiny DNGs under
// Fixtures/raw/ from Adobe's published DNG specification (1.4 tags, TIFF 6
// layout, little-endian), uncompressed. IFD0 is a 32 x 24 8-bit RGB preview
// (NewSubFileType 1) filled with a marker colour the raw data doesn't hold;
// its one SubIFD is the 64 x 48 16-bit raw data, an RGGB mosaic
// (`tiny-bayer.dng`) or LinearRaw RGB (`tiny-linear.dng`, SR-4's fallback).
// Both carry Orientation 6, BaselineExposure 1.0, AsShotNeutral 1 1 1, an
// sRGB D65 ColorMatrix1 and UniqueCameraModel "AfterGlow Test". The scene is
// neutral: a grey ramp and two highlight patches at 0.70 and 0.90 of white.
// Tests load the committed files by `#filePath` (`fixture(_:)`); SuiteImagingTests
// declares no resources.
import Foundation

enum TinyDNG {
    struct Spec: Sendable {
        var name: String
        /// An RGGB mosaic; false writes LinearRaw RGB.
        var cfa: Bool
        static let bayer = Spec(name: "tiny-bayer.dng", cfa: true)
        static let linear = Spec(name: "tiny-linear.dng", cfa: false)
    }
    static let notRawName = "not-raw.nef"
    /// A file named like a RAW file that isn't one.
    static let notRaw = Data("not a raw file".utf8)
    static let camera = "AfterGlow Test"
    /// The raw data's size and the preview's, as stored (before Orientation 6).
    static let width = 64, height = 48, previewWidth = 32, previewHeight = 24
    /// The preview's fill, magenta, which the neutral raw data never holds.
    static let marker: [UInt8] = [255, 0, 255]
    /// The two 16 x 16 highlight patches: top-left corners, stored, and their level.
    static let patches: [(x: Int, y: Int)] = [(8, 8), (40, 8)]
    static let highlights: [Double] = [0.70, 0.90]

    static func fixture(_ name: String) -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures").appendingPathComponent("raw").appendingPathComponent(name)
    }

    /// The scene at a stored pixel as a fraction of white: a patch's level, or
    /// the ramp from 0 to 0.5 left to right, one level per two columns.
    static func scene(x: Int, y: Int) -> Double {
        for (p, level) in zip(patches, highlights) where (p.x..<p.x + 16).contains(x) && (p.y..<p.y + 16).contains(y) {
            return level
        }
        return 0.5 * Double(x / 2) / Double(width / 2 - 1)
    }

    static func write(_ spec: Spec) -> Data {
        let samples = spec.cfa ? 1 : 3
        var raw: [UInt8] = []
        for y in 0..<height {
            for x in 0..<width {
                let v = UInt16((scene(x: x, y: y) * 65535).rounded())
                for _ in 0..<samples { raw += [UInt8(v & 0xFF), UInt8(v >> 8)] }
            }
        }
        let preview = (0..<previewWidth * previewHeight).flatMap { _ in marker }
        // Pointer values don't change a layout's size, so lay out once with zeros, then for real.
        func layout(_ sub: Int, _ previewAt: Int, _ rawAt: Int) -> (ifd0: [UInt8], ifd1: [UInt8]) {
            let ifd0 = IFD.encode(previewTags(sub: sub, strip: previewAt, bytes: preview.count), at: 8)
            return (ifd0, IFD.encode(rawTags(spec, strip: rawAt, bytes: raw.count), at: 8 + ifd0.count))
        }
        let sizes = layout(0, 0, 0)
        let sub = 8 + sizes.ifd0.count, previewAt = sub + sizes.ifd1.count
        let (ifd0, ifd1) = layout(sub, previewAt, previewAt + preview.count)
        return Data([0x49, 0x49, 42, 0] + IFD.le(8, 4) + ifd0 + ifd1 + preview + raw)
    }

    static func previewTags(sub: Int, strip: Int, bytes: Int) -> [IFD.Entry] {
        let xyzToSRGB = [32406, -15372, -4986, -9689, 18758, 415, 557, -2040, 10570].map { ($0, 10000) }
        return [
            .long(254, [1]), .long(256, [previewWidth]), .long(257, [previewHeight]), .short(258, [8, 8, 8]),
            .short(259, [1]), .short(262, [2]), .ascii(271, "AfterGlow"), .ascii(272, camera), .long(273, [strip]),
            .short(274, [6]), .short(277, [3]), .long(278, [previewHeight]), .long(279, [bytes]), .short(284, [1]),
            .long(330, [sub]), .byte(50706, [1, 4, 0, 0]), .byte(50707, [1, 1, 0, 0]), .ascii(50708, camera),
            .rational(50721, xyzToSRGB, signed: true), .rational(50728, [(1, 1), (1, 1), (1, 1)], signed: false),
            .rational(50730, [(1, 1)], signed: true), .short(50778, [21]),
        ]
    }

    static func rawTags(_ spec: Spec, strip: Int, bytes: Int) -> [IFD.Entry] {
        let samples = spec.cfa ? 1 : 3
        let cfa: [IFD.Entry] = spec.cfa ? [.short(33421, [2, 2]), .byte(33422, [0, 1, 1, 2])] : []
        return [
            .long(254, [0]), .long(256, [width]), .long(257, [height]), .short(258, Array(repeating: 16, count: samples)),
            .short(259, [1]), .short(262, [spec.cfa ? 32803 : 34892]), .long(273, [strip]), .short(277, [samples]),
            .long(278, [height]), .long(279, [bytes]), .short(284, [1]),
        ] + cfa + [.long(50714, [0]), .long(50717, [65535])]
    }
}

/// One little-endian TIFF IFD: its entries in tag order, then the values
/// that don't fit in four bytes, each started on an even offset.
enum IFD {
    struct Entry {
        var tag: Int, type: Int, count: Int, payload: [UInt8]
        static func byte(_ tag: Int, _ v: [UInt8]) -> Entry { Entry(tag: tag, type: 1, count: v.count, payload: v) }
        static func ascii(_ tag: Int, _ s: String) -> Entry {
            let v = Array(s.utf8) + [0]
            return Entry(tag: tag, type: 2, count: v.count, payload: v)
        }
        static func short(_ tag: Int, _ v: [Int]) -> Entry { Entry(tag: tag, type: 3, count: v.count, payload: v.flatMap { le($0, 2) }) }
        static func long(_ tag: Int, _ v: [Int]) -> Entry { Entry(tag: tag, type: 4, count: v.count, payload: v.flatMap { le($0, 4) }) }
        static func rational(_ tag: Int, _ v: [(Int, Int)], signed: Bool) -> Entry {
            Entry(tag: tag, type: signed ? 10 : 5, count: v.count, payload: v.flatMap { le($0.0, 4) + le($0.1, 4) })
        }
    }

    /// `value` as `size` little-endian bytes (two's complement when negative).
    static func le(_ value: Int, _ size: Int) -> [UInt8] {
        (0..<size).map { UInt8(truncatingIfNeeded: value >> (8 * $0)) }
    }

    static func encode(_ entries: [Entry], at offset: Int) -> [UInt8] {
        let sorted = entries.sorted { $0.tag < $1.tag }
        var head = le(sorted.count, 2), tail: [UInt8] = []
        let tailAt = offset + 2 + 12 * sorted.count + 4
        for e in sorted {
            head += le(e.tag, 2) + le(e.type, 2) + le(e.count, 4)
            if e.payload.count <= 4 {
                head += e.payload + Array(repeating: 0, count: 4 - e.payload.count)
            } else {
                head += le(tailAt + tail.count, 4)
                tail += e.payload + (e.payload.count % 2 == 1 ? [0] : [])
            }
        }
        return head + le(0, 4) + tail
    }
}
