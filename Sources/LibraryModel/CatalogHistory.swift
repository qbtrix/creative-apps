// CatalogHistory.swift: undo and redo for the catalog. Each step is named
// ("Set Rating", "Exposure") and holds the photos it changed as they were
// before and after, so undo puts `before` back by id and redo puts `after`
// back. Steps that share an open coalesce key (one slider drag) stay one step.
// The catalog's recordEdit, undo and redo extend LibraryCatalog later in this
// file (SP-14). Linux-safe.

/// The undo and redo stacks of named before-and-after steps.
public struct CatalogHistory: Hashable, Sendable {
    /// One undoable change: the photos it touched, before and after.
    public struct Step: Hashable, Sendable {
        /// The menu name, e.g. "Set Rating" in "Undo Set Rating".
        public let name: String
        public let before: [PhotoItem]
        public internal(set) var after: [PhotoItem]
        /// Pushes with the same key while the history is open join this step.
        public let coalesceKey: String?

        public init(name: String, before: [PhotoItem], after: [PhotoItem], coalesceKey: String? = nil) {
            self.name = name
            self.before = before
            self.after = after
            self.coalesceKey = coalesceKey
        }
    }

    /// Oldest first; the last is the step Undo reverts.
    public internal(set) var undo: [Step]
    /// Oldest undone last; the last is the step Redo reapplies.
    public internal(set) var redo: [Step]
    /// True while the top step can still take a coalesced push.
    public internal(set) var open: Bool

    public init() {
        undo = []
        redo = []
        open = false
    }

    /// The step Undo would revert; nil when there is nothing to undo.
    public var top: Step? { undo.last }

    /// The step Redo would reapply; nil when there is nothing to redo.
    public var redoTop: Step? { redo.last }

    /// Records a step and clears redo. When the step's coalesce key matches
    /// the open top's, the top takes the step's `after` instead.
    public mutating func push(_ step: Step) {
        redo = []
        if open, let key = step.coalesceKey, let last = undo.indices.last, undo[last].coalesceKey == key {
            undo[last].after = step.after
        } else {
            undo.append(step)
        }
        open = true
    }

    /// Ends the current gesture: the next push starts a new step.
    public mutating func endCoalescing() {
        open = false
    }

    /// Moves the top step to redo and returns it; nil when there is none.
    public mutating func popUndo() -> Step? {
        open = false
        guard let step = undo.popLast() else { return nil }
        redo.append(step)
        return step
    }

    /// Moves the last undone step back to undo and returns it; nil when there is none.
    public mutating func popRedo() -> Step? {
        open = false
        guard let step = redo.popLast() else { return nil }
        undo.append(step)
        return step
    }
}
