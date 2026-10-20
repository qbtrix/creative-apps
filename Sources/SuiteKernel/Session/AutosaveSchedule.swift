// AutosaveSchedule.swift (autosave-history AH-1 stub, AH-5 body): the autosave timing Photo's `PhotoAutosave` and
// Flare's `FlareAutosave` each wrote, once, on the caller's clock. Until AH-5 the stub is never due.

/// When an open document writes its recovery copy: once per edit, `delay` after it, never twice for one
/// edit, and a write that finishes after a save or a discard is deleted again.
public struct AutosaveSchedule: Hashable, Sendable {
    /// One write the caller runs: the time of the edit whose bytes it writes.
    public struct Ticket: Hashable, Sendable { public let edit: Double }
    /// What to do with a finished write's file: keep it, delete it (a save or discard overtook it), or
    /// keep nothing due until the next edit (it failed).
    public enum Finish: Hashable, Sendable { case keep, discard, retryOnNextEdit }

    /// The seconds after an edit before its write is due.
    private let delay: Double

    /// A schedule that writes `delay` seconds after each edit; a non-finite or negative delay is never due.
    public init(delay: Double) { self.delay = delay }

    /// The newest edit's bytes are on disk. Stub: false; AH-5 fills this in.
    public var isWritten: Bool { false }
    /// An edit happened at `time`. Stub: does nothing; AH-5 fills this in.
    public mutating func noteEdit(at time: Double) {}
    /// A ticket for the write that is due at `now`; nil unless a write is due. Stub: nil; AH-5 fills this in.
    public mutating func begin(now: Double, dirty: Bool) -> Ticket? { nil }
    /// The write for `ticket` ended, landing its bytes when `wrote`. Stub: `.keep`; AH-5 fills this in.
    public mutating func finish(_ ticket: Ticket, wrote: Bool) -> Finish { .keep }
    /// Saved; an edit made during the save stays due when `stillDirty`. Stub: does nothing; AH-5 fills this in.
    public mutating func didSave(stillDirty: Bool) {}
    /// The document was closed clean or without saving: nothing is due. Stub: does nothing; AH-5 fills this in.
    public mutating func didDiscard() {}
}
