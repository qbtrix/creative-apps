// CatalogHistory.swift: undo and redo for the catalog. Each step is named
// ("Set Rating", "Exposure") and holds the photos it changed as they were
// before and after, so undo puts `before` back by id and redo puts `after`
// back. Steps that share an open coalesce key (one slider drag) stay one step.
// The catalog's recordEdit, undo and redo extend LibraryCatalog at the end of
// this file; undo and redo never move the loupe (#426). Linux-safe.

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

extension LibraryCatalog {
    /// "Undo Set Rating"; nil when there is nothing to undo.
    public var undoTitle: String? { history.top.map { "Undo " + $0.name } }

    /// "Redo Set Rating"; nil when there is nothing to redo.
    public var redoTitle: String? { history.redoTop.map { "Redo " + $0.name } }

    /// Applies `edit` to the photos with `ids` and records it as the step
    /// `name`. An edit that changes nothing records nothing. Edits sharing an
    /// open `coalesceKey` (one drag) stay one step until `endCoalescing()`.
    mutating func recordEdit(
        _ name: String, coalesceKey: String? = nil, ids: Set<String>, _ edit: (inout PhotoItem) -> Void
    ) {
        let indices = items.indices.filter { ids.contains(items[$0].id) }
        let before = indices.map { items[$0] }
        for index in indices {
            edit(&items[index])
        }
        let after = indices.map { items[$0] }
        guard before != after else { return }
        saveRevision += 1
        history.push(CatalogHistory.Step(name: name, before: before, after: after, coalesceKey: coalesceKey))
        refreshAfterHistoryChange()
    }

    /// Ends the current gesture: the next recorded edit is a new step.
    public mutating func endCoalescing() {
        history.endCoalescing()
    }

    /// Puts the top step's photos back as they were; the loupe stays put.
    public mutating func undo() {
        guard let step = history.popUndo() else { return }
        restore(step.before)
    }

    /// Reapplies the last undone step; the loupe stays put.
    public mutating func redo() {
        guard let step = history.popRedo() else { return }
        restore(step.after)
    }

    /// Replaces each photo by id with its copy in `photos`, then refreshes.
    private mutating func restore(_ photos: [PhotoItem]) {
        let byID = Dictionary(photos.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
        for index in items.indices {
            if let photo = byID[items[index].id] { items[index] = photo }
        }
        saveRevision += 1
        refreshAfterHistoryChange()
    }

    /// Keeps the counts, the order and the selection true after an edit,
    /// undo or redo. It never touches `mode` or `focusedItemID`.
    private mutating func refreshAfterHistoryChange() {
        recount()
        if editCanReorder { rebuildOrder() }
        select(selection)
    }
}
