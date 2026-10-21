// AutosaveRecovery.swift (autosave-history AH-2 stub, AH-8 body): the `.autosaveRecovery` modifier on every document
// window. `AutosaveDriver` decides over the kernel's `AutosaveSchedule` and the store's `RecoveryFolder`: while dirty
// it ticks each second, copies the document on main and encodes and writes it off main; turning clean deletes the
// copy. At launch the newest copy left behind is offered in a system alert naming the document and its time; Restore
// hands its bytes back and keeps the file until the next save, Discard deletes it.
import SuiteKernel
import SuiteModel
import SwiftUI

/// What the modifier reads from the app's document: its window, name, dirty state, bytes and how to restore them.
/// Sendable: its closures are main-actor isolated, which makes them Sendable (SE-0434).
public struct AutosaveHooks: Sendable {
    /// The window's id; its recovery files are named after it.
    public var window: String
    /// The document's name, nil while it is untitled.
    public var documentName: @MainActor () -> String?
    /// Whether the document has edits no save has written.
    public var isDirty: @MainActor () -> Bool
    /// Copies the document's value on main and returns the encode that runs off it; nil when there is nothing to write.
    public var encoder: @MainActor () -> (@Sendable () throws -> Data)?
    /// Opens a recovered copy's bytes in the window.
    public var restore: @MainActor (Data) async throws -> Void

    public init(
        window: String, documentName: @escaping @MainActor () -> String?, isDirty: @escaping @MainActor () -> Bool,
        encoder: @escaping @MainActor () -> (@Sendable () throws -> Data)?,
        restore: @escaping @MainActor (Data) async throws -> Void
    ) {
        self.window = window
        self.documentName = documentName
        self.isDirty = isDirty
        self.encoder = encoder
        self.restore = restore
    }
}

/// One window's autosave and recovery offer: when to write, what to delete and what to offer. Every file read and
/// write runs in a detached task; main does only the schedule, the copy and the offer.
@MainActor @Observable
final class AutosaveDriver {
    /// The copy left behind that the alert offers; nil when there is none or it was answered.
    private(set) var offer: RecoveryItem?
    /// The schedule that says when a write is due, on `now`'s clock.
    @ObservationIgnored private var schedule: AutosaveSchedule
    /// Where the copies go; nil turns autosave and the offer off.
    private let folder: RecoveryFolder?
    /// Seconds on the caller's clock; the wall clock in the app.
    private let now: @MainActor () -> Double
    /// The window of a restored copy, whose file stays until the next save.
    @ObservationIgnored private var restoredWindow: String?

    init(folder: RecoveryFolder?, delay: Double, now: @escaping @MainActor () -> Double = AutosaveDriver.wallClock) {
        self.folder = folder
        self.now = now
        schedule = AutosaveSchedule(delay: delay)
    }

    /// Seconds since the reference date: what `RecoveryItem.savedAt` holds.
    nonisolated static func wallClock() -> Double { Date.now.timeIntervalSinceReferenceDate }

    /// An edit happened now.
    func noteEdit() { schedule.noteEdit(at: now()) }

    /// Writes `hooks`' document when a write is due: copied on main, encoded and written off it. A write that
    /// finishes after a save or a discard is deleted again; a failed one waits for the next edit.
    func tick(_ hooks: AutosaveHooks) async {
        guard let folder, let ticket = schedule.begin(now: now(), dirty: hooks.isDirty()) else { return }
        guard let encode = hooks.encoder() else {
            _ = schedule.finish(ticket, wrote: false)
            return
        }
        let (window, name, at) = (hooks.window, hooks.documentName(), now())
        let wrote = await Task.detached(priority: .utility) { () -> Bool in
            do {
                try folder.write(try encode(), window: window, name: name, at: at)
                return true
            } catch {
                return false
            }
        }.value
        if schedule.finish(ticket, wrote: wrote) == .discard { await remove([window]) }
    }

    /// The document turned clean (saved, or undone to its saved state): nothing is due and its copy goes, with a
    /// restored copy's file.
    func didTurnClean(_ hooks: AutosaveHooks) async {
        schedule.didSave(stillDirty: false)
        let windows = [hooks.window] + (restoredWindow.map { [$0] } ?? [])
        restoredWindow = nil
        await remove(windows)
    }

    /// Reads the folder off main; the newest copy left behind becomes the offer.
    func launch() async {
        guard let folder else { return }
        let found = await Task.detached(priority: .userInitiated) { () -> RecoveryItem? in
            (try? folder.leftBehind())?.first
        }.value
        if let found { offer = found }
    }

    /// Restore: hands `item`'s bytes to the window and keeps its file until the next save.
    func restore(_ item: RecoveryItem, _ hooks: AutosaveHooks) async {
        offer = nil
        restoredWindow = item.window
        try? await hooks.restore(item.data)
    }

    /// Discard: deletes `item`'s files.
    func discard(_ item: RecoveryItem) async {
        offer = nil
        await remove([item.window])
    }

    /// The alert closed without an answer; the copy stays for the next launch.
    func dismissOffer() { offer = nil }

    /// Deletes `windows`' copies off main; a missing file is fine.
    private func remove(_ windows: [String]) async {
        guard let folder else { return }
        await Task.detached(priority: .utility) {
            for window in windows { try? folder.discard(window: window) }
        }.value
    }

    /// The kernel's offer for `item`: its document's name ("Untitled" when it had none) and when it was autosaved.
    nonisolated static func recoveryOffer(_ item: RecoveryItem) -> RecoveryOffer {
        RecoveryOffer(name: item.name ?? "Untitled", savedAt: Date(timeIntervalSinceReferenceDate: item.savedAt))
    }

    /// The alert's message: when the copy was autosaved, in the current locale ("Autosaved Oct 20, 2026, 4:03 PM.").
    nonisolated static func message(_ item: RecoveryItem) -> String {
        "Autosaved \(recoveryOffer(item).savedAt.formatted(date: .abbreviated, time: .shortened))."
    }
}

/// The modifier: notes edits, ticks while dirty, deletes the copy on a save and shows the launch offer.
private struct AutosaveRecoveryModifier: ViewModifier {
    let hooks: AutosaveHooks
    let edits: Int
    @State private var driver: AutosaveDriver

    init(hooks: AutosaveHooks, folder: RecoveryFolder?, delay: Double, edits: Int) {
        self.hooks = hooks
        self.edits = edits
        _driver = State(initialValue: AutosaveDriver(folder: folder, delay: delay))
    }

    /// What restarts the tick loop: an edit (so it holds the newest hooks), or the document turning dirty or clean.
    private struct TickKey: Hashable { let edits: Int, dirty: Bool }

    func body(content: Content) -> some View {
        let dirty = hooks.isDirty()
        let driver = driver
        let hooks = hooks
        content
            .onChange(of: edits) { driver.noteEdit() }
            .onChange(of: dirty) { _, isDirty in
                if !isDirty { Task { await driver.didTurnClean(hooks) } }
            }
            .task(id: TickKey(edits: edits, dirty: dirty)) {
                guard dirty else { return }
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(1))
                    guard !Task.isCancelled else { return }
                    await driver.tick(hooks)
                }
            }
            .task { await driver.launch() }
            .alert(
                driver.offer.map { AutosaveDriver.recoveryOffer($0).prompt } ?? "",
                isPresented: Binding(get: { driver.offer != nil }, set: { if !$0 { driver.dismissOffer() } }),
                presenting: driver.offer
            ) { item in
                Button("Restore") { Task { await driver.restore(item, hooks) } }
                    .accessibilityIdentifier("suite.recovery.restore")
                Button("Discard", role: .destructive) { Task { await driver.discard(item) } }
                    .accessibilityIdentifier("suite.recovery.discard")
            } message: { item in
                Text(AutosaveDriver.message(item))
            }
    }
}

extension View {
    /// Autosaves the document `hooks` reads to `folder` `delay` seconds after an edit and offers a copy left behind
    /// at launch. `edits` changes on every edit (the history's current step id). `folder` nil turns autosave off
    /// (the journeys' `-ApplePersistenceIgnoreState` launch).
    public func autosaveRecovery(_ hooks: AutosaveHooks, folder: RecoveryFolder?, delay: Double, edits: Int) -> some View {
        modifier(AutosaveRecoveryModifier(hooks: hooks, folder: folder, delay: delay, edits: edits))
    }
}
