// Platform/CatalogStore.swift: spine stub of the CatalogStoring platform
// adapter. The persist feature replaces it with the file conformance
// (Application Support or -LibraryCatalogDir, atomic write, .bad rename).
// Until then every call throws its "not built yet" reason.
import Foundation
import LibraryModel

struct CatalogStore: CatalogStoring {
    static let notBuilt = LibraryError.invalid("The catalog file isn't built yet (persist).")

    func read() async throws -> Data? { throw Self.notBuilt }
    func write(_ data: Data) async throws { throw Self.notBuilt }
    func setAside() async throws -> String { throw Self.notBuilt }
}
