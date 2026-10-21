// PhotoAutosaveTests.swift: PhotoAutosave (photo-documents D-9, PJ-3), Flare's
// MP-5 and MP-6 cases for Photo and a restore that decodes off the main actor
// (QB-L12), each in its own temp folder behind the live recovery store
// (`PhotoServices.recovering(in:)`), times passed in. macOS only.
#if os(macOS)
import CoreRaster
import Foundation
import Synchronization
import Testing

@testable import PhotoApp
@testable import PhotoModel

/// The live store; `onWrite` runs inside each write, and each `leftBehind` records whether it ran on main.
private final class ProbeStore: RecoveryStoring {
    let inner: any RecoveryStoring
    let onWrite: @Sendable () -> Void
    let readsOnMain = Mutex<[Bool]>([])
    var unavailableHelp: String? { nil }

    init(_ inner: any RecoveryStoring, onWrite: @escaping @Sendable () -> Void = {}) {
        self.inner = inner
        self.onWrite = onWrite
    }

    func write(_ entry: RecoveryEntry, window: String) throws {
        onWrite()
        try inner.write(entry, window: window)
    }

    func leftBehind() throws -> [RecoveryEntry] {
        let main = Thread.isMainThread
        readsOnMain.withLock { $0.append(main) }
        return try inner.leftBehind()
    }

    func discard(window: String) throws { try inner.discard(window: window) }
    func discardAll() throws { try inner.discardAll() }
}

/// ImageIOCodec that records, from inside each call, whether it ran on the main thread.
private final class MainProbeCodec: PhotoImageCodec {
    let onMain = Mutex<[Bool]>([])

    func decode(_ data: Data, longestSide: Int?) throws -> DecodedImage {
        let main = Thread.isMainThread
        onMain.withLock { $0.append(main) }
        return try ImageIOCodec().decode(data, longestSide: longestSide)
    }

    func encode(_ image: DecodedImage, as format: ImageFormat, quality: Double) throws -> Data {
        try ImageIOCodec().encode(image, as: format, quality: quality)
    }
}

/// A store whose every write fails (a full disk, a folder it can't write).
private struct FailingStore: RecoveryStoring {
    struct Refused: Error {}
    var unavailableHelp: String? { nil }
    func write(_ entry: RecoveryEntry, window: String) throws { throw Refused() }
    func leftBehind() throws -> [RecoveryEntry] { [] }
    func discard(window: String) throws {}
    func discardAll() throws {}
}

/// ImageIOCodec that counts its encodes.
private final class CountingCodec: PhotoImageCodec {
    let encodes = Mutex(0)
    func decode(_ data: Data, longestSide: Int?) throws -> DecodedImage {
        try ImageIOCodec().decode(data, longestSide: longestSide)
    }
    func encode(_ image: DecodedImage, as format: ImageFormat, quality: Double) throws -> Data {
        encodes.withLock { $0 += 1 }
        return try ImageIOCodec().encode(image, as: format, quality: quality)
    }
}

/// Blocks the calling thread until `semaphore` is signalled (sync, so it can run in a detached task).
private func block(on semaphore: DispatchSemaphore) {
    semaphore.wait()
}

@MainActor
@Suite struct PhotoAutosaveTests {
    private let folder = FileManager.default.temporaryDirectory.appending(path: "PhotoAutosaveTests-\(UUID().uuidString)")

    private var store: any RecoveryStoring { PhotoServices.live.recovering(in: folder).recovery }

    /// The .ora copies in the store's Recovery folder (a .json sits beside each); none when it is missing.
    private func names() -> [String] {
        let recovery = folder.appending(path: "Recovery").path(percentEncoded: false)
        return ((try? FileManager.default.contentsOfDirectory(atPath: recovery)) ?? []).filter { $0.hasSuffix(".ora") }
    }

    /// beach.png, a 4 x 3 white image, opened clean on the live archive.
    private func opened() throws -> PhotoWorkspace {
        let white = DecodedImage(rgba8: [UInt8](repeating: 255, count: 4 * 3 * 4), width: 4, height: 3)
        var model = PhotoWorkspace(services: PhotoServices.live.recovering(in: folder))
        try model.openImage(try ImageIOCodec().encode(white, as: .png, quality: 1), name: "beach.png", codec: ImageIOCodec())
        return model
    }

    /// beach.png with a second layer: two layers, dirty.
    private func edited() throws -> PhotoWorkspace {
        var model = try opened()
        model.addLayer()
        return model
    }

    private func makeAutosave(_ store: (any RecoveryStoring)? = nil, window: String = "w1") -> PhotoAutosave {
        PhotoAutosave(window: window, delay: PhotoWorkspace.autosaveDelay, store: store ?? self.store)
    }

    /// Window w1's autosave after an edit at 0 and a tick at 5, which writes `w1.ora`.
    private func written() async throws -> (PhotoAutosave, PhotoWorkspace) {
        let (autosave, model) = try (makeAutosave(), edited())
        autosave.noteEdit(at: 0)
        await autosave.tick(model: model, now: 5, codec: ImageIOCodec())
        return (autosave, model)
    }

    @Test func dueModelWritesOncePerEdit() async throws {
        let model = try edited()
        let autosave = makeAutosave()
        autosave.noteEdit(at: 0)
        await autosave.tick(model: model, now: 4, codec: ImageIOCodec())
        #expect(names().isEmpty)
        #expect(!autosave.autosaved)
        await autosave.tick(model: model, now: 5, codec: ImageIOCodec())
        #expect(names() == ["w1.ora"])
        #expect(autosave.autosaved)
        let entry = try #require(try store.leftBehind().first)
        #expect(entry.documentName == "beach.png")
        #expect(entry.savedAt == 5)
        // Once per edit: later ticks don't write the same edit again.
        try store.discard(window: "w1")
        await autosave.tick(model: model, now: 6, codec: ImageIOCodec())
        await autosave.tick(model: model, now: 60, codec: ImageIOCodec())
        #expect(names().isEmpty)
        // A new edit is written once it is due.
        autosave.noteEdit(at: 100)
        #expect(!autosave.autosaved)
        await autosave.tick(model: model, now: 105, codec: ImageIOCodec())
        #expect(names() == ["w1.ora"])
    }

    /// A write that fails is not retried every tick: each retry encodes the whole document again, which
    /// on an 8K image kept Photo at about one core while idle, for as long as the write kept failing.
    /// The next edit tries again.
    @Test func aFailedWriteWaitsForTheNextEdit() async throws {
        let model = try edited()
        let autosave = makeAutosave(FailingStore())
        let codec = CountingCodec()
        autosave.noteEdit(at: 0)
        await autosave.tick(model: model, now: 5, codec: codec)
        let once = codec.encodes.withLock { $0 }
        #expect(once > 0)
        for now in 6...20 { await autosave.tick(model: model, now: Double(now), codec: codec) }
        #expect(codec.encodes.withLock { $0 } == once, "an unchanged document was encoded again")
        #expect(!autosave.autosaved)
        autosave.noteEdit(at: 30)
        await autosave.tick(model: model, now: 35, codec: codec)
        #expect(codec.encodes.withLock { $0 } == 2 * once, "the next edit didn't try again")
    }

    /// The 8K budget fixture's window autosaves while the zoom budget runs; that must land in a temp
    /// folder, or the user's next Photo launch offers to restore a test image.
    @Test func budgetFixtureAutosavesOutsideTheUsersRecoveryFolder() async throws {
        let id = "budget-\(UUID().uuidString)"
        let store = PhotoRenderBudgetTests.services.recovery
        let autosave = makeAutosave(store, window: id)
        autosave.noteEdit(at: 0)
        await autosave.tick(model: try edited(), now: 5, codec: ImageIOCodec())
        defer { try? store.discard(window: id) }
        #expect(autosave.autosaved)
        let users = LiveRecovery.defaultDirectory.appending(path: "Recovery/\(id).ora")
        #expect(!FileManager.default.fileExists(atPath: users.path(percentEncoded: false)))
    }

    @Test func cleanModelWritesNothing() async throws {
        let autosave = makeAutosave()
        autosave.noteEdit(at: 0)
        let clean = try opened()
        await autosave.tick(model: clean, now: 1_000, codec: ImageIOCodec())
        await autosave.tick(model: PhotoWorkspace(services: .live), now: 2_000, codec: ImageIOCodec())
        await autosave.willQuit(model: clean, codec: ImageIOCodec(), now: 3_000)
        #expect(names().isEmpty)
    }

    @Test func didSaveRemovesTheFile() async throws {
        let (autosave, dirty) = try await written()
        var model = dirty
        #expect(names() == ["w1.ora"])
        model.didSave(as: "beach.ora", kind: .document)
        autosave.didSave(model: model)
        #expect(names().isEmpty)
        #expect(autosave.lastEdit == nil)
        #expect(!autosave.autosaved)
        await autosave.tick(model: model, now: 1_000, codec: ImageIOCodec())
        #expect(names().isEmpty)
    }

    @Test func writeLandingAfterASaveIsRemoved() async throws {
        let (started, proceed) = (DispatchSemaphore(value: 0), DispatchSemaphore(value: 0))
        let gated = ProbeStore(store) {
            started.signal()
            proceed.wait()
        }
        let model = try edited()
        let autosave = makeAutosave(gated)
        autosave.noteEdit(at: 0)
        let tick = Task { await autosave.tick(model: model, now: 5, codec: ImageIOCodec()) }
        await Task.detached { block(on: started) }.value
        // The save lands while the write is still running.
        var saved = model
        saved.didSave(as: "beach.ora", kind: .document)
        autosave.didSave(model: saved)
        proceed.signal()
        await tick.value
        #expect(names().isEmpty)
        #expect(!autosave.autosaved)
    }

    @Test func launchReadsOffMainAndOffersTheNewest() async throws {
        let model = try edited()
        let package = try model.documentPackage(archive: PhotoServices.live.archive, codec: ImageIOCodec())
        try store.write(RecoveryEntry(documentName: "old.png", savedAt: 1, package: package), window: "w0")
        _ = try await written()
        let probe = ProbeStore(store)
        let launched = await makeAutosave(probe, window: "w2").launch(model: PhotoWorkspace(services: .live))
        let offer = try #require(launched)
        #expect(probe.readsOnMain.withLock { $0 } == [false])
        #expect(offer.entry.documentName == "beach.png")
        #expect(offer.message == "Restore beach.png from \(PhotoAutosave.time(5))?")
        #expect(names().sorted() == ["w0.ora", "w1.ora"], "the files stay until Restore or Discard")
        // A window that already holds unsaved work gets no offer.
        #expect(await makeAutosave(probe, window: "w3").launch(model: model) == nil)
    }

    @Test func noOrDamagedFileGivesNoOfferAndIsGone() async throws {
        #expect(await makeAutosave().launch(model: PhotoWorkspace(services: .live)) == nil)
        let recovery = folder.appending(path: "Recovery")
        try FileManager.default.createDirectory(at: recovery, withIntermediateDirectories: true)
        try Data("not a zip".utf8).write(to: recovery.appending(path: "crashed.ora"))
        #expect(await makeAutosave().launch(model: PhotoWorkspace(services: .live)) == nil)
        #expect(names().isEmpty)
    }

    @Test func restoreAndDiscardRemoveTheFile() async throws {
        let (writer, dirty) = try await written()
        let relaunch = makeAutosave(window: "w2")
        let launched = await relaunch.launch(model: PhotoWorkspace(services: .live))
        let offer = try #require(launched)
        var model = PhotoWorkspace(services: PhotoServices.live.recovering(in: folder))
        let snapshot = try await PhotoAutosave.decode(offer, archive: model.services.archive, codec: ImageIOCodec())
        try relaunch.restore(offer, decoded: snapshot, into: &model)
        #expect(model.layers.count == 2)
        #expect(model.documentName == "beach.png")
        #expect(model.isDirty)
        #expect(model.fileKind == nil)
        #expect(names().isEmpty)
        // Quit writes once more while dirty; Discard on the next launch removes it.
        await writer.willQuit(model: dirty, codec: ImageIOCodec(), now: 9)
        #expect(try store.leftBehind().map(\.savedAt) == [9])
        relaunch.discardLeftBehind()
        #expect(names().isEmpty)
        // A clean close: the window's own file goes, and nothing is due.
        await writer.willQuit(model: dirty, codec: ImageIOCodec(), now: 10)
        writer.discard()
        #expect(names().isEmpty)
        #expect(writer.lastEdit == nil)
    }

    @Test func restoreDecodesOffMain() async throws {
        _ = try await written()
        let relaunch = makeAutosave(window: "w2")
        let launched = await relaunch.launch(model: PhotoWorkspace(services: .live))
        let offer = try #require(launched)
        let codec = MainProbeCodec()
        let snapshot = try await PhotoAutosave.decode(offer, archive: PhotoServices.live.archive, codec: codec)
        let calls = codec.onMain.withLock { $0 }
        #expect(!calls.isEmpty)
        #expect(!calls.contains(true))
        var model = PhotoWorkspace(services: PhotoServices.live.recovering(in: folder))
        try relaunch.restore(offer, decoded: snapshot, into: &model)
        #expect(model.layers.count == 2)
        #expect(model.isDirty)
        #expect(names().isEmpty)
    }

    @Test func offerTextForBeach() throws {
        let entry = RecoveryEntry(documentName: "beach.png", savedAt: 0, package: PhotoPackage(files: [:]))
        #expect(RecoveryOffer(entry: entry, time: { _ in "9:41 AM" }).message == "Restore beach.png from 9:41 AM?")
        #expect(PhotoAutosave.time(9) == Date(timeIntervalSince1970: 9).formatted(date: .omitted, time: .shortened))
    }
}
#endif
