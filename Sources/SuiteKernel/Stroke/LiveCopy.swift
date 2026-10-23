// LiveCopy.swift: the copy a drag draws on (editor-kernel EK-29 stub,
// EK-28 body). A stroke or a drag begins a working copy of the Model, edits
// it sample by sample while the canvas shows it, and hands it back once with
// `take()`, so the document changes (and records one undo step) only at the end.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// The working copy a drag edits until it ends.
public struct LiveCopy<Model: Sendable>: Sendable {
    /// The copy the canvas shows mid-drag; nil when no drag is under way.
    public private(set) var shown: Model?

    /// No copy yet.
    public init() {}

    /// Starts the copy from `m`; a second `begin` before `take` is ignored.
    public mutating func begin(_ m: Model) {
        if shown == nil { shown = m }
    }

    /// Edits the copy; true when there was one to edit.
    public mutating func edit(_ body: (inout Model) -> Void) -> Bool {
        guard var copy = shown else { return false }
        body(&copy)
        shown = copy
        return true
    }

    /// Hands back the copy and ends the drag; nil when nothing began, so a
    /// second `take` returns nil.
    public mutating func take() -> Model? {
        let copy = shown
        shown = nil
        return copy
    }
}
