// Platform/CatalogStore.swift: CatalogStoring on the file system (persist
// PE-4). `catalog.json` lives in the -LibraryCatalogDir folder when the app
// was launched with one, else in Library's folder under the suite root
// (adopt-kernel-autosave AK-6); the folder is made on the first write, and an
// earlier build's catalog moves in once before the first read. A write lands atomically (Foundation writes an
// auxiliary file and renames it over the catalog), so a reader never sees a
// partial file and nothing temporary is left beside it. `writeNow` is the
// same write, synchronous, for the flush on quit. `setAside` renames a
// damaged catalog to `catalog.json.bad`, replacing an older one. Foundation
// FileManager only.
import Foundation
import LibraryModel
import SuiteModel

struct CatalogStore: CatalogStoring {
    static let fileName = "catalog.json"
    static let setAsideName = "catalog.json.bad"

    /// The folder `catalog.json` lives in.
    let folder: URL
    /// True when the folder came from the launch, so an earlier build's
    /// catalog may move into it; false for a folder a test names.
    let fromLaunch: Bool

    /// `directory` is a folder a test names; nil means the launch's
    /// (`LibrarySupport.catalogFolder`: -LibraryCatalogDir, else Library's
    /// folder under the suite root).
    init(directory: String? = nil) {
        let path = directory ?? LibrarySupport.catalogFolder(arguments: ProcessInfo.processInfo.arguments, home: NSHomeDirectory())
        folder = URL(fileURLWithPath: path, isDirectory: true)
        fromLaunch = directory == nil
    }

    /// Where an earlier build kept Library's files (Application Support/
    /// Library). Collections still live here until their own move.
    static var defaultFolder: URL {
        URL(fileURLWithPath: SuiteLocations.legacyFolder("Library", home: NSHomeDirectory()), isDirectory: true)
    }

    var fileURL: URL { folder.appendingPathComponent(Self.fileName, isDirectory: false) }
    var setAsideURL: URL { folder.appendingPathComponent(Self.setAsideName, isDirectory: false) }

    /// Moves an earlier build's catalog here once, before the first load, by
    /// `LibrarySupport.legacyCatalogStep`: never over a catalog already here
    /// (both are kept) and never deleting. A failed move leaves the old file.
    func moveLegacyCatalog() {
        guard fromLaunch else { return }
        let manager = FileManager.default
        let step = LibrarySupport.legacyCatalogStep(
            arguments: ProcessInfo.processInfo.arguments, home: NSHomeDirectory(),
            exists: { manager.fileExists(atPath: $0) })
        guard case let .move(from, to) = step else { return }
        try? manager.createDirectory(at: folder, withIntermediateDirectories: true)
        try? manager.moveItem(atPath: from, toPath: to)
    }

    func read() async throws -> Data? {
        moveLegacyCatalog()
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
