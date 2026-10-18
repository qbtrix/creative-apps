// DocumentSession.swift (EK-3 stub, EK-24 body): the one document session. Dirty is read
// from tokens (history step ids), never a flag, so undoing back to the saved step reads
// clean. Autosave is due a delay after the last edit that no autosave has covered.
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

    /// True when the current token is not the saved one.
    public var isDirty: Bool { currentToken != savedToken }

    /// True when dirty and `delay` has passed since the last edit with no
    /// autosave at or after it. False for a delay that is negative, NaN or infinite.
    public func autosaveDue(now: Date, delay: TimeInterval) -> Bool {
        guard delay.isFinite, delay >= 0, isDirty, let edit = lastEdit else { return false }
        if let autosave = lastAutosave, autosave >= edit { return false }
        return now.timeIntervalSince(edit) >= delay
    }

    /// Records a save at `token`: that step is the saved one and the status reads saved.
    public mutating func didSave(token: Int) {
        savedToken = token
        status = .saved
    }

    /// Records an edit that moved the history to `token` at `at`; an undo or
    /// redo counts, so moving back to the saved token reads clean.
    public mutating func didEdit(token: Int, at: Date) {
        currentToken = token
        lastEdit = at
    }
}

/// An autosaved copy found at launch, offered back to the person.
public struct RecoveryOffer: Hashable, Sendable {
    /// The document's name and when the copy was autosaved.
    public var name: String, savedAt: Date

    /// An offer for `name` autosaved at `savedAt`.
    public init(name: String, savedAt: Date) { self.name = name; self.savedAt = savedAt }

    /// The question the recovery alert asks, naming the document.
    public var prompt: String { "Restore the autosaved changes to \u{201C}\(name)\u{201D}?" }
}
