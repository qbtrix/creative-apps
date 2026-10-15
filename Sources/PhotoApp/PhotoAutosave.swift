// PhotoAutosave.swift: a Photo window's autosave and its restore offer
// (photo-documents D-9, PJ-3), in FlareAutosave's shape. The file I/O is the
// Model's `RecoveryStoring` (one `<window>.ora` per window); this holds only
// the timing and the off-main calls. When `model.autosaveDue` says so, `tick`
// builds `recoveryEntry` and writes it in one detached task, once per edit
// (the main actor only copies the workspace value). A write that lands after
// a save or a discard is removed again. `launch` reads `leftBehind()` off the
// main actor (a damaged file is already dropped) and offers the newest;
// Restore and Discard remove what the crash left. Times come in as arguments.
import Foundation
import Observation
import PhotoModel

@MainActor @Observable
final class PhotoAutosave {
    /// This window's name in the recovery folder, and the seconds after an edit before it autosaves.
    let window: String, delay: Double
    let store: any RecoveryStoring
    /// The latest edit's bytes are on disk.
    private(set) var autosaved = false
    /// When the last unsaved edit happened, in the caller's clock; nil after a save.
    @ObservationIgnored private(set) var lastEdit: Double?
    /// The edit whose bytes are on disk (or being written), so one edit is written once.
    @ObservationIgnored private var writtenEdit: Double?
    /// Counts saves and discards, so a write that lands after one is removed again.
    @ObservationIgnored private var resets = 0

    init(window: String, delay: Double, store: any RecoveryStoring) {
        self.window = window
        self.delay = delay
        self.store = store
    }

    /// An edit happened at `time`.
    func noteEdit(at time: Double) {
        lastEdit = time
        autosaved = false
    }

    /// Writes the recovery entry off the main actor when autosave is due and
    /// this edit isn't written yet.
    func tick(model: PhotoWorkspace, now: Double, codec: any PhotoImageCodec) async {
        guard let edit = lastEdit,
              model.autosaveDue(lastEdit: edit, lastAutosave: writtenEdit, now: now, delay: delay) else { return }
        writtenEdit = edit
        let reset = resets
        let wrote = await write(model, now: now, codec: codec)
        if resets != reset {
            if wrote { try? store.discard(window: window) }
        } else if wrote {
            autosaved = lastEdit == edit
        } else if writtenEdit == edit {
            writtenEdit = nil
        }
    }

    /// The image was saved: the window's file goes. An edit made while the
    /// save ran is still due; a clean image has nothing due until its next edit.
    func didSave(model: PhotoWorkspace) { reset(keepingEdit: model.isDirty) }

    /// The app is quitting: writes the entry once more while the image is dirty.
    func willQuit(model: PhotoWorkspace, codec: any PhotoImageCodec, now: Double = Date.now.timeIntervalSince1970) async {
        _ = await write(model, now: now, codec: codec)
    }

    /// Reads what a crash left behind off the main actor and offers the
    /// newest; nil when there is none, or while `model` holds unsaved work.
    func launch(model: PhotoWorkspace) async -> RecoveryOffer? {
        guard !model.isDirty else { return nil }
        let store = store
        let entries = await Task.detached(priority: .userInitiated) { (try? store.leftBehind()) ?? [] }.value
        guard let newest = entries.first else { return nil }
        return RecoveryOffer(entry: newest, time: Self.time)
    }

    /// Restore: opens the offer's image, dirty and unsaved, then removes what
    /// the crash left behind (the next edit autosaves it under this window).
    func restore(_ offer: RecoveryOffer, into model: inout PhotoWorkspace, codec: any PhotoImageCodec) throws {
        try model.restore(offer.entry, codec: codec)
        discardLeftBehind()
    }

    /// Discard on the offer: removes what the crash left behind. The offer
    /// comes once per launch, before any window writes, so only that is there.
    func discardLeftBehind() { try? store.discardAll() }

    /// A clean close, or Don't Save: removes this window's file, and nothing is due.
    func discard() { reset(keepingEdit: false) }

    /// The time in the offer, for example "9:41 AM".
    nonisolated static func time(_ seconds: Double) -> String {
        Date(timeIntervalSince1970: seconds).formatted(date: .omitted, time: .shortened)
    }

    /// Removes the window's file; a write still running is removed when it lands.
    private func reset(keepingEdit: Bool) {
        resets += 1
        if !keepingEdit { lastEdit = nil }
        writtenEdit = nil
        autosaved = false
        try? store.discard(window: window)
    }

    /// Builds `model`'s entry and writes it in one detached task, off the main
    /// actor; whether it landed. A clean image has no entry and writes nothing.
    private func write(_ model: PhotoWorkspace, now: Double, codec: any PhotoImageCodec) async -> Bool {
        let (store, window) = (store, window)
        let task = Task.detached(priority: .utility) { () throws -> Bool in
            guard let entry = try model.recoveryEntry(now: now, codec: codec) else { return false }
            try store.write(entry, window: window)
            return true
        }
        return (try? await task.value) ?? false
    }
}
