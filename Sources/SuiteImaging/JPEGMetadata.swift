// JPEGMetadata.swift: the suite's Linux-safe MetadataCarrying for a JPEG still from a JPEG source. The CLI's
// Photo export uses it, because the CLI can't reach the ImageIO carrier (StillMetadata, SuiteShell; #5975).
// It copies the source's Exif APP1 onto the still and edits that copy in place, never re-laying it out:
//   - a dropped path's IFD entry is removed and the bytes it points at (a sub-IFD included) are zeroed, so a
//     dropped location or serial can't be read back from the file;
//   - a dropped Orientation is set to 1, since the still's pixels are already upright;
//   - the thumbnail (IFD1) and the source's pixel size always go: they describe the source's frame, not the still.
// A path it can't map to a tag ("{TIFF}.Foo") copies no Exif at all, never too much. XMP (APP1) and IPTC (APP13)
// aren't parsed, so they're copied only when nothing but Orientation is dropped (XMP then only without its own
// orientation). A source that isn't a JPEG copies nothing; a still that isn't one throws `.readFailed`.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteModel

public struct JPEGMetadata: MetadataCarrying {
    public init() {}

    public func carrying(_ still: Data, from source: Data, dropping: Set<String>) throws(SuiteError) -> Data {
        let out = [UInt8](still)
        guard let own = Self.segments(out) else { throw .readFailed("The export isn't a JPEG.") }
        guard let found = Self.segments([UInt8](source)) else { return still }
        let onlyOrientation = dropping.isSubset(of: Self.orientation)
        var copied: [UInt8] = []
        for s in found where s.marker == 0xE1 || s.marker == 0xED {
            if s.marker == 0xE1, s.body.starts(with: Self.exifHeader) {
                guard var tiff = ExifBody(Array(s.body.dropFirst(6))), tiff.edit(dropping) else { continue }
                copied += Self.segment(0xE1, Self.exifHeader + tiff.b)
            } else if onlyOrientation, dropping.isEmpty || !Self.contains(s.body, "Orientation") {
                copied += Self.segment(s.marker, s.body)
            }
        }
        // After SOI and the still's own APP0 (JFIF), which must stay first.
        let at = own.first.map { $0.marker == 0xE0 ? $0.end : 2 } ?? 2
        return Data(out.prefix(at) + copied + out.dropFirst(at))
    }

    public func properties(of image: Data) throws(SuiteError) -> Set<String> {
        guard let found = Self.segments([UInt8](image)) else { throw .readFailed("The image isn't a JPEG.") }
        var paths = Set<String>()
        for s in found {
            if s.marker == 0xED { paths.insert("{IPTC}") }
            guard s.marker == 0xE1, s.body.starts(with: Self.exifHeader), let tiff = ExifBody(Array(s.body.dropFirst(6))),
                  let ifd0 = tiff.ifd0, let entries = tiff.entries(ifd0) else { continue }
            for e in entries {
                switch e.tag {
                case 0x0112: paths.formUnion(["Orientation", "{TIFF}.Orientation", "{TIFF}"])
                case 0x8825: paths.insert("{GPS}")
                case 0x8769:
                    paths.insert("{Exif}")
                    let sub = tiff.u32(e.at + 8).flatMap(tiff.entries) ?? []
                    for x in sub { if let k = Self.exifTags.first(where: { $0.value == x.tag })?.key { paths.insert("{Exif}.\(k)") } }
                default:
                    if let k = Self.tiffTags.first(where: { $0.value == e.tag })?.key { paths.formUnion(["{TIFF}.\(k)", "{TIFF}"]) }
                }
            }
        }
        return paths
    }

    static let exifHeader: [UInt8] = [0x45, 0x78, 0x69, 0x66, 0, 0]
    static let orientation: Set<String> = ["Orientation", "{TIFF}.Orientation"]
    static let tiffTags: [String: Int] = ["ImageDescription": 0x010E, "Make": 0x010F, "Model": 0x0110, "Software": 0x0131,
        "DateTime": 0x0132, "Artist": 0x013B, "HostComputer": 0x013C, "Copyright": 0x8298,
        "XResolution": 0x011A, "YResolution": 0x011B, "ResolutionUnit": 0x0128]
    static let exifTags: [String: Int] = ["ExposureTime": 0x829A, "FNumber": 0x829D, "ISOSpeedRatings": 0x8827,
        "DateTimeOriginal": 0x9003, "DateTimeDigitized": 0x9004, "OffsetTimeOriginal": 0x9011, "FocalLength": 0x920A,
        "MakerNote": 0x927C, "UserComment": 0x9286, "CameraOwnerName": 0xA430, "BodySerialNumber": 0xA431,
        "LensMake": 0xA433, "LensModel": 0xA434, "LensSerialNumber": 0xA435]
    /// The source's pixel size: wrong on a resized still, so never carried.
    static let structural = [0xA002, 0xA003]

    /// The marker segments before the first scan, each with its body and where it ends; nil when `b` isn't a
    /// JPEG or its headers are cut off.
    static func segments(_ b: [UInt8]) -> [(marker: UInt8, body: [UInt8], end: Int)]? {
        guard b.count > 3, b[0] == 0xFF, b[1] == 0xD8 else { return nil }
        var at = 2, found: [(marker: UInt8, body: [UInt8], end: Int)] = []
        while at + 3 < b.count {
            guard b[at] == 0xFF else { return nil }
            let marker = b[at + 1]
            if marker == 0xFF { at += 1; continue }
            if marker == 0xDA || marker == 0xD9 { return found }
            if marker == 0x01 || (0xD0...0xD7).contains(marker) { at += 2; continue }
            let length = Int(b[at + 2]) << 8 | Int(b[at + 3])
            guard length >= 2, at + 2 + length <= b.count else { return nil }
            found.append((marker, Array(b[(at + 4)..<(at + 2 + length)]), at + 2 + length))
            at += 2 + length
        }
        return nil
    }

    static func segment(_ marker: UInt8, _ body: [UInt8]) -> [UInt8] {
        let length = body.count + 2
        guard length <= 0xFFFF else { return [] }
        return [0xFF, marker, UInt8(length >> 8), UInt8(length & 0xFF)] + body
    }

    static func contains(_ body: [UInt8], _ text: String) -> Bool {
        let needle = Array(text.utf8)
        guard body.count >= needle.count else { return false }
        return (0...(body.count - needle.count)).contains { body[$0..<($0 + needle.count)].elementsEqual(needle) }
    }
}

/// An Exif body's TIFF structure, edited in place with every read and write bounds-checked.
private struct ExifBody {
    var b: [UInt8]
    let little: Bool

    init?(_ b: [UInt8]) {
        guard b.count >= 8, b.starts(with: [0x49, 0x49]) || b.starts(with: [0x4D, 0x4D]) else { return nil }
        (self.b, little) = (b, b[0] == 0x49)
        guard u16(2) == 42 else { return nil }
    }

    func u16(_ at: Int) -> Int? {
        guard at >= 0, at + 2 <= b.count else { return nil }
        let x = Int(b[at]), y = Int(b[at + 1])
        return little ? x | y << 8 : x << 8 | y
    }

    func u32(_ at: Int) -> Int? {
        guard let p = u16(at), let q = u16(at + 2) else { return nil }
        return little ? p | q << 16 : p << 16 | q
    }

    mutating func put16(_ at: Int, _ v: Int) {
        guard at >= 0, at + 2 <= b.count else { return }
        let (hi, lo) = (UInt8(v >> 8 & 0xFF), UInt8(v & 0xFF))
        (b[at], b[at + 1]) = little ? (lo, hi) : (hi, lo)
    }

    mutating func put32(_ at: Int, _ v: Int) {
        put16(at + (little ? 0 : 2), v & 0xFFFF)
        put16(at + (little ? 2 : 0), v >> 16 & 0xFFFF)
    }

    mutating func zero(_ range: Range<Int>?) {
        guard let range, range.lowerBound >= 0, range.upperBound <= b.count else { return }
        b.replaceSubrange(range, with: repeatElement(0, count: range.count))
    }

    var ifd0: Int? { u32(4) }

    /// Each entry's tag and offset in the IFD at `ifd`; nil when it runs past the body.
    func entries(_ ifd: Int) -> [(tag: Int, at: Int)]? {
        guard ifd >= 8, let n = u16(ifd), ifd + 2 + 12 * n + 4 <= b.count else { return nil }
        return (0..<n).compactMap { i in u16(ifd + 2 + 12 * i).map { ($0, ifd + 2 + 12 * i) } }
    }

    /// Where the IFD at `ifd` keeps its next-IFD offset.
    func nextLink(_ ifd: Int) -> Int? { u16(ifd).map { ifd + 2 + 12 * $0 } }

    /// The bytes an entry's value takes outside the entry; nil when it fits inline.
    func outside(_ entry: Int) -> Range<Int>? {
        let sizes = [1: 1, 2: 1, 3: 2, 4: 4, 5: 8, 6: 1, 7: 1, 8: 2, 9: 4, 10: 8, 11: 4, 12: 8]
        guard let type = u16(entry + 2), let count = u32(entry + 4), let offset = u32(entry + 8) else { return nil }
        let total = (sizes[type] ?? 1) * count
        guard total > 4 else { return nil }
        return offset..<(offset + total)
    }

    /// Zeroes the IFD at `ifd`, its values, its sub-IFDs and (IFD1) its thumbnail.
    mutating func wipe(_ ifd: Int, depth: Int = 0) {
        guard depth < 4, let entries = entries(ifd), let link = nextLink(ifd) else { return }
        let thumbnailLength = entries.first { $0.tag == 0x0202 }.flatMap { u32($0.at + 8) }
        for e in entries {
            if [0x8769, 0x8825, 0xA005].contains(e.tag), let sub = u32(e.at + 8) { wipe(sub, depth: depth + 1) }
            if e.tag == 0x0201, let start = u32(e.at + 8), let thumbnailLength { zero(start..<(start + thumbnailLength)) }
            zero(outside(e.at))
        }
        zero(ifd..<(link + 4))
    }

    /// Removes the entry tagged `tag` from the IFD at `ifd`, zeroing what it points at.
    mutating func remove(_ tag: Int, from ifd: Int) {
        guard let entries = entries(ifd), let i = entries.firstIndex(where: { $0.tag == tag }), let link = nextLink(ifd) else { return }
        let at = entries[i].at
        if [0x8769, 0x8825, 0xA005].contains(tag), let sub = u32(at + 8) { wipe(sub, depth: 1) }
        zero(outside(at))
        b.replaceSubrange(at..<(link + 4), with: Array(b[(at + 12)..<(link + 4)]) + repeatElement(0, count: 12))
        put16(ifd, entries.count - 1)
    }

    /// Applies the drop policy; false when a path names a tag it can't find, so the caller copies no Exif.
    mutating func edit(_ dropping: Set<String>) -> Bool {
        guard let ifd0, entries(ifd0) != nil, let link = nextLink(ifd0) else { return false }
        if let ifd1 = u32(link), ifd1 != 0 { wipe(ifd1) }
        put32(link, 0)
        func exifIFD() -> Int? { entries(ifd0)?.first { $0.tag == 0x8769 }.flatMap { u32($0.at + 8) } }
        for tag in JPEGMetadata.structural { if let e = exifIFD() { remove(tag, from: e) } }
        for path in dropping.sorted() {
            let parts = path.split(separator: ".", maxSplits: 1).map(String.init)
            let (group, key) = (parts.first ?? "", parts.count > 1 ? parts[1] : nil)
            switch (group, key) {
            case ("Orientation", nil), ("{TIFF}", "Orientation"?):
                if let e = entries(ifd0)?.first(where: { $0.tag == 0x0112 }) { put16(e.at + 8, 1) }
            case ("{GPS}", _): remove(0x8825, from: ifd0)
            case ("{Exif}", nil): remove(0x8769, from: ifd0)
            case ("{Exif}", let key?):
                guard let exif = exifIFD() else { continue }
                if let tag = JPEGMetadata.exifTags[key] { remove(tag, from: exif) } else { remove(0x8769, from: ifd0) }
            case ("{TIFF}", let key?):
                guard let tag = JPEGMetadata.tiffTags[key] else { return false }
                remove(tag, from: ifd0)
            case (let maker, _) where maker.hasPrefix("{Maker"):
                if let exif = exifIFD() { remove(0x927C, from: exif) }
            default: continue
            }
        }
        return true
    }
}
