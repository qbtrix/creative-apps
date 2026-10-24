// Platform/CollectionsStore.swift: the collections file on the file system
// (filters-collections FC-15). `collections.json` lives beside `catalog.json`:
// in the -LibraryCatalogDir folder when the app was launched with one, else
// in Application Support/Library; the folder is made on the first write. It
// mirrors `CatalogStore`: a write lands atomically (Foundation writes an
// auxiliary file and renames it over the file), so a reader never sees a
// partial file and nothing temporary is left beside it. `writeNow` is the
// same write, synchronous, for the flush on quit. `setAside` renames a
// damaged file to `collections.json.bad`, replacing an older one, so nothing
// is ever written over it. File I/O only: the codec is the Model's
// (`restoreCollections`, `collectionsSaveRequest`). Foundation FileManager only.
import Foundation
import LibraryModel

struct CollectionsStore: Sendable {
    static let fileName = "collections.json"
    static let setAsideName = "collections.json.bad"

    /// The folder `collections.json` lives in.
    let folder: URL

    init(directory: String) {
        folder = URL(fileURLWithPath: directory, isDirectory: true)
    }

    var fileURL: URL { folder.appendingPathComponent(Self.fileName, isDirectory: false) }
    var setAsideURL: URL { folder.appendingPathComponent(Self.setAsideName, isDirectory: false) }

    /// The file's bytes, nil when there is no file.
    func read() async throws -> Data? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        do {
            return try Data(contentsOf: fileURL)
        } catch {
            throw LibraryError.invalid("Library couldn't read your collections. Check that you have access to them.")
        }
    }

    /// An atomic replace of `collections.json` with exactly `data`.
    func write(_ data: Data) async throws { try writeNow(data) }

    /// The write, synchronous, for the flush on quit: the folder made if
    /// missing, then an atomic replace of `collections.json` with `data`.
    func writeNow(_ data: Data) throws {
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            throw LibraryError.writeFailed(path: fileURL.path, reason: Self.reason(for: error))
        }
    }

    /// Renames a damaged file to `collections.json.bad`, replacing an older
    /// one; returns the set-aside path, as `CatalogStore.setAside` does.
    func setAside() async throws -> String {
        let manager = FileManager.default
        guard manager.fileExists(atPath: fileURL.path) else { return setAsideURL.path }
        do {
            if manager.fileExists(atPath: setAsideURL.path) { try manager.removeItem(at: setAsideURL) }
            try manager.moveItem(at: fileURL, to: setAsideURL)
        } catch {
            throw LibraryError.writeFailed(path: setAsideURL.path, reason: "Library couldn't set its damaged collections file aside.")
        }
        return setAsideURL.path
    }

    /// The plain words for a failed write.
    static func reason(for error: Error) -> String {
        switch (error as? CocoaError)?.code {
        case .fileWriteOutOfSpace?: "The disk is full."
        case .fileWriteNoPermission?, .fileWriteVolumeReadOnly?: "Library doesn't have permission to save your collections."
        default: "Library couldn't save your collections."
        }
    }
}
