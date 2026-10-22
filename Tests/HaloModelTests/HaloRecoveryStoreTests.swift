// HaloRecoveryStoreTests.swift (autosave-history HA-7b): where Halo's autosave writes, and a
// restore into the open window. A `-SuiteSupportDir` wins over the journeys' ignore-state flag,
// that flag alone (or the caller's `ignoringState`) keeps no copies, a plain launch writes under
// the suite root's Halo folder, and a written copy lands in `<support>/Halo/Recovery/` as a
// `.halo` file. `restoreRecovered` puts the copy's project in place, edited, unsaved, with no
// path or steps and the recent list kept. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
@testable import HaloModel
import SuiteModel
import Testing

@Suite struct HaloRecoveryStoreTests {
    static let ignore = ["-ApplePersistenceIgnoreState", "YES"]

    @Test func supportDirWinsOverIgnoredState() {
        let path = HaloRecoveryStore.folderPath(arguments: Self.ignore + ["-SuiteSupportDir", "/tmp/s"], home: "/Users/a")
        #expect(path == "/tmp/s/Halo")
        #expect(HaloRecoveryStore.folderPath(arguments: ["-SuiteSupportDir", "/tmp/s"], home: "/", ignoringState: true) == "/tmp/s/Halo")
    }

    @Test func ignoredStateWithoutASupportDirKeepsNone() {
        #expect(HaloRecoveryStore.folderPath(arguments: Self.ignore, home: "/Users/a") == nil)
        #expect(HaloRecoveryStore.folderPath(arguments: ["-ApplePersistenceIgnoreState", "true"], home: "/Users/a") == nil)
        #expect(HaloRecoveryStore.folder(arguments: Self.ignore + ["-SuiteSupportDir", ""], home: "/Users/a") == nil)
        #expect(HaloRecoveryStore.folder(arguments: [], home: "/Users/a", ignoringState: true) == nil)
    }

    @Test func plainLaunchWritesUnderTheSuiteRoot() {
        let path = HaloRecoveryStore.folderPath(arguments: ["-ApplePersistenceIgnoreState", "NO"], home: "/Users/a")
        #expect(path == "/Users/a/Library/Application Support/AfterGlow/Halo")
    }

    @Test func aWrittenCopyIsAHaloFileLeftBehind() throws {
        let support = FileManager.default.temporaryDirectory.appendingPathComponent("halo-recovery-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: support) }
        let folder = try #require(HaloRecoveryStore.folder(arguments: Self.ignore + ["-SuiteSupportDir", support.path], home: "/"))
        try folder.write(Data("comp".utf8), window: "halo.main", name: "title", at: 10)
        #expect(try folder.leftBehind().map(\.name) == ["title"])
        #expect(FileManager.default.fileExists(atPath: support.appendingPathComponent("Halo/Recovery/halo.main.halo").path))
    }

    @Test func restoreRecoveredReplacesTheOpenProject() throws {
        var source = HaloProject(services: .live, document: try #require(HaloFixtures.project("keyed")))
        source.setRecent([HaloRecentFile(name: "a", path: "/a.halo")])
        var window = source
        window.didSave(name: "w", path: "/w.halo")
        window.newComposition()
        #expect(!window.historyListing.steps.isEmpty)
        try window.restoreRecovered(from: try source.recoveryBytes(), name: "title")
        #expect(window.compositions == source.compositions)
        #expect(window.file.unsaved)
        #expect(window.file.path == nil)
        #expect(window.windowTitle == "title")
        #expect(window.historyListing.steps.isEmpty)
        #expect(window.recent.map(\.path) == ["/w.halo", "/a.halo"])
    }

    @Test func damagedBytesLeaveTheProjectAsItWas() throws {
        var window = HaloProject(services: .live, document: try #require(HaloFixtures.project("keyed")))
        let before = window.compositions
        #expect(throws: (any Error).self) { try window.restoreRecovered(from: Data("no".utf8), name: "title") }
        #expect(window.compositions == before)
        #expect(!window.file.unsaved)
    }
}
