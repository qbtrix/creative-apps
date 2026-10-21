// PhotoRecoveryFolderTests.swift: history-panel PH-6. Autosave through RecoveryFolder on AutosaveSchedule: an edit
// writes one .ora after the delay, a save removes it, a relaunch offers the newest, Restore gives the same layers
// back dirty, and the encode runs off main. Each test has its own temporary folder. Linux and macOS.
import Foundation
import CoreRaster
@testable import PhotoModel
import SuiteKernel
import SuiteModel
import Testing

@Suite struct PhotoRecoveryFolderTests {
    /// A fresh folder under the temporary directory, removed after `body`.
    private func inTemporaryFolder(_ body: (URL) async throws -> Void) async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PhotoRecoveryFolderTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try await body(root)
    }

    /// The layered fixture on live services that autosave into `folder`,
    /// saved, then edited once: dirty.
    private func editedFixture(in folder: URL) throws -> PhotoWorkspace {
        var workspace = try PhotoWorkspace.fixture(.layered)
        workspace.services = PhotoServices.live.recovering(in: folder)
        workspace.didSave(as: "beach.ora", kind: .document)
        workspace.adjust(.exposure(0.25))
        return workspace
    }

    private func copies(in folder: URL) -> [String] {  // the .ora copies under Recovery/
        let names = (try? FileManager.default.contentsOfDirectory(
            atPath: folder.appendingPathComponent("Recovery").path)) ?? []
        return names.filter { $0.hasSuffix(".ora") }.sorted()
    }

    @Test func anEditWritesOneOraAfterTheDelay() async throws {
        try await inTemporaryFolder { root in
            let workspace = try editedFixture(in: root)
            let folder = try #require(workspace.services.recoveryFolder)
            var schedule = AutosaveSchedule(delay: PhotoWorkspace.autosaveDelay)
            schedule.noteEdit(at: 100)
            #expect(schedule.begin(now: 104, dirty: workspace.isDirty) == nil)
            let due = schedule.begin(now: 105, dirty: workspace.isDirty)
            let ticket = try #require(due)
            try folder.write(try workspace.recoveryBytes(codec: RawCodec()), window: "w1",
                             name: workspace.documentName, at: 105)
            #expect(schedule.finish(ticket, wrote: true) == .keep)
            #expect(copies(in: root) == ["w1.ora"])
            #expect(try folder.leftBehind().map(\.name) == ["beach.ora"])
        }
    }

    @Test func saveRemovesRecovery() async throws {
        try await inTemporaryFolder { root in
            var workspace = try editedFixture(in: root)
            let store = workspace.services.recovery
            let entry = try workspace.recoveryEntry(now: 1_700_000_000, codec: RawCodec())
            try store.write(try #require(entry), window: "w1")
            #expect(try store.leftBehind().count == 1)
            workspace.didSave(as: "beach.ora", kind: .document)
            #expect(!workspace.isDirty)
            try store.discard(window: "w1")
            #expect(try store.leftBehind().isEmpty)
            #expect(copies(in: root).isEmpty)
        }
    }

    @Test func newestOffered() async throws {
        try await inTemporaryFolder { root in
            var older = try editedFixture(in: root)
            older.didSave(as: "older.ora", kind: .document)
            older.adjust(.exposure(-0.5))
            let edited = try editedFixture(in: root)
            let folder = try #require(edited.services.recoveryFolder)
            try folder.write(try older.recoveryBytes(codec: RawCodec()), window: "a", name: older.documentName, at: 100)
            try folder.write(try edited.recoveryBytes(codec: RawCodec()), window: "b", name: edited.documentName, at: 200)

            // A relaunch: a new store over the same folder.
            let relaunched = PhotoServices.live.recovering(in: root)
            #expect(try relaunched.recovery.leftBehind().map(\.documentName) == ["beach.ora", "older.ora"])
            let newest = try relaunched.recoveryFolder?.leftBehind().first
            let offered = try #require(newest)
            #expect(offered.window == "b")

            let restored = try await PhotoWorkspace.recovered(
                from: offered.data, name: offered.name, services: relaunched, codec: RawCodec())
            #expect(try restored.snapshot() == edited.snapshot())
            #expect(restored.isDirty)
            #expect(restored.fileKind == nil)
            #expect(restored.documentName == "beach.ora")
        }
    }

    @Test func theDefaultsRoundTripTheNameInTheBytes() async throws {
        let white = DecodedImage(rgba8: [UInt8](repeating: 255, count: 4 * 3 * 4), width: 4, height: 3)
        var workspace = PhotoWorkspace(services: .live)
        try workspace.openImage(try RawCodec().encode(white, as: .png, quality: 1), name: "a.png", codec: RawCodec())
        workspace.addLayer()
        let restored = try await PhotoWorkspace.recovered(from: try workspace.recoveryBytes(), name: nil)
        #expect(restored.documentName == "a.png")
        #expect(try restored.snapshot() == workspace.snapshot())
        #expect(restored.isDirty)
        let renamed = try await PhotoWorkspace.recovered(from: try workspace.recoveryBytes(), name: "b.png")
        #expect(renamed.documentName == "b.png")
    }

    @Test func damagedBytesThrow() async {
        await #expect(throws: (any Error).self) {
            _ = try await PhotoWorkspace.recovered(from: Data("not a zip".utf8), name: "x")
        }
    }

    @Test func restoringKeepsTheWindowsServices() async throws {
        try await inTemporaryFolder { root in
            let edited = try editedFixture(in: root)
            let restored = try await PhotoWorkspace.recovered(
                from: try edited.recoveryBytes(codec: RawCodec()), name: nil, services: .live, codec: RawCodec())
            #expect(restored.services.recoveryFolder != nil)
            var window = PhotoWorkspace(services: .fake)
            window.restoreRecovered(restored)
            #expect(try window.snapshot() == edited.snapshot())
            #expect(window.services.recoveryFolder == nil)
            #expect(window.isDirty)
        }
    }

    /// RawCodec that notes whether it ran on the main thread.
    final class SpyCodec: PhotoImageCodec, @unchecked Sendable {
        private let lock = NSLock()
        private var threads: [Bool] = []
        var ranOnMain: [Bool] { lock.withLock { threads } }
        func decode(_ data: Data, longestSide: Int?) throws -> DecodedImage {
            try RawCodec().decode(data, longestSide: longestSide)
        }
        func encode(_ image: DecodedImage, as format: ImageFormat, quality: Double) throws -> Data {
            lock.withLock { threads.append(Thread.isMainThread) }
            return try RawCodec().encode(image, as: format, quality: quality)
        }
    }

    @MainActor @Test func encodesOffMain() async throws {
        var workspace = try editedFixture(in: FileManager.default.temporaryDirectory
            .appendingPathComponent("PhotoRecoveryFolderTests-\(UUID().uuidString)", isDirectory: true))
        let expected = try workspace.recoveryBytes(codec: RawCodec())
        let spy = SpyCodec()
        let encoder = workspace.recoveryEncoder(codec: spy)
        #expect(spy.ranOnMain.isEmpty, "making the encoder encodes nothing")
        workspace.adjust(.exposure(-1))
        let bytes = try await Task.detached { try encoder() }.value
        #expect(!spy.ranOnMain.isEmpty)
        #expect(!spy.ranOnMain.contains(true))
        #expect(bytes == expected, "the copy is taken when the encoder is made")
    }
}
