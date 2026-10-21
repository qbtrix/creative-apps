// RecoveryFolderTests.swift (autosave-history AH-1 written, AH-7 on): the recovery files over the suite
// store, in a temp folder. A write reads back, two windows come newest first, a pair whose JSON is missing or
// damaged is dropped and deleted, and discard removes both files.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteModel
import Testing

@Suite struct RecoveryFolderTests {
    /// A folder over a fresh store per test (tests run in parallel), and the store under it.
    static func make() -> (RecoveryFolder, FileStore) {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("RecoveryFolderTests-\(UUID().uuidString)").path
        let store = FileStore(folder: folder)
        return (RecoveryFolder(store: store, ext: "fake"), store)
    }
    static func exists(_ store: FileStore, _ name: String) -> Bool {
        FileManager.default.fileExists(atPath: store.folder + "/Recovery/" + name)
    }

    @Test func writeThenLeftBehind() throws {
        let (folder, store) = Self.make()
        try folder.write(Data("one".utf8), window: "w1", name: "Poster", at: 100)
        #expect(try folder.leftBehind() == [RecoveryItem(window: "w1", name: "Poster", savedAt: 100, data: Data("one".utf8))])
        #expect(Self.exists(store, "w1.fake") && Self.exists(store, "w1.json"))
    }
    @Test func emptyFolderLeavesNothing() throws {
        #expect(try Self.make().0.leftBehind().isEmpty)
    }
    @Test func newestFirst() throws {
        let (folder, _) = Self.make()
        try folder.write(Data("a".utf8), window: "w1", name: nil, at: 100)
        try folder.write(Data("b".utf8), window: "w2", name: "Untitled", at: 200)
        #expect(try folder.leftBehind().map(\.window) == ["w2", "w1"])
        #expect(try folder.leftBehind().first?.name == "Untitled")
    }
    @Test func damagedPairDropped() throws {
        let (folder, store) = Self.make()
        try folder.write(Data("a".utf8), window: "w1", name: nil, at: 100)
        try folder.write(Data("b".utf8), window: "w2", name: nil, at: 200)
        try folder.write(Data("c".utf8), window: "w3", name: nil, at: 300)
        try FileManager.default.removeItem(atPath: store.folder + "/Recovery/w2.json")
        try store.writeData("Recovery/w3.json", Data("not json".utf8))
        #expect(try folder.leftBehind().map(\.window) == ["w1"])
        #expect(!Self.exists(store, "w2.fake") && !Self.exists(store, "w3.fake") && !Self.exists(store, "w3.json"))
    }
    @Test func discardRemovesBoth() throws {
        let (folder, store) = Self.make()
        try folder.write(Data("a".utf8), window: "w1", name: nil, at: 100)
        try folder.write(Data("b".utf8), window: "w2", name: nil, at: 200)
        try folder.discard(window: "w1")
        #expect(!Self.exists(store, "w1.fake") && !Self.exists(store, "w1.json"))
        #expect(try folder.leftBehind().map(\.window) == ["w2"])
        try folder.discard(window: "none")
        try folder.discardAll()
        #expect(try folder.leftBehind().isEmpty)
    }
}
