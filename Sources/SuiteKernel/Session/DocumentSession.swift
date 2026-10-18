// DocumentSession.swift (EK-3 stub, EK-24 body): the one document session. Dirty is read
// from tokens (history step ids), never a flag. Stubs return fakes and never trap.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// What the save indicator shows: never saved, saved, a save being written,
/// the last save failed (in words), or a file that needs Save As.
public enum SaveStatus: Hashable, Sendable { case unsaved, saved, saving, failed(String), readOnly }

/// One open document's save state.
public struct DocumentSession: Hashable, Sendable {
    /// The history step id at the last save, and the one on screen now.
    public var savedToken: Int, currentToken: Int
    /// When the last edit and the last autosave happened; nil before any.
    public var lastEdit: Date?, lastAutosave: Date?
    /// What the save indicator shows.
    public var status: SaveStatus

    /// A session at `token` (saved and current), with no edit or autosave yet.
    public init(token: Int = 0, status: SaveStatus = .unsaved) {
        savedToken = token; currentToken = token; lastEdit = nil; lastAutosave = nil; self.status = status
    }

    /// True when the current token is not the saved one. Stub: false until EK-24.
    public var isDirty: Bool { false }

    /// True when dirty and `delay` has passed since the last edit with no
    /// autosave after it. Stub: false until EK-24.
    public func autosaveDue(now: Date, delay: TimeInterval) -> Bool { false }

    /// Records a save at `token`. Stub: ignored until EK-24.
    public mutating func didSave(token: Int) {}

    /// Records an edit that moved the history to `token` at `at`. Stub: ignored until EK-24.
    public mutating func didEdit(token: Int, at: Date) {}
}

/// An autosaved copy found at launch, offered back to the person.
public struct RecoveryOffer: Hashable, Sendable {
    /// The document's name and when the copy was autosaved.
    public var name: String, savedAt: Date

    /// An offer for `name` autosaved at `savedAt`.
    public init(name: String, savedAt: Date) { self.name = name; self.savedAt = savedAt }

    /// The question the recovery alert asks. Stub: the name until EK-24.
    public var prompt: String { name }
}
