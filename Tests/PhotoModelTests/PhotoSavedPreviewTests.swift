// PhotoSavedPreviewTests.swift: shared-thumbnails ST-7's Model half. A saved
// document's `Thumbnails/thumbnail.png` is published once under the file's
// ref; a file that isn't there, isn't a document or has no thumbnail, and a
// store that throws, publish nothing. Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import PhotoModel
import SuiteModel
import Testing

@Suite struct PhotoSavedPreviewTests {
    private static let png = Data([0x89, 0x50, 0x4E, 0x47, 1, 2, 3])

    /// A new temp folder.
    private static func folder() throws -> String {
        let path = FileManager.default.temporaryDirectory.path + "/PhotoSavedPreview-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        return path
    }

    /// An OpenRaster file at `folder/name` through the live archive's zip, with `files` beside its mimetype.
    private static func document(_ folder: String, _ name: String, files: [String: Data]) throws -> String {
        let package = PhotoPackage(files: files.merging(["mimetype": Data("image/openraster".utf8)]) { a, _ in a })
        let path = folder + "/" + name
        try PhotoServices.live.archive.container(package).write(to: URL(fileURLWithPath: path))
        return path
    }

    @Test func aSavedDocumentPublishesItsThumbnailUnderItsRef() async throws {
        let path = try Self.document(try Self.folder(), "Beach.ora", files: [PhotoSavedPreview.entry: Self.png, "stack.xml": Data()])
        let thumbnails = FakeThumbnails()
        #expect(await PhotoSavedPreview.publish(documentAt: path, archive: PhotoServices.live.archive, to: thumbnails))
        let ref = PhotoSavedPreview.ref(forPath: path)
        #expect(ref.fileID == SuiteDocumentRef.fileID(forPath: path))
        #expect(ref.app == .photo && ref.type == .photoOpenRaster && ref.displayName == "Beach.ora")
        #expect(await thumbnails.preview(for: ref) == Self.png)
        #expect(await thumbnails.written.count == 1, "one save published more than once")
    }

    @Test func nothingLandedPublishesNothing() async throws {
        let folder = try Self.folder()
        let archive = PhotoServices.live.archive
        let thumbnails = FakeThumbnails()
        let missing = folder + "/Gone.ora"
        #expect(!(await PhotoSavedPreview.publish(documentAt: missing, archive: archive, to: thumbnails)))
        let bare = try Self.document(folder, "Bare.ora", files: ["stack.xml": Data()])
        #expect(!(await PhotoSavedPreview.publish(documentAt: bare, archive: archive, to: thumbnails)))
        let empty = try Self.document(folder, "Empty.ora", files: [PhotoSavedPreview.entry: Data()])
        #expect(!(await PhotoSavedPreview.publish(documentAt: empty, archive: archive, to: thumbnails)))
        let junk = folder + "/Junk.ora"
        try Data("not a zip".utf8).write(to: URL(fileURLWithPath: junk))
        #expect(!(await PhotoSavedPreview.publish(documentAt: junk, archive: archive, to: thumbnails)))
        #expect(await thumbnails.written.isEmpty)
    }

    @Test func aStoreThatThrowsPublishesNothing() async throws {
        let path = try Self.document(try Self.folder(), "Beach.ora", files: [PhotoSavedPreview.entry: Self.png])
        let closed = FakeThumbnails(unavailable: "Previews can't be kept.")
        #expect(!(await PhotoSavedPreview.publish(documentAt: path, archive: PhotoServices.live.archive, to: closed)))
    }
}
