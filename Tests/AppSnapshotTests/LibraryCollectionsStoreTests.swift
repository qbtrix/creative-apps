// LibraryCollectionsStoreTests.swift: CollectionsStore on the file system
// (filters-collections FC-15 check row; slice FC-e). Written before its code
// (FC-13); FC-15 enabled it. Each test uses a fresh temp folder.
#if os(macOS)
import Foundation
import LibraryModel
import Testing

@testable import LibraryApp

@Suite struct LibraryCollectionsStoreTests {
    private func store() throws -> CollectionsStore {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("LibraryCollectionsStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return CollectionsStore(directory: url.path)
    }
    private func names(in store: CollectionsStore) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: store.folder.path).sorted()
    }

    /// No file reads nil; writes round-trip; writeNow has written when it returns.
    @Test func readsNilThenWritesRoundTrip() async throws {
        let store = try store()
        defer { try? FileManager.default.removeItem(at: store.folder) }
        #expect(try await store.read() == nil)
        for text in ["{\n  \"version\" : 1\n}\n", "{\n  \"collections\" : [\n\n  ],\n  \"version\" : 1\n}\n"] {
            try await store.write(Data(text.utf8))
            #expect(try await store.read() == Data(text.utf8))
        }
        try store.writeNow(Data("{}\n".utf8))
        #expect(try Data(contentsOf: store.fileURL) == Data("{}\n".utf8))
        #expect(try names(in: store) == ["collections.json"])
    }

    @Test func setAsideRenamesToBadReplacingAnOlderOne() async throws {
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
