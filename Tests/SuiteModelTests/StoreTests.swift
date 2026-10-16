// StoreTests.swift: the suite store's revisioned files never land a stale
// write and never show a partial file (SC-4a; docs/blueprints/suite.md, 2.6),
// and the support folder honours -SuiteSupportDir.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteModel
import Testing

@Suite struct StoreTests {
    /// A fresh folder per test; tests run in parallel.
    private func makeStore() -> FileStore {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("StoreTests-\(UUID().uuidString)").path
        return FileStore(folder: folder)
    }

    private func contents(_ store: FileStore, _ name: String) -> Data? {
        FileManager.default.contents(atPath: store.folder + "/" + name)
    }

    @Test func missingFileReadsAsNilAtRevisionZero() throws {
        let store = makeStore()
        let read = try store.read("recents.json", as: [String].self)
        #expect(read.value == nil)
        #expect(read.revision == 0)
        #expect(try store.readData("handoffs/none.aghandoff") == nil)
    }

    @Test func writeThenReadReturnsValueAndRevisionOne() throws {
        let store = makeStore()
        let revision = try store.write("recents.json", ["a"], expecting: 0)
        #expect(revision == 1)
        let read = try store.read("recents.json", as: [String].self)
        #expect(read.value == ["a"])
        #expect(read.revision == 1)
        #expect(try store.write("recents.json", ["a", "b"], expecting: 1) == 2)
        #expect(try store.read("recents.json", as: [String].self).value == ["a", "b"])
    }

    @Test func fileIsTheRevisionEnvelope() throws {
        let store = makeStore()
        try store.write("preferences.json", 7, expecting: 0)
        let text = contents(store, "preferences.json").map { String(decoding: $0, as: UTF8.self) }
        #expect(text == #"{"revision":1,"value":7}"#)
    }

    @Test func staleWriteThrowsAndLeavesTheFile() throws {
        let store = makeStore()
        try store.write("recents.json", ["first"], expecting: 0)
        try store.write("recents.json", ["second"], expecting: 1)
        let before = contents(store, "recents.json")
        #expect(throws: SuiteError.staleRevision) {
            try store.write("recents.json", ["stale"], expecting: 1)
        }
        #expect(throws: SuiteError.staleRevision) {
            try store.write("fresh.json", ["stale"], expecting: 3)
        }
        #expect(contents(store, "recents.json") == before)
        #expect(contents(store, "fresh.json") == nil)
        let read = try store.read("recents.json", as: [String].self)
        #expect(read.value == ["second"])
        #expect(read.revision == 2)
    }

    @Test func updateMergesAndBumps() throws {
        let store = makeStore()
        let first = try store.update("recents.json", empty: [String]()) { $0 + ["a"] }
        #expect(first.value == ["a"])
        #expect(first.revision == 1)
        let second = try store.update("recents.json", empty: [String]()) { $0 + ["b"] }
        #expect(second.value == ["a", "b"])
        #expect(second.revision == 2)
        let read = try store.read("recents.json", as: [String].self)
        #expect(read.value == ["a", "b"])
        #expect(read.revision == 2)
    }

    @Test func concurrentUpdatesAllLand() async throws {
        let store = makeStore()
        try await withThrowingTaskGroup(of: Void.self) { group in
            for i in 0..<8 {
                group.addTask {
                    _ = try store.update("assets/index.json", empty: [Int]()) { $0 + [i] }
                }
            }
            try await group.waitForAll()
        }
        let read = try store.read("assets/index.json", as: [Int].self)
        #expect(read.value?.sorted() == Array(0..<8))
        #expect(read.revision == 8)
    }

    @Test func crashBeforeRenameLeavesOldFileReadable() throws {
        let store = makeStore()
        try store.write("recents.json", ["kept"], expecting: 0)
        // A writer died after writing its temporary file, before the rename.
        let stray = store.folder + "/.recents.json.tmp-crashed"
        #expect(FileManager.default.createFile(atPath: stray, contents: Data(#"{"revis"#.utf8)))
        let read = try store.read("recents.json", as: [String].self)
        #expect(read.value == ["kept"])
        #expect(read.revision == 1)
        #expect(try store.write("recents.json", ["next"], expecting: 1) == 2)
        #expect(try store.read("recents.json", as: [String].self).value == ["next"])
    }

    @Test func damagedFileThrowsDamaged() throws {
        let store = makeStore()
        try store.writeData("recents.json", Data("not json".utf8))
        #expect(throws: SuiteError.damaged("your recent work list")) {
            try store.read("recents.json", as: [String].self)
        }
    }

    @Test func writeDataThenReadDataIsTheSameBytesWithNoEnvelope() throws {
        let store = makeStore()
        let bytes = Data([0x7B, 0x22, 0x69, 0x64, 0x22, 0x7D, 0x00, 0xFF])
        try store.writeData("handoffs/abc.aghandoff", bytes)
        #expect(try store.readData("handoffs/abc.aghandoff") == bytes)
        #expect(contents(store, "handoffs/abc.aghandoff") == bytes)
        let replaced = Data("second".utf8)
        try store.writeData("handoffs/abc.aghandoff", replaced)
        #expect(try store.readData("handoffs/abc.aghandoff") == replaced)
    }

    @Test func supportFolderHonoursSuiteSupportDir() {
        let home = "/Users/ana"
        #expect(SuiteLocations.supportFolder(arguments: [], home: home)
            == "/Users/ana/Library/Application Support/AfterGlow")
        #expect(SuiteLocations.supportFolder(arguments: ["App", "-SuiteSupportDir", "/tmp/s1"], home: home)
            == "/tmp/s1")
        #expect(SuiteLocations.supportFolder(arguments: ["App", "-SuiteSupportDir"], home: "/Users/ana/")
            == "/Users/ana/Library/Application Support/AfterGlow")
    }
}
