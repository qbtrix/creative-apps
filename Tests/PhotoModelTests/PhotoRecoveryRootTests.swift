// PhotoRecoveryRootTests.swift (adopt-kernel-autosave AK-7 written, AK-8 on): Photo's recovery copies live in
// `<support>/Photo/Recovery` under the one suite root, `-SuiteSupportDir` reaches that folder, and `.ora` copies an
// earlier build left in `Application Support/Photo/Recovery` are offered once, never over a newer copy. Each test
// uses its own temporary home. Disabled until AK-8 puts LiveRecovery's store on `SuiteLocations.appFolder("Photo")`;
// AK-8 replaces `launch(arguments:home:)` below with the LiveRecovery call that builds the store and moves the old
// copies. Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
@testable import PhotoModel
import SuiteModel
import Testing

@Suite struct PhotoRecoveryRootTests {
    /// A fresh home folder under the temporary directory, removed after `body`.
    private func inTemporaryHome(_ body: (String) throws -> Void) throws {
        let home = FileManager.default.temporaryDirectory
            .appendingPathComponent("PhotoRecoveryRootTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: home) }
        try body(home.path)
    }

    private func package(_ marker: UInt8) -> PhotoPackage {
        PhotoPackage(files: [
            PhotoZip.mimetype: PhotoZip.mimetypeValue,
            "stack.xml": Data("<image w=\"4\" h=\"4\"><stack/></image>".utf8),
            "data/layer-1.png": Data([0x89, 0x50, 0x4E, 0x47, marker]),
        ])
    }

    /// Photo's recovery folder under the suite root.
    private func rootFolder(arguments: [String], home: String) -> URL {
        URL(fileURLWithPath: SuiteLocations.appFolder("Photo", arguments: arguments, home: home), isDirectory: true)
            .appendingPathComponent("Recovery", isDirectory: true)
    }

    /// Where earlier builds kept Photo's recovery copies.
    private func legacyFolder(home: String) -> URL {
        URL(fileURLWithPath: SuiteLocations.legacyFolder("Photo/Recovery", home: home), isDirectory: true)
    }

    private func oraFiles(in folder: URL) -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []).filter { $0.hasSuffix(".ora") }.sorted()
    }

    /// What a launch does: each old `.ora` follows `LegacySupport.plan` into the root's folder, then the store is
    /// built on that folder. AK-8 moves this into LiveRecovery (the store on `appFolder("Photo")`, the old folder
    /// moved once) and this helper calls it instead.
    private func launch(arguments: [String], home: String) throws -> any RecoveryStoring {
        let folder = rootFolder(arguments: arguments, home: home)
        let old = legacyFolder(home: home)
        for name in oraFiles(in: old) {
            let step = LegacySupport.plan(
                old: old.appendingPathComponent(name).path, new: folder.appendingPathComponent(name).path,
                exists: { FileManager.default.fileExists(atPath: $0) })
            if case .move(let from, let to) = step {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                try FileManager.default.moveItem(atPath: from, toPath: to)
            }
        }
        return LiveDocuments.recovery(directory: folder)
    }

    @Test(.disabled("waits on AK-8"))
    func photoFolder() throws {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        #expect(LiveRecovery.defaultDirectory.standardizedFileURL
            == rootFolder(arguments: [], home: home).standardizedFileURL)
        #expect(LiveRecovery.defaultDirectory.path.hasSuffix("/AfterGlow/Photo/Recovery"))
    }

    @Test(.disabled("waits on AK-8"))
    func writesUnderTheRoot() throws {
        try inTemporaryHome { home in
            let store = try launch(arguments: [], home: home)
            let entry = RecoveryEntry(documentName: "beach.png", savedAt: 100, package: package(1))
            try store.write(entry, window: "w1")
            let folder = home + "/Library/Application Support/AfterGlow/Photo/Recovery"
            #expect(oraFiles(in: URL(fileURLWithPath: folder, isDirectory: true)) == ["w1.ora"])
            #expect(oraFiles(in: legacyFolder(home: home)).isEmpty)
            #expect(try store.leftBehind() == [entry])
        }
    }

    @Test(.disabled("waits on AK-8"))
    func flagReachesPhoto() throws {
        try inTemporaryHome { home in
            let support = home + "/temp-support"
            let store = try launch(arguments: ["PhotoApp", SuiteLocations.supportDirFlag, support], home: home)
            let entry = RecoveryEntry(documentName: "flag.png", savedAt: 200, package: package(2))
            try store.write(entry, window: "w1")
            #expect(oraFiles(in: URL(fileURLWithPath: support + "/Photo/Recovery", isDirectory: true)) == ["w1.ora"])
            #expect(oraFiles(in: rootFolder(arguments: [], home: home)).isEmpty)
            #expect(try launch(arguments: [SuiteLocations.supportDirFlag, support], home: home).leftBehind() == [entry])
        }
    }

    @Test(.disabled("waits on AK-8"))
    func oldCopiesOffered() throws {
        try inTemporaryHome { home in
            let old = RecoveryEntry(documentName: "old.png", savedAt: 300, package: package(3))
            try LiveRecovery(directory: legacyFolder(home: home)).write(old, window: "w1")
            let store = try launch(arguments: [], home: home)
            #expect(try store.leftBehind() == [old])
            #expect(oraFiles(in: legacyFolder(home: home)).isEmpty)
            #expect(oraFiles(in: rootFolder(arguments: [], home: home)) == ["w1.ora"])
        }
    }

    @Test(.disabled("waits on AK-8"))
    func oldCopiesOfferedOnce() throws {
        try inTemporaryHome { home in
            let old = RecoveryEntry(documentName: "old.png", savedAt: 300, package: package(3))
            try LiveRecovery(directory: legacyFolder(home: home)).write(old, window: "w1")
            let first = try launch(arguments: [], home: home)
            #expect(try first.leftBehind() == [old])
            try first.discardAll()
            #expect(try launch(arguments: [], home: home).leftBehind().isEmpty)
        }
    }

    @Test(.disabled("waits on AK-8"))
    func neverOverANewerCopy() throws {
        try inTemporaryHome { home in
            let old = RecoveryEntry(documentName: "old.png", savedAt: 300, package: package(3))
            let newer = RecoveryEntry(documentName: "new.png", savedAt: 400, package: package(4))
            try LiveRecovery(directory: legacyFolder(home: home)).write(old, window: "w1")
            try LiveRecovery(directory: rootFolder(arguments: [], home: home)).write(newer, window: "w1")
            let store = try launch(arguments: [], home: home)
            #expect(try store.leftBehind() == [newer])
            #expect(oraFiles(in: legacyFolder(home: home)) == ["w1.ora"])
            #expect(try LiveRecovery(directory: legacyFolder(home: home)).leftBehind() == [old])
        }
    }

    @Test(.disabled("waits on AK-8"))
    func otherFilesStayPut() throws {
        try inTemporaryHome { home in
            let old = legacyFolder(home: home)
            try FileManager.default.createDirectory(at: old, withIntermediateDirectories: true)
            try Data("note".utf8).write(to: old.appendingPathComponent("notes.txt"))
            #expect(try launch(arguments: [], home: home).leftBehind().isEmpty)
            #expect(FileManager.default.fileExists(atPath: old.appendingPathComponent("notes.txt").path))
        }
    }
}
