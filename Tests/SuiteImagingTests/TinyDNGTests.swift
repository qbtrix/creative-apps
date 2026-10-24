// TinyDNGTests.swift: the shared-raw fixtures (SR-1, slice SR-a, journey
// MJ-SR). Each committed file under Fixtures/raw/ equals its writer's bytes,
// and the writer's IFDs parse back to the packet's sizes and tags: IFD0 the
// 32 x 24 preview, its SubIFD the 64 x 48 raw data, Orientation 6,
// BaselineExposure 1.0. The parser here is independent of the writer, and
// the PNG's profile comes back through core's own Inflate and ICC reader.
// To rewrite the fixtures after a writer change:
//   TINY_FIXTURES_WRITE=1 swift test --filter TinyDNGTests
import CoreColor
import CoreRaster
import Foundation
import Testing

/// A little-endian TIFF read back, one IFD at a time.
struct TIFFRead {
    struct Entry { var type: Int; var count: Int; var values: [Double]; var text: String }
    let bytes: [UInt8]

    func u16(_ at: Int) -> Int { at + 1 < bytes.count ? Int(bytes[at]) | Int(bytes[at + 1]) << 8 : -1 }
    func u32(_ at: Int) -> Int { at + 3 < bytes.count ? u16(at) | u16(at + 2) << 16 : -1 }

    var firstIFD: Int { bytes.starts(with: [0x49, 0x49, 42, 0]) ? u32(4) : -1 }

    /// The entries of the IFD at `offset`, by tag.
    func ifd(_ offset: Int) -> [Int: Entry] {
        let sizes = [1: 1, 2: 1, 3: 2, 4: 4, 5: 8, 10: 8]
        var out: [Int: Entry] = [:]
        for i in 0..<max(0, u16(offset)) {
            let at = offset + 2 + 12 * i, type = u16(at + 2), count = u32(at + 4)
            let size = sizes[type] ?? 1
            let base = size * count <= 4 ? at + 8 : u32(at + 8)
            var values: [Double] = []
            for k in 0..<count {
                let p = base + k * size
                switch type {
                case 3: values.append(Double(u16(p)))
                case 4: values.append(Double(u32(p)))
                case 5: values.append(Double(u32(p)) / Double(max(1, u32(p + 4))))
                case 10: values.append(Double(Int32(truncatingIfNeeded: u32(p))) / Double(max(1, Int32(truncatingIfNeeded: u32(p + 4)))))
                default: values.append(p < bytes.count ? Double(bytes[p]) : -1)
                }
            }
            let text = type == 2 && base + count <= bytes.count ? String(decoding: bytes[base..<base + count].prefix { $0 != 0 }, as: UTF8.self) : ""
            out[u16(at)] = Entry(type: type, count: count, values: values, text: text)
        }
        return out
    }

    /// The strip of an IFD: its first offset and byte count.
    func strip(_ ifd: [Int: Entry]) -> ArraySlice<UInt8> {
        let start = Int(ifd[273]?.values.first ?? -1), count = Int(ifd[279]?.values.first ?? 0)
        return start >= 0 && start + count <= bytes.count ? bytes[start..<start + count] : []
    }
}

@Suite struct TinyDNGTests {
    static func committed() throws -> [(name: String, bytes: Data)] {
        [(TinyDNG.Spec.bayer.name, TinyDNG.write(.bayer)), (TinyDNG.Spec.linear.name, TinyDNG.write(.linear)),
         (TinyDNG.notRawName, TinyDNG.notRaw), (TinyPNG.name, try TinyPNG.p3Red16())]
    }

    @Test func committedFilesEqualTheirWriters() throws {
        let write = ProcessInfo.processInfo.environment["TINY_FIXTURES_WRITE"] == "1"
        for (name, bytes) in try Self.committed() {
            let url = TinyDNG.fixture(name)
            if write { try bytes.write(to: url) }
            #expect(try Data(contentsOf: url) == bytes, "\(name) drifted from its writer")
        }
    }

    static func ifds(_ spec: TinyDNG.Spec) -> (read: TIFFRead, preview: [Int: TIFFRead.Entry], raw: [Int: TIFFRead.Entry]) {
        let read = TIFFRead(bytes: [UInt8](TinyDNG.write(spec)))
        let preview = read.ifd(read.firstIFD)
        let raw = read.ifd(Int(preview[330]?.values.first ?? -1))
        return (read, preview, raw)
    }

    @Test(arguments: [TinyDNG.Spec.bayer, .linear])
    func ifd0IsTheUprightTaggedPreview(_ spec: TinyDNG.Spec) {
        let (read, ifd, _) = Self.ifds(spec)
        #expect(read.firstIFD == 8)
        #expect(ifd[254]?.values == [1], "NewSubFileType: reduced-resolution preview")
        #expect(ifd[256]?.values == [32] && ifd[257]?.values == [24])
        #expect(ifd[258]?.values == [8, 8, 8] && ifd[262]?.values == [2] && ifd[259]?.values == [1])
        #expect(ifd[274]?.values == [6], "Orientation 6: 90 degrees clockwise")
        #expect(ifd[50706]?.values == [1, 4, 0, 0], "DNGVersion 1.4")
        #expect(ifd[50708]?.text == TinyDNG.camera && ifd[272]?.text == TinyDNG.camera)
        #expect(ifd[50730]?.values == [1.0] && ifd[50730]?.type == 10, "BaselineExposure 1.0, SRATIONAL")
        #expect(ifd[50728]?.values == [1, 1, 1], "AsShotNeutral")
        #expect(ifd[50778]?.values == [21], "CalibrationIlluminant1 D65")
        let matrix = ifd[50721]?.values ?? []
        #expect(matrix.count == 9 && abs((matrix.first ?? 0) - 3.2406) < 1e-4, "ColorMatrix1, XYZ to sRGB")
        let strip = read.strip(ifd)
        #expect(strip.count == 32 * 24 * 3)
        #expect(stride(from: 0, to: strip.count, by: 3).allSatisfy { Array(strip.dropFirst($0).prefix(3)) == TinyDNG.marker })
    }

    @Test func subIFDIsTheRGGBMosaic() {
        let (read, _, raw) = Self.ifds(.bayer)
        #expect(raw[254]?.values == [0] && raw[256]?.values == [64] && raw[257]?.values == [48])
        #expect(raw[262]?.values == [32803] && raw[258]?.values == [16] && raw[277]?.values == [1])
        #expect(raw[33421]?.values == [2, 2] && raw[33422]?.values == [0, 1, 1, 2])
        #expect(raw[50714]?.values == [0] && raw[50717]?.values == [65535])
        #expect(read.strip(raw).count == 64 * 48 * 2)
    }

    @Test func subIFDOfTheLinearFileIsLinearRaw() {
        let (read, _, raw) = Self.ifds(.linear)
        #expect(raw[256]?.values == [64] && raw[257]?.values == [48])
        #expect(raw[262]?.values == [34892] && raw[258]?.values == [16, 16, 16] && raw[277]?.values == [3])
        #expect(raw[33421] == nil && raw[50717]?.values == [65535])
        #expect(read.strip(raw).count == 64 * 48 * 6)
    }

    /// The scene: both highlight patches and the ramp, read from the strips
    /// as fractions of white, in every sample of a 2 x 2 cell.
    @Test(arguments: [TinyDNG.Spec.bayer, .linear])
    func rawDataHoldsTheScene(_ spec: TinyDNG.Spec) {
        let (read, _, raw) = Self.ifds(spec)
        let strip = Array(read.strip(raw)), samples = spec.cfa ? 1 : 3
        func value(_ x: Int, _ y: Int, _ s: Int) -> Double {
            let at = ((y * 64 + x) * samples + s) * 2
            guard at + 1 < strip.count else { return -1 }
            return Double(Int(strip[at]) | Int(strip[at + 1]) << 8) / 65535
        }
        for (patch, level) in zip(TinyDNG.patches, TinyDNG.highlights) {
            let cell = [(0, 0), (1, 0), (0, 1), (1, 1)].map { value(patch.x + $0.0, patch.y + $0.1, samples - 1) }
            #expect(cell.allSatisfy { abs($0 - level) < 1e-4 }, "\(cell) vs \(level)")
        }
        #expect(value(0, 47, 0) == 0 && abs(value(63, 47, 0) - 0.5) < 1e-4, "the ramp runs 0 to 0.5")
        #expect(value(62, 47, 0) == value(63, 47, 0), "one level per 2 x 2 cell")
    }

    @Test func notRawIsFourteenBytes() {
        #expect(TinyDNG.notRaw == Data("not a raw file".utf8) && TinyDNG.notRaw.count == 14)
    }

    @Test func pngIsSixteenBitP3RedOnTheLeft() throws {
        let data = try TinyPNG.p3Red16()
        let info = try PNG.info(data)
        #expect(info.width == 8 && info.height == 8 && info.bitDepth == 16 && info.colorType == 2)
        let bytes = [UInt8](data)
        let tag = Array("iCCP".utf8)
        let at = try #require((0..<bytes.count - 4).first { Array(bytes[$0..<$0 + 4]) == tag })
        let length = Int(bytes[at - 4]) << 24 | Int(bytes[at - 3]) << 16 | Int(bytes[at - 2]) << 8 | Int(bytes[at - 1])
        let body = bytes[(at + 4)..<(at + 4 + length)]
        let nul = try #require(body.firstIndex(of: 0))
        #expect(String(decoding: body[body.startIndex..<nul], as: UTF8.self) == "Display P3")
        let icc = try Inflate.zlib(Data(body[(nul + 2)...]), limit: 1 << 20)
        #expect(try ColorProfile(iccData: icc) == ColorProfile.displayP3)
        let pixels = try PNG.read(data)
        let left = try pixels.pixel(x: 0, y: 7), right = try pixels.pixel(x: 7, y: 0)
        #expect(left.r == 1 && left.g == 0 && left.b == 0 && left.a == 1)
        #expect(right.r == 1 && right.g == 1 && right.b == 1)
    }
}
