// LibraryCollectionsStoreTests.swift: CollectionsStore, the collections file
// on the file system (filters-collections FC-15 check row; slice FC-e).
// Written before its code (FC-13): every test waits on FC-15, which builds
// the store and drops the `.disabled` traits. Each test works in a fresh temp
// folder: no file reads as nil; a write round-trips and leaves only
// collections.json; writeNow has written the bytes when it returns;
// setAside renames to collections.json.bad, replacing an older one, and the
// next read is nil. macOS only.
#if os(macOS)
import Foundation
import LibraryModel
import Testing

@testable import LibraryApp

@Suite struct LibraryCollectionsStoreTests {
    /// A store over a fresh, existing temp folder.
    private func store() throws -> CollectionsStore {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("LibraryCollectionsStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return CollectionsStore(directory: url.path)
    }

    private func names(in store: CollectionsStore) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: store.folder.path).sorted()
    }

    @Test(.disabled("waits on FC-15")) func readIsNilWithNoFile() async throws {
        let store = try store()
        defer { try? FileManager.default.removeItem(at: store.folder) }
        #expect(try await store.read() == nil)
    }

    @Test(.disabled("waits on FC-15")) func writeThenReadGivesTheBytes() async throws {
        let store = try store()
        defer { try? FileManager.default.removeItem(at: store.folder) }
        let data = Data("{\n  \"version\" : 1\n}\n".utf8)
        try await store.write(data)
        #expect(try await store.read() == data)
        let second = Data("{\n  \"collections\" : [\n\n  ],\n  \"version\" : 1\n}\n".utf8)
        try await store.write(second)
        #expect(try await store.read() == second)
        #expect(try names(in: store) == ["collections.json"])
    }

    @Test(.disabled("waits on FC-15")) func writeNowWritesBeforeItReturns() throws {
        let store = try store()
        defer { try? FileManager.default.removeItem(at: store.folder) }
        let data = Data("{\n  \"version\" : 1\n}\n".utf8)
        try store.writeNow(data)
        #expect(try Data(contentsOf: store.fileURL) == data)
        #expect(try names(in: store) == ["collections.json"])
    }

    @Test(.disabled("waits on FC-15")) func setAsideRenamesToBadReplacingAnOlderOne() async throws {
        let store = try store()
        defer { try? FileManager.default.removeItem(at: store.folder) }
        try Data("old bad".utf8).write(to: store.setAsideURL)
        try store.writeNow(Data("not json".utf8))
        let path = try await store.setAside()
        #expect(URL(fileURLWithPath: path).lastPathComponent == "collections.json.bad")
        #expect(try Data(contentsOf: store.setAsideURL) == Data("not json".utf8))
        #expect(try await store.read() == nil)
        #expect(try names(in: store) == ["collections.json.bad"])
    }

    @Test func theFileSitsBesideTheCatalog() {
        let store = CollectionsStore(directory: "/tmp/LibraryCollectionsStoreTests")
        #expect(store.fileURL.path == "/tmp/LibraryCollectionsStoreTests/collections.json")
        #expect(store.setAsideURL.lastPathComponent == "collections.json.bad")
    }
}
#endif
