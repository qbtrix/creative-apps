// LibrarySidecarWriterTests.swift: the app's sidecar writer on a real folder (metadata-more MD-17):
// it writes only `.xmp` files, never touches the photo, leaves another app's sidecar alone, and
// ImageIO reads back what it wrote (QB-LIB-V8). Written first (contract rule 13, MD-14), turned on
// by MD-17. macOS only.
#if os(macOS)
import CryptoKit
import Foundation
import ImageIO
import LibraryModel
import Testing

@testable import LibraryApp

@Suite struct LibrarySidecarWriterTests {
    /// The app's writer (MD-17); the tests speak only `SidecarWriting`.
    private func writer() -> any SidecarWriting { XMPSidecarWriter() }

    /// 3 stars, Red, Dusk and Pier, a title and a caption.
    private func packet(rating: Int = 3) throws -> Data {
        var fields = SidecarFields(photo: try #require(LibraryFixtures.photos(named: "shoot").first))
        (fields.keywords, fields.title, fields.caption) = (["Dusk", "Pier"], "Harbour", "Low tide")
        (fields.rating, fields.label) = (rating, PhotoLabel.red)
        return XMPSidecar.encode(fields)
    }

    /// A fresh folder holding a stand-in `IMG_1.jpg`; removed afterwards.
    private func inFolder(_ body: (URL) async throws -> Void) async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "LibrarySidecarWriter-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: root.path)
            try? FileManager.default.removeItem(at: root)
        }
        try Data([0xFF, 0xD8, 0xFF, 0xD9]).write(to: root.appending(path: "IMG_1.jpg"))
        try await body(root)
    }

    private func fingerprint(_ url: URL) throws -> (hash: Data, modified: Date?) {
        let modified = try FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date
        return (Data(SHA256.hash(data: try Data(contentsOf: url))), modified)
    }

    /// Writes the packet to `name` in `root` through the writer.
    private func write(_ name: String, in root: URL, rating: Int = 3) async throws {
        try await writer().write(try packet(rating: rating), sidecar: root.appending(path: name).path)
    }

    @Test func writesTheSidecarAndNeverThePhoto() async throws {
        try await inFolder { root in
            let before = try fingerprint(root.appending(path: "IMG_1.jpg"))
            for rating in [1, 2, 3] { try await write("IMG_1.xmp", in: root, rating: rating) }
            #expect(try fingerprint(root.appending(path: "IMG_1.jpg")) == before)
            #expect(try await writer().read(sidecar: root.appending(path: "IMG_1.xmp").path) == (try packet()))
        }
    }

    @Test func refusesAnythingButAnXMPFileOrAReadOnlyFolder() async throws {
        try await inFolder { root in
            let before = try fingerprint(root.appending(path: "IMG_1.jpg"))
            await #expect(throws: LibraryError.self) { try await write("IMG_1.jpg", in: root) }
            await #expect(throws: LibraryError.self) { try await write("IMG_1", in: root) }
            #expect(try fingerprint(root.appending(path: "IMG_1.jpg")) == before)
            #expect(try FileManager.default.contentsOfDirectory(atPath: root.path) == ["IMG_1.jpg"])
            try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: root.path)
            await #expect(throws: LibraryError.self) { try await write("IMG_1.xmp", in: root) }
        }
    }

    @Test func leavesAnotherAppsSidecarByteEqual() async throws {
        try await inFolder { root in
            let theirs = Data("<x:xmpmeta xmlns:x=\"adobe:ns:meta/\"/>".utf8)
            try theirs.write(to: root.appending(path: "IMG_2.xmp"))
            let error = await #expect(throws: LibraryError.self) { try await write("IMG_2.xmp", in: root) }
            #expect(error?.message == "IMG_2.xmp was written by another app; Library left it unchanged.")
            #expect(try Data(contentsOf: root.appending(path: "IMG_2.xmp")) == theirs)
        }
    }

    /// QB-LIB-V8: ImageIO's XMP parser finds every field Library wrote; alt-text reads x-default.
    @Test func imageIOReadsEveryField() async throws {
        try await inFolder { root in
            try await write("IMG_1.xmp", in: root)
            let data = try Data(contentsOf: root.appending(path: "IMG_1.xmp"))
            let meta = try #require(CGImageMetadataCreateFromXMPData(data as CFData))
            let values = ["dc:subject[0]", "dc:title", "dc:description", "xmp:Rating", "xmp:Label"].map {
                CGImageMetadataCopyStringValueWithPath(meta, nil, $0 as CFString) as String?
            }
            #expect(values == ["Dusk", "Harbour", "Low tide", "3", "Red"])
        }
    }
}
#endif
