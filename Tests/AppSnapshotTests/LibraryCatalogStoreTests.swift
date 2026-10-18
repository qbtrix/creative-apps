// LibraryCatalogStoreTests.swift: CatalogStore, Library's CatalogStoring on
// the file system (persist PE-4). Each test works in a fresh temp folder:
// no file reads as nil; a write round-trips and leaves only catalog.json;
// writeNow writes the same bytes; setAside renames to catalog.json.bad,
// replacing an older one, and the next read is nil; a missing folder is
// made by the first write. macOS only.
#if os(macOS)
import Foundation
import LibraryModel
import Testing

@testable import LibraryApp

@Suite struct LibraryCatalogStoreTests {
    /// A path in the temp folder that doesn't exist yet.
    private func freshPath() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("LibraryCatalogStoreTests-\(UUID().uuidString)")
    }

    /// A store over a fresh, existing temp folder.
    private func store() throws -> CatalogStore {
        let url = freshPath()
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return CatalogStore(directory: url.path)
    }

    private func names(in store: CatalogStore) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: store.folder.path).sorted()
    }

    @Test func readIsNilWithNoFile() async throws {
        #expect(try await store().read() == nil)
    }

    @Test func writeThenReadRoundTripsAndLeavesNoTemporaryFile() async throws {
        let store = try store()
        let data = Data("{\"version\" : 1}\n".utf8)
        try await store.write(data)
        #expect(try await store.read() == data)
        let second = Data("{\"photos\" : [], \"version\" : 1}\n".utf8)
        try await store.write(second)
        #expect(try await store.read() == second)
        #expect(try names(in: store) == ["catalog.json"])
    }

    @Test func writeNowWritesTheSameBytes() async throws {
        let store = try store()
        let data = Data("{\"photos\" : [], \"version\" : 1}\n".utf8)
        try store.writeNow(data)
        #expect(try Data(contentsOf: store.fileURL) == data)
        #expect(try await store.read() == data)
        #expect(try names(in: store) == ["catalog.json"])
    }

    @Test func setAsideRenamesToBadReplacingAnOlderOne() async throws {
        let store = try store()
        try Data("old bad".utf8).write(to: store.setAsideURL)
        try await store.write(Data("not json".utf8))
        let path = try await store.setAside()
        #expect(path == store.setAsideURL.path)
        #expect(URL(fileURLWithPath: path).lastPathComponent == "catalog.json.bad")
        #expect(try Data(contentsOf: store.setAsideURL) == Data("not json".utf8))
        #expect(try await store.read() == nil)
        #expect(try names(in: store) == ["catalog.json.bad"])
    }

    @Test func aMissingFolderIsCreated() async throws {
        let folder = freshPath().appendingPathComponent("nested", isDirectory: true)
        let store = CatalogStore(directory: folder.path)
        #expect(try await store.read() == nil)
        let data = Data("{}\n".utf8)
        try await store.write(data)
        #expect(try await store.read() == data)
    }

    @Test func noDirectoryMeansApplicationSupportLibrary() {
        let store = CatalogStore(directory: nil)
        #expect(store.folder.lastPathComponent == "Library")
        #expect(store.fileURL.lastPathComponent == "catalog.json")
    }
}
#endif
