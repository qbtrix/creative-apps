// Platform/CatalogStore.swift: CatalogStoring on the file system (persist
// PE-4). `catalog.json` lives in the -LibraryCatalogDir folder when the app
// was launched with one, else in Application Support/Library; the folder is
// made on the first write. A write lands atomically (Foundation writes an
// auxiliary file and renames it over the catalog), so a reader never sees a
// partial file and nothing temporary is left beside it. `writeNow` is the
// same write, synchronous, for the flush on quit. `setAside` renames a
// damaged catalog to `catalog.json.bad`, replacing an older one. Foundation
// FileManager only.
import Foundation
import LibraryModel

struct CatalogStore: CatalogStoring {
    static let fileName = "catalog.json"
    static let setAsideName = "catalog.json.bad"

    /// The folder `catalog.json` lives in.
    let folder: URL

    /// `directory` is the -LibraryCatalogDir path; nil means Application
    /// Support/Library.
    init(directory: String? = LibraryLaunch(arguments: ProcessInfo.processInfo.arguments).catalogDir) {
        folder = directory.map { URL(fileURLWithPath: $0, isDirectory: true) } ?? Self.defaultFolder
    }

    /// Application Support/Library in the user's domain; the temporary folder
    /// when the system has none to give.
    static var defaultFolder: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        return (support ?? FileManager.default.temporaryDirectory).appendingPathComponent("Library", isDirectory: true)
    }

    var fileURL: URL { folder.appendingPathComponent(Self.fileName, isDirectory: false) }
    var setAsideURL: URL { folder.appendingPathComponent(Self.setAsideName, isDirectory: false) }

    func read() async throws -> Data? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        do {
            return try Data(contentsOf: fileURL)
        } catch {
            throw LibraryError.invalid("Library couldn't read its catalog. Check that you have access to it.")
        }
    }

    func write(_ data: Data) async throws { try writeNow(data) }

    /// The write, synchronous: the folder made if missing, then an atomic
    /// replace of `catalog.json` with exactly `data`.
    func writeNow(_ data: Data) throws {
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            throw LibraryError.writeFailed(path: fileURL.path, reason: Self.reason(for: error))
        }
    }

    func setAside() async throws -> String {
        let manager = FileManager.default
        guard manager.fileExists(atPath: fileURL.path) else { return setAsideURL.path }
        do {
            if manager.fileExists(atPath: setAsideURL.path) { try manager.removeItem(at: setAsideURL) }
            try manager.moveItem(at: fileURL, to: setAsideURL)
        } catch {
            throw LibraryError.writeFailed(path: setAsideURL.path, reason: "Library couldn't set its damaged catalog aside.")
        }
        return setAsideURL.path
    }

    /// The plain words for a failed write.
    static func reason(for error: Error) -> String {
        switch (error as? CocoaError)?.code {
        case .fileWriteOutOfSpace?: "The disk is full."
        case .fileWriteNoPermission?, .fileWriteVolumeReadOnly?: "Library doesn't have permission to save its catalog."
        default: "Library couldn't save its catalog."
        }
    }
}
