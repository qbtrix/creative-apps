// LiveRecoveryTests.swift: D-4b of photo-documents, history-panel PH-6.
// LiveRecovery keeps one `<window>.ora` (and RecoveryFolder's `<window>.json`)
// per window under "Recovery/" in its folder: a write round-trips through
// leftBehind (name, time, package), replaces the window's last one, and never
// leaves a partial file; a damaged file is removed and skipped; a window name
// never escapes the folder. Each test uses its own temporary folder. Runs on
// Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
@testable import PhotoModel
import Testing

@Suite struct LiveRecoveryTests {
    /// A fresh folder under the temporary directory, removed after `body`.
    private func inTemporaryFolder(_ body: (URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("LiveRecoveryTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try body(root)
    }

    private func package(_ marker: UInt8) -> PhotoPackage {
        PhotoPackage(files: [
            PhotoZip.mimetype: PhotoZip.mimetypeValue,
            "stack.xml": Data("<image w=\"4\" h=\"4\"><stack/></image>".utf8),
            "data/layer-1.png": Data([0x89, 0x50, 0x4E, 0x47, marker]),
        ])
    }

    private func files(in folder: URL) throws -> [String] {  // locks left out
        try FileManager.default.contentsOfDirectory(atPath: folder.path).filter { !$0.hasSuffix(".lock") }.sorted()
    }

    private func copies(in folder: URL) throws -> [String] { try files(in: folder.appendingPathComponent("Recovery")) }

    @Test func writeThenLeftBehindGivesTheEntry() throws {
        try inTemporaryFolder { folder in
            let store = LiveDocuments.recovery(directory: folder.appendingPathComponent("Recovery"))
            #expect(store.unavailableHelp == nil)
            #expect(try store.leftBehind().isEmpty)
            let entry = RecoveryEntry(documentName: "beach.png", savedAt: 1_700_000_000.123_456, package: package(1))
            try store.write(entry, window: "w1")
            #expect(try store.leftBehind() == [entry])
            let untitled = RecoveryEntry(documentName: nil, savedAt: 1_700_000_001.5, package: package(2))
            try store.write(untitled, window: "w1")
            #expect(try store.leftBehind() == [untitled])
        }
    }

    @Test func twoWindowsGiveTwoEntriesNewestFirst() throws {
        try inTemporaryFolder { folder in
            let store = LiveRecovery(directory: folder)
            let older = RecoveryEntry(documentName: "a", savedAt: 100, package: package(1))
            let newer = RecoveryEntry(documentName: "b", savedAt: 200, package: package(2))
            try store.write(newer, window: "first")
            try store.write(older, window: "second")
            #expect(try store.leftBehind() == [newer, older])
            #expect(try copies(in: folder) == ["first.json", "first.ora", "second.json", "second.ora"])

            try store.discard(window: "first")
            #expect(try store.leftBehind() == [older])
            try store.discard(window: "never-written")
            try store.write(newer, window: "third")
            try store.discardAll()
            #expect(try store.leftBehind().isEmpty)
            #expect(!FileManager.default.fileExists(atPath: folder.appendingPathComponent("Recovery").path))
        }
    }

    @Test func aDamagedFileIsRemovedAndSkipped() throws {
        try inTemporaryFolder { folder in
            let store = LiveRecovery(directory: folder)
            let entry = RecoveryEntry(documentName: "kept", savedAt: 5, package: package(3))
            try store.write(entry, window: "good")
            let recovery = folder.appendingPathComponent("Recovery")
            let damaged = recovery.appendingPathComponent("bad.ora")
            try Data("not a zip".utf8).write(to: damaged)
            try Data(#"{"name":"bad","savedAt":9}"#.utf8).write(to: recovery.appendingPathComponent("bad.json"))
            try Data("notes".utf8).write(to: recovery.appendingPathComponent("readme.txt"))
            #expect(try store.leftBehind() == [entry])
            #expect(!FileManager.default.fileExists(atPath: damaged.path))
            #expect(try copies(in: folder) == ["good.json", "good.ora", "readme.txt"])
        }
    }

    @Test func aThrowingWriteLeavesNoPartialFile() throws {
        try inTemporaryFolder { root in
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let notAFolder = root.appendingPathComponent("Recovery")
            try Data("a file".utf8).write(to: notAFolder)
            let store = LiveRecovery(directory: root)
            let entry = RecoveryEntry(documentName: "x", savedAt: 1, package: package(4))
            #expect(throws: (any Error).self) { try store.write(entry, window: "w") }
            #expect(try files(in: root) == ["Recovery"])
            #expect(try Data(contentsOf: notAFolder) == Data("a file".utf8))
            #expect(try store.leftBehind().isEmpty)
        }
    }

    @Test func aWriteLeavesOnlyTheWindowsFile() throws {
        try inTemporaryFolder { folder in
            let store = LiveRecovery(directory: folder)
            for step in 0..<3 {
                try store.write(RecoveryEntry(documentName: "n", savedAt: Double(step), package: package(UInt8(step))),
                                window: "w")
            }
            #expect(try copies(in: folder) == ["w.json", "w.ora"])
        }
    }

    @Test func aWindowNameWithSlashesStaysInsideTheFolder() throws {
        try inTemporaryFolder { root in
            let folder = root.appendingPathComponent("Recovery")
            let store = LiveRecovery(directory: root)
            let entry = RecoveryEntry(documentName: "slash", savedAt: 9, package: package(5))
            try store.write(entry, window: "../escape/..")
            try store.write(entry, window: "a/b")
            try store.write(entry, window: "a_b")
            #expect(try files(in: root) == ["Recovery"])
            let names = try files(in: folder)
            #expect(names.count == 6)
            #expect(names.allSatisfy { ($0.hasSuffix(".ora") || $0.hasSuffix(".json")) && !$0.contains("/") && !$0.hasPrefix(".") })
            #expect(try store.leftBehind().count == 3)
            try store.discard(window: "a/b")
            #expect(try store.leftBehind().count == 2)
        }
    }

    @Test func aMissingFolderGivesAnEmptyList() throws {
        try inTemporaryFolder { root in
            let folder = root.appendingPathComponent("Recovery", isDirectory: true)
            let store = LiveRecovery(directory: folder)
            #expect(try store.leftBehind().isEmpty)
            try store.discardAll()
            try store.discard(window: "w")
            #expect(!FileManager.default.fileExists(atPath: folder.path))
        }
    }

    @Test func theDefaultFolderIsApplicationSupportPhotoRecovery() {
        let store = LiveRecovery(directory: LiveRecovery.defaultDirectory)
        #expect(LiveRecovery.defaultDirectory.path.hasSuffix("Photo"))
        #expect(store.file(for: "w").path.hasSuffix("Photo/Recovery/w.ora"))
        #expect(LiveDocuments.recovery().unavailableHelp == nil)
    }
}
