// AutosaveSchedule.swift (autosave-history AH-1 stub, AH-5 body): the autosave timing Photo's `PhotoAutosave` and
// Flare's `FlareAutosave` each wrote, once, on the caller's clock. A write is due `delay` after the newest edit
// no ticket has covered; a save or discard bumps `resets`, so a write that started before it is deleted again.

/// When an open document writes its recovery copy: once per edit, `delay` after it, never twice for one
/// edit, and a write that finishes after a save or a discard is deleted again.
public struct AutosaveSchedule: Hashable, Sendable {
    /// One write the caller runs: the time of the edit whose bytes it writes.
    public struct Ticket: Hashable, Sendable {
        public let edit: Double
        /// The schedule's save and discard count when the ticket was taken.
        let resets: Int
    }
    /// What to do with a finished write's file: keep it, delete it (a save or discard overtook it), or
    /// keep nothing due until the next edit (it failed).
    public enum Finish: Hashable, Sendable { case keep, discard, retryOnNextEdit }

    /// The seconds after an edit before its write is due; nil when the delay is never due.
    private let delay: Double?
    /// The newest edit not covered by a save or discard.
    private var lastEdit: Double?
    /// The edit a ticket was taken for, so one edit is written once, even when that write failed.
    private var writtenEdit: Double?
    /// The edit whose bytes landed on disk.
    private var landedEdit: Double?
    /// Saves and discards so far; a ticket taken before one finishes as `.discard`.
    private var resets = 0

    /// A schedule that writes `delay` seconds after each edit; a non-finite or negative delay is never due.
    public init(delay: Double) { self.delay = delay.isFinite && delay >= 0 ? delay : nil }

    /// The newest edit's bytes are on disk.
    public var isWritten: Bool { lastEdit != nil && landedEdit == lastEdit }

    /// An edit happened at `time`.
    public mutating func noteEdit(at time: Double) { lastEdit = time }

    /// A ticket for the write that is due at `now`; nil unless a write is due.
    public mutating func begin(now: Double, dirty: Bool) -> Ticket? {
        guard dirty, let delay, let edit = lastEdit, edit != writtenEdit, now - edit >= delay else { return nil }
        writtenEdit = edit
        return Ticket(edit: edit, resets: resets)
    }

    /// A ticket for the write the app's quit runs at `now`: due at once while `dirty` and the newest edit's bytes
    /// aren't on disk, whatever the delay; nil for a clean window or one whose copy is current. A dirty window with
    /// no edit noted writes as of `now`.
    public mutating func beginQuit(now: Double, dirty: Bool) -> Ticket? {
        guard dirty, !isWritten else { return nil }
        let edit = lastEdit ?? now
        lastEdit = edit
        writtenEdit = edit
        return Ticket(edit: edit, resets: resets)
    }

    /// The write for `ticket` ended, landing its bytes when `wrote`. A failed write keeps `writtenEdit`, so the
    /// next edit tries again, not the next tick.
    public mutating func finish(_ ticket: Ticket, wrote: Bool) -> Finish {
        guard wrote else { return .retryOnNextEdit }
        if ticket.resets != resets { return .discard }
        landedEdit = ticket.edit
        return .keep
    }

    /// Saved; an edit made during the save stays due when `stillDirty`.
    public mutating func didSave(stillDirty: Bool) {
        reset()
        if !stillDirty { lastEdit = nil }
    }

    /// The document was closed clean or without saving: nothing is due.
    public mutating func didDiscard() {
        reset()
        lastEdit = nil
    }

    /// Forgets every write: the recovery file is deleted, and a write still running is deleted when it ends.
    private mutating func reset() {
        resets += 1
        writtenEdit = nil
        landedEdit = nil
    }
}
