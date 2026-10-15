// PhotoAutosaveTests.swift: PhotoAutosave (photo-documents D-9, PJ-3), Flare's
// MP-5 and MP-6 cases for Photo, each in its own temp folder behind the live
// recovery store (`PhotoServices.recovering(in:)`), times passed in. macOS only.
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

/// Blocks the calling thread until `semaphore` is signalled (sync, so it can run in a detached task).
private func block(on semaphore: DispatchSemaphore) {
    semaphore.wait()
}

@MainActor
@Suite struct PhotoAutosaveTests {
    private let folder = FileManager.default.temporaryDirectory
        .appending(path: "PhotoAutosaveTests-\(UUID().uuidString)").appending(path: "Recovery")

    private var store: any RecoveryStoring { PhotoServices.live.recovering(in: folder).recovery }

    /// The names in the recovery folder; none when it is missing.
    private func names() -> [String] {
        (try? FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false))) ?? []
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
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("not a zip".utf8).write(to: folder.appending(path: "crashed.ora"))
        #expect(await makeAutosave().launch(model: PhotoWorkspace(services: .live)) == nil)
        #expect(names().isEmpty)
    }

    @Test func restoreAndDiscardRemoveTheFile() async throws {
        let (writer, dirty) = try await written()
        let relaunch = makeAutosave(window: "w2")
        let launched = await relaunch.launch(model: PhotoWorkspace(services: .live))
        let offer = try #require(launched)
        var model = PhotoWorkspace(services: PhotoServices.live.recovering(in: folder))
        try relaunch.restore(offer, into: &model, codec: ImageIOCodec())
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

    @Test func offerTextForBeach() throws {
        let entry = RecoveryEntry(documentName: "beach.png", savedAt: 0, package: PhotoPackage(files: [:]))
        #expect(RecoveryOffer(entry: entry, time: { _ in "9:41 AM" }).message == "Restore beach.png from 9:41 AM?")
        #expect(PhotoAutosave.time(9) == Date(timeIntervalSince1970: 9).formatted(date: .omitted, time: .shortened))
    }
}
#endif
