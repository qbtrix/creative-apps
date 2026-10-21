// Platform/CollectionsStore.swift: the collections file on the file system
// (filters-collections FC-4 stub; FC-15 builds it). `collections.json` lives
// beside `catalog.json`: in the -LibraryCatalogDir folder when the app was
// launched with one, else in Application Support/Library. Until FC-15 every
// call throws "The collections file isn't built yet (filters-collections).",
// and the Model's `fileUnavailable` keeps the hooks from asking for a write.
// Foundation only.
import Foundation
import LibraryModel

struct CollectionsStore: Sendable {
    static let fileName = "collections.json"
    static let setAsideName = "collections.json.bad"

    /// Thrown by every call until FC-15 builds the store.
    static let unbuilt = LibraryError.invalid("The collections file isn't built yet (filters-collections).")

    /// The folder `collections.json` lives in.
    let folder: URL

    init(directory: String) {
        folder = URL(fileURLWithPath: directory, isDirectory: true)
    }

    var fileURL: URL { folder.appendingPathComponent(Self.fileName, isDirectory: false) }
    var setAsideURL: URL { folder.appendingPathComponent(Self.setAsideName, isDirectory: false) }

    /// The file's bytes, nil when there is no file.
    func read() async throws -> Data? { throw Self.unbuilt }

    /// An atomic replace of `collections.json` with exactly `data`.
    func write(_ data: Data) async throws { try writeNow(data) }

    /// The write, synchronous, for the flush on quit.
    func writeNow(_ data: Data) throws { throw Self.unbuilt }

    /// Renames a damaged file to `collections.json.bad`, replacing an older
    /// one; returns the set-aside path.
    func setAside() async throws -> String { throw Self.unbuilt }
}
