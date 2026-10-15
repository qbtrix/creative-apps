// Live/PhotoZip.swift: the OpenRaster container (D-1 of photo-documents).
// A zip, written and read in pure Swift from the public .ZIP File Format
// Specification (PKWARE APPNOTE): every entry stored (method 0, PNGs are
// compressed already), `mimetype` first so its bytes sit at offset 30, the
// other paths sorted; no zip64. Every read is bounds-checked, so damaged
// bytes throw an ArchiveError and never crash. Writing sizes the file once
// and takes the entries' CRCs across the cores; the CRC-32 reads eight bytes
// a step (slicing-by-8). Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

enum PhotoZip {
    static let mimetype = "mimetype"
    static let mimetypeValue = Data("image/openraster".utf8)

    private static let localSignature: UInt32 = 0x0403_4B50
    private static let centralSignature: UInt32 = 0x0201_4B50
    private static let endSignature: UInt32 = 0x0605_4B50
    private static let localSize = 30, centralSize = 46, endSize = 22
    /// 1980-01-01 00:00, the earliest DOS date, so the same package writes the same bytes.
    private static let dosDate: UInt16 = 0x0021

    // MARK: Writing

    /// The file's bytes for `package`. Throws `.tooLarge` past zip's 32-bit limits.
    static func container(_ package: PhotoPackage) throws -> Data {
        let names = (package.files[mimetype] == nil ? [] : [mimetype])
            + package.files.keys.filter { $0 != mimetype }.sorted()
        guard names.count <= Int(UInt16.max) else { throw ArchiveError.tooLarge }
        let crcs = try PhotoLayerComposite.inParallel(names.count) { crc32(package.files[names[$0]] ?? Data()) }
        var out = Data(capacity: names.reduce(endSize) {
            $0 + localSize + centralSize + 2 * $1.utf8.count + (package.files[$1]?.count ?? 0)
        })
        var central: [UInt8] = []
        for (name, crc) in zip(names, crcs) {
            let bytes = package.files[name] ?? Data()
            let nameBytes = Array(name.utf8)
            let offset = out.count
            guard bytes.count <= Int(UInt32.max), nameBytes.count <= Int(UInt16.max),
                  offset <= Int(UInt32.max) else { throw ArchiveError.tooLarge }
            let flags: UInt16 = nameBytes.allSatisfy { $0 < 0x80 } ? 0 : 0x0800  // UTF-8 names
            out.put32(localSignature)
            out.put16(10); out.put16(flags); out.put16(0)  // version needed, flags, stored
            out.put16(0); out.put16(dosDate)
            out.put32(crc); out.put32(UInt32(bytes.count)); out.put32(UInt32(bytes.count))
            out.put16(UInt16(nameBytes.count)); out.put16(0)
            out += nameBytes
            out += bytes

            central.put32(centralSignature)
            central.put16(20); central.put16(10); central.put16(flags); central.put16(0)
            central.put16(0); central.put16(dosDate)
            central.put32(crc); central.put32(UInt32(bytes.count)); central.put32(UInt32(bytes.count))
            central.put16(UInt16(nameBytes.count)); central.put16(0); central.put16(0)  // name, extra, comment
            central.put16(0); central.put16(0); central.put32(0)  // disk, internal, external attributes
            central.put32(UInt32(offset))
            central += nameBytes
        }
        let centralOffset = out.count
        guard centralOffset <= Int(UInt32.max), central.count <= Int(UInt32.max),
              centralOffset + central.count + endSize <= Int(UInt32.max) else { throw ArchiveError.tooLarge }
        out += central
        out.put32(endSignature)
        out.put16(0); out.put16(0)
        out.put16(UInt16(names.count)); out.put16(UInt16(names.count))
        out.put32(UInt32(central.count)); out.put32(UInt32(centralOffset))
        out.put16(0)
        return out
    }

    // MARK: Reading

    /// The entries of a file `container` wrote, or any zip of stored entries
    /// whose first entry is `mimetype` = "image/openraster".
    static func package(fromContainer data: Data) throws -> PhotoPackage {
        let bytes = [UInt8](data)
        guard let end = endRecord(in: bytes),
              let count = bytes.u16(end + 10), let size = bytes.u32(end + 12), let start = bytes.u32(end + 16)
        else { throw ArchiveError.notADocument }
        let centralStart = Int(start), centralEnd = Int(start) + Int(size)
        guard centralEnd <= end else { throw truncated }
        var files: [String: Data] = [:]
        var cursor = centralStart
        for index in 0..<Int(count) {
            guard bytes.u32(cursor) == centralSignature,
                  let method = bytes.u16(cursor + 10), let crc = bytes.u32(cursor + 16),
                  let stored = bytes.u32(cursor + 20), let length = bytes.u32(cursor + 24),
                  let nameLength = bytes.u16(cursor + 28), let extra = bytes.u16(cursor + 30),
                  let comment = bytes.u16(cursor + 32), let offset = bytes.u32(cursor + 42),
                  let nameBytes = bytes.slice(cursor + centralSize, Int(nameLength))
            else { throw index == 0 ? ArchiveError.notADocument : truncated }
            cursor += centralSize + Int(nameLength) + Int(extra) + Int(comment)
            guard cursor <= centralEnd else { throw truncated }
            let name = String(decoding: nameBytes, as: UTF8.self)
            if index == 0, name != mimetype { throw ArchiveError.notADocument }
            guard method == 0 else { throw ArchiveError.damaged("\(name) is compressed") }
            guard stored == length else { throw ArchiveError.damaged("\(name) is corrupt") }
            let range = try entryRange(in: bytes, at: Int(offset), name: nameBytes, size: Int(length), limit: centralStart)
            let entry = bytes[range]
            guard crc32(entry) == crc else { throw ArchiveError.damaged("\(name) is corrupt") }
            if index == 0, Data(entry) != mimetypeValue { throw ArchiveError.notADocument }
            guard files[name] == nil else { throw ArchiveError.damaged("\(name) appears twice") }
            files[name] = Data(entry)
        }
        guard !files.isEmpty else { throw ArchiveError.notADocument }
        return PhotoPackage(files: files)
    }

    private static let truncated = ArchiveError.damaged("the file is cut short")

    /// The offset of the end-of-central-directory record, searched back from
    /// the end past a comment of up to 64 KB.
    private static func endRecord(in bytes: [UInt8]) -> Int? {
        guard bytes.count >= endSize else { return nil }
        let last = bytes.count - endSize
        let first = max(0, last - Int(UInt16.max))
        for offset in stride(from: last, through: first, by: -1) where bytes.u32(offset) == endSignature {
            if let comment = bytes.u16(offset + 20), offset + endSize + Int(comment) == bytes.count { return offset }
        }
        return nil
    }

    /// Where in `bytes` the data of the local entry at `offset` lies, checked
    /// against its central record.
    private static func entryRange(in bytes: [UInt8], at offset: Int, name: [UInt8], size: Int,
                                   limit: Int) throws -> Range<Int> {
        let label = String(decoding: name, as: UTF8.self)
        guard bytes.u32(offset) == localSignature, let method = bytes.u16(offset + 8),
              let nameLength = bytes.u16(offset + 26), let extra = bytes.u16(offset + 28),
              bytes.slice(offset + localSize, Int(nameLength)) == name
        else { throw ArchiveError.damaged("\(label) is corrupt") }
        guard method == 0 else { throw ArchiveError.damaged("\(label) is compressed") }
        let start = offset + localSize + Int(nameLength) + Int(extra)
        guard size >= 0, start >= 0, start <= bytes.count, size <= bytes.count - start, start + size <= limit
        else { throw truncated }
        return start..<(start + size)
    }

    // MARK: CRC-32

    /// `tables[k * 256 + b]`: table 0 is the byte-at-a-time CRC table; table
    /// k is the CRC of byte b followed by k zero bytes, for slicing-by-8.
    private static let tables: [UInt32] = {
        var tables = (0..<256).map { index in
            var value = UInt32(index)
            for _ in 0..<8 { value = value & 1 == 1 ? 0xEDB8_8320 ^ (value >> 1) : value >> 1 }
            return value
        }
        for k in 1..<8 {
            for b in 0..<256 {
                let previous = tables[(k - 1) * 256 + b]
                tables.append((previous >> 8) ^ tables[Int(previous & 0xFF)])
            }
        }
        return tables
    }()

    /// The zip CRC-32 (reflected polynomial 0xEDB88320) of `data`.
    static func crc32(_ data: Data) -> UInt32 { data.withUnsafeBytes { crc32($0) } }

    static func crc32(_ bytes: [UInt8]) -> UInt32 { bytes.withUnsafeBytes { crc32($0) } }

    static func crc32(_ bytes: ArraySlice<UInt8>) -> UInt32 { bytes.withUnsafeBytes { crc32($0) } }

    /// Eight bytes a step while eight remain, then one at a time. Every read
    /// is inside `bytes` (i + 8 <= count, then i < count) and every table
    /// index is k * 256 plus one byte, under `tables.count` = 2048.
    private static func crc32(_ bytes: UnsafeRawBufferPointer) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        tables.withUnsafeBufferPointer { t in
            guard t.count == 8 * 256 else { return }
            let count = bytes.count
            var i = 0
            while count - i >= 8 {
                let low = crc ^ (UInt32(bytes[i]) | UInt32(bytes[i + 1]) << 8
                    | UInt32(bytes[i + 2]) << 16 | UInt32(bytes[i + 3]) << 24)
                let high = UInt32(bytes[i + 4]) | UInt32(bytes[i + 5]) << 8
                    | UInt32(bytes[i + 6]) << 16 | UInt32(bytes[i + 7]) << 24
                crc = t[7 * 256 + Int(low & 0xFF)] ^ t[6 * 256 + Int(low >> 8 & 0xFF)]
                    ^ t[5 * 256 + Int(low >> 16 & 0xFF)] ^ t[4 * 256 + Int(low >> 24)]
                    ^ t[3 * 256 + Int(high & 0xFF)] ^ t[2 * 256 + Int(high >> 8 & 0xFF)]
                    ^ t[256 + Int(high >> 16 & 0xFF)] ^ t[Int(high >> 24)]
                i += 8
            }
            while i < count {
                crc = t[Int((crc ^ UInt32(bytes[i])) & 0xFF)] ^ (crc >> 8)
                i += 1
            }
        }
        return crc ^ 0xFFFF_FFFF
    }
}

private extension RangeReplaceableCollection where Element == UInt8 {
    mutating func put16(_ value: UInt16) {
        append(UInt8(value & 0xFF)); append(UInt8(value >> 8))
    }

    mutating func put32(_ value: UInt32) {
        put16(UInt16(value & 0xFFFF)); put16(UInt16(value >> 16))
    }
}

private extension Array where Element == UInt8 {
    /// `length` bytes at `offset`, or nil when they run past either end.
    func slice(_ offset: Int, _ length: Int) -> [UInt8]? {
        guard offset >= 0, length >= 0, offset <= count, length <= count - offset else { return nil }
        return Array(self[offset..<offset + length])
    }

    func u16(_ offset: Int) -> UInt16? {
        guard let pair = slice(offset, 2), let low = pair.first, let high = pair.last else { return nil }
        return UInt16(low) | UInt16(high) << 8
    }

    func u32(_ offset: Int) -> UInt32? {
        guard let low = u16(offset), let high = u16(offset + 2) else { return nil }
        return UInt32(low) | UInt32(high) << 16
    }
}
