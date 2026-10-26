// Live/PhotoSavedPreview.swift: shared-thumbnails ST-7. After a document
// save lands, the saved file's own `Thumbnails/thumbnail.png` (the OpenRaster
// entry LiveArchive writes, at most 256 px long) goes to the suite's
// thumbnails under the file's ref, so the home's Recent card shows it. It
// reads the file back from disk, so only what landed is published: a missing
// file, one that isn't a document, one with no thumbnail entry or a store
// that throws publishes nothing. The caller runs it off the main actor.
// Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteModel

public enum PhotoSavedPreview {
    /// The OpenRaster thumbnail's entry.
    public static let entry = "Thumbnails/thumbnail.png"

    /// The suite's ref for the Photo document at `path`: the path's file id, Photo, OpenRaster.
    public static func ref(forPath path: String) -> SuiteDocumentRef {
        let name = path.split(separator: "/").last.map(String.init) ?? path
        return SuiteDocumentRef(path: path, fileID: SuiteDocumentRef.fileID(forPath: path), app: .photo,
                                type: .photoOpenRaster, displayName: name)
    }

    /// Publishes the thumbnail of the document saved at `path`, read back
    /// through `archive`, to `thumbnails`; true once it was published.
    @discardableResult
    public static func publish(documentAt path: String, archive: any DocumentArchiving,
                               to thumbnails: any ThumbnailPublishing) async -> Bool {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let package = try? archive.package(fromContainer: data),
              let png = package.files[entry], !png.isEmpty
        else { return false }
        do {
            _ = try await thumbnails.publish(png: png, for: ref(forPath: path))
            return true
        } catch {
            return false
        }
    }
}
