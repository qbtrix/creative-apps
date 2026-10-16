// PhotoContainerTests.swift: D-1 of photo-documents. The OpenRaster
// container is a zip whose entries are all stored: `mimetype` first, then the
// other paths sorted. It round-trips byte for byte, the CRC-32 is the zip
// one, and damaged, compressed, foreign or truncated bytes throw an
// ArchiveError instead of crashing. Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
@testable import PhotoModel
import Testing

@Suite struct PhotoContainerTests {
    private let layer = "data/layer-1.png"

    private func sample() -> PhotoPackage {
        PhotoPackage(files: [
            "stack.xml": Data("<image w=\"4\" h=\"4\"><stack/></image>".utf8),
            "mimetype": Data("image/openraster".utf8),
            layer: Data([0x89, 0x50, 0x4E, 0x47, 0x00, 0xFF, 0x10, 0x20, 0x30]),
        ])
    }

    /// The offset just past the `occurrence`th (0-based) copy of `name` in `bytes`.
    private func end(of name: String, in bytes: [UInt8], occurrence: Int) -> Int? {
        let needle = Array(name.utf8)
        var seen = 0
        for start in 0...(bytes.count - needle.count) where Array(bytes[start..<start + needle.count]) == needle {
            if seen == occurrence { return start + needle.count }
            seen += 1
        }
        return nil
    }

    @Test func roundTripsByteForByte() throws {
        let package = sample()
        let data = try PhotoZip.container(package)
        let read = try PhotoZip.package(fromContainer: data)
        #expect(read == package)
        #expect(try PhotoZip.container(read) == data)
    }

    @Test func mimetypeIsTheFirstStoredEntry() throws {
        let bytes = [UInt8](try PhotoZip.container(sample()))
        #expect(Array(bytes[0..<4]) == [0x50, 0x4B, 0x03, 0x04])
        #expect(bytes[8] == 0 && bytes[9] == 0)  // method 0, stored
        #expect(String(decoding: bytes[30..<38], as: UTF8.self) == "mimetype")
        #expect(String(decoding: bytes[38..<54], as: UTF8.self) == "image/openraster")
    }

    @Test func otherEntriesFollowSorted() throws {
        let bytes = [UInt8](try PhotoZip.container(sample()))
        let layerAt = try #require(end(of: layer, in: bytes, occurrence: 0))
        let stackAt = try #require(end(of: "stack.xml", in: bytes, occurrence: 0))
        #expect(layerAt < stackAt)
    }

    @Test func crc32MatchesTheCheckValue() {
        #expect(PhotoZip.crc32(Data("123456789".utf8)) == 0xCBF4_3926)
        #expect(PhotoZip.crc32(Data()) == 0)
    }

    @Test func aFlippedDataByteIsCorrupt() throws {
        var bytes = [UInt8](try PhotoZip.container(sample()))
        let dataStart = try #require(end(of: layer, in: bytes, occurrence: 0))
        bytes[dataStart + 2] ^= 0x01
        #expect(throws: ArchiveError.damaged("\(layer) is corrupt")) {
            try PhotoZip.package(fromContainer: Data(bytes))
        }
    }

    @Test func notAZipIsNotADocument() {
        #expect(throws: ArchiveError.notADocument) {
            try PhotoZip.package(fromContainer: Data("not a zip".utf8))
        }
        #expect(throws: ArchiveError.notADocument) {
            try PhotoZip.package(fromContainer: Data())
        }
    }

    @Test func anotherMimetypeIsNotADocument() throws {
        var files = sample().files
        files["mimetype"] = Data("image/png".utf8)
        let data = try PhotoZip.container(PhotoPackage(files: files))
        #expect(throws: ArchiveError.notADocument) { try PhotoZip.package(fromContainer: data) }
        files["mimetype"] = nil
        let none = try PhotoZip.container(PhotoPackage(files: files))
        #expect(throws: ArchiveError.notADocument) { try PhotoZip.package(fromContainer: none) }
    }

    @Test func aCompressedEntryIsDamaged() throws {
        var bytes = [UInt8](try PhotoZip.container(sample()))
        let local = try #require(end(of: layer, in: bytes, occurrence: 0)) - layer.utf8.count
        let central = try #require(end(of: layer, in: bytes, occurrence: 1)) - layer.utf8.count
        bytes[local - 30 + 8] = 8
        bytes[central - 46 + 10] = 8
        #expect(throws: ArchiveError.damaged("\(layer) is compressed")) {
            try PhotoZip.package(fromContainer: Data(bytes))
        }
    }

    @Test func truncatedInputThrows() throws {
        let bytes = [UInt8](try PhotoZip.container(sample()))
        for length in 0..<bytes.count {
            #expect(throws: ArchiveError.self) {
                try PhotoZip.package(fromContainer: Data(bytes[0..<length]))
            }
        }
    }

    @Test func anyFlippedByteThrowsOrReadsNeverCrashes() throws {
        let bytes = [UInt8](try PhotoZip.container(sample()))
        for index in bytes.indices {
            for mask: UInt8 in [0x01, 0x80, 0xFF] {
                var damaged = bytes
                damaged[index] ^= mask
                do { _ = try PhotoZip.package(fromContainer: Data(damaged)) } catch is ArchiveError {}
            }
        }
    }
}
