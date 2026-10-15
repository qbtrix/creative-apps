// PhotoPackageIO.swift: a Photo document's bytes on disk, off the main actor
// (PV-1, D-6 of photo-documents). The window takes `snapshot()` on the main
// actor (a copy-on-write value, no pixel work) and hands it to `write`, which
// encodes every image, builds the container and writes it atomically in one
// detached task, so a failed write leaves no new file and keeps an old one
// whole. `read` loads the file and splits the container into its package in
// a detached task; the window passes that package to
// `openDocument(_:name:codec:)`. Errors are the archive's `ArchiveError`, the
// codec's, or the file system's.
import Foundation
import PhotoModel

enum PhotoPackageIO {
    /// Encodes `snapshot` through `archive` and `codec` and writes the
    /// container to `url` atomically, all off the main actor.
    nonisolated static func write(
        _ snapshot: PhotoDocumentSnapshot, to url: URL, archive: any DocumentArchiving, codec: any PhotoImageCodec
    ) async throws {
        try await Task.detached(priority: .userInitiated) {
            let package = try archive.encode(snapshot, codec: codec)
            let data = try archive.container(package)
            try data.write(to: url, options: .atomic)
        }.value
    }

    /// The package in the document file at `url`, read and unpacked off the
    /// main actor. Throws `ArchiveError` for a file that isn't a document.
    nonisolated static func read(from url: URL, archive: any DocumentArchiving) async throws -> PhotoPackage {
        try await Task.detached(priority: .userInitiated) {
            let data = try Data(contentsOf: url)
            return try archive.package(fromContainer: data)
        }.value
    }
}
