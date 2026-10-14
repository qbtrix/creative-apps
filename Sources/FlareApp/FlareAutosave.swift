// FlareAutosave.swift: the recovery file and the autosave writer (docs/blueprints/flare/features/mac-platform.md,
// MP-5). `RecoveryFile` writes atomically (`Data.write(to:options: .atomic)`, the parent folder made first), reads
// back the bytes with their modification date, and removes itself, ignoring a missing file. `FlareAutosave` keeps
// the last edit's time; `tick(model:now:)` writes `recoveryData()` off the main actor once per edit when the model
// says autosave is due (`autosaveDue`), `didSave()` removes the file, and `willQuit(model:)` writes once more while
// dirty. Times come in as arguments, never from a clock, so tests drive it. On launch (MP-6), `launch()` reads and
// decodes the recovery file in a detached task, off the main thread, and returns a `RecoveryOffer` ("Restore the
// unsaved animation from <time>?"), or nil when there is no file; a damaged file is removed with no offer.
// `restore(_:into:)` lands the document through `restoreRecovery` and removes the file; `discard()` removes it.
// No SwiftUI: F17c (#393) wires it to the window and shows the offer.
#if os(macOS)
import FlareCore
import FlareModel
import Foundation

/// The file that holds the unsaved document's bytes between autosaves and a relaunch.
struct RecoveryFile: Sendable {
    let url: URL

    /// Writes `data` atomically (a temporary file, then a replace), creating the parent folder first.
    func write(_ data: Data) async throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }

    /// The file's bytes and modification date; nil when it is missing or can't be read.
    func read() async -> (Data, Date)? {
        guard let data = try? Data(contentsOf: url),
            let attributes = try? FileManager.default.attributesOfItem(atPath: url.path(percentEncoded: false)),
            let date = attributes[.modificationDate] as? Date
        else { return nil }
        return (data, date)
    }

    /// Deletes the file; a missing file is fine.
    func remove() {
        try? FileManager.default.removeItem(at: url)
    }
}

/// The launch offer to bring back unsaved work: the recovered document, the recovery file's date, and the text
/// the window shows.
struct RecoveryOffer: Sendable {
    let document: Document
    let date: Date
    let message: String

    /// `time` turns the file's date into the time shown in the message; by default the current locale's date
    /// and time.
    init(document: Document, date: Date, time: (Date) -> String = RecoveryOffer.time) {
        self.document = document
        self.date = date
        message = "Restore the unsaved animation from \(time(date))?"
    }

    /// The file's date and time in the current locale, for example "Jan 17, 2021, 4:03 PM".
    static func time(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }
}

/// Writes the recovery file while the document has unsaved changes. The window calls `noteEdit(at:)` on each
/// edit and `tick(model:now:)` about once a second.
@MainActor
final class FlareAutosave {
    let recovery: RecoveryFile
    /// When the last unsaved edit happened, in the caller's clock; nil after a save.
    private(set) var lastEdit: Double?
    /// The edit whose bytes are on disk (or being written), so one edit is written once.
    private var writtenEdit: Double?
    /// Counts saves, so a write that lands after a save is removed again.
    private var saves = 0

    init(recovery: RecoveryFile) {
        self.recovery = recovery
    }

    /// An edit happened at `time`.
    func noteEdit(at time: Double) {
        lastEdit = time
    }

    /// Writes the recovery bytes off the main actor when autosave is due and this edit isn't written yet.
    func tick(model: FlareWorkspace, now: Double) async {
        guard let edit = lastEdit, edit != writtenEdit, model.autosaveDue(lastEdit: edit, now: now),
            let data = model.recoveryData()
        else { return }
        writtenEdit = edit
        let saved = saves
        let succeeded = await write(data)
        if saves != saved {
            recovery.remove()
        } else if !succeeded, writtenEdit == edit {
            writtenEdit = nil
        }
    }

    /// The document was saved: the recovery file goes, and nothing is due until the next edit.
    func didSave() {
        saves += 1
        lastEdit = nil
        writtenEdit = nil
        recovery.remove()
    }

    /// The app is quitting: writes the recovery bytes once more while the document is dirty.
    func willQuit(model: FlareWorkspace) async {
        guard let data = model.recoveryData() else { return }
        _ = await write(data)
    }

    /// Reads and decodes the recovery file off the main thread: the offer, or nil when there is no file. A file
    /// that doesn't decode is removed and gives no offer. `offMain` runs inside the detached read, for tests.
    func launch(offMain: @escaping @Sendable () -> Void = {}) async -> RecoveryOffer? {
        let recovery = recovery
        let found = await Task.detached(priority: .userInitiated) { () async -> (Document, Date)? in
            offMain()
            guard let (data, date) = await recovery.read() else { return nil }
            switch FlareWorkspace.decodeFile(data) {
            case .success(let document):
                return (document, date)
            case .failure:
                recovery.remove()
                return nil
            }
        }.value
        guard let (document, date) = found else { return nil }
        return RecoveryOffer(document: document, date: date)
    }

    /// Restore: lands the offer's document as unsaved, untitled work and removes the recovery file.
    func restore(_ offer: RecoveryOffer, into model: inout FlareWorkspace) {
        model.restoreRecovery(offer.document)
        recovery.remove()
    }

    /// Discard: removes the recovery file.
    func discard() {
        recovery.remove()
    }

    /// Writes `data` in a detached task, off the main actor; whether it landed.
    private func write(_ data: Data) async -> Bool {
        let recovery = recovery
        let task = Task.detached(priority: .utility) { try await recovery.write(data) }
        do {
            try await task.value
            return true
        } catch {
            return false
        }
    }
}
#endif
