// DesignHistory.swift: Design's undo and redo. Every document edit records one
// step: its name ("Add Rectangle") and the snapshot of the document just before
// it. Undo swaps the current snapshot for the step's and keeps the current one
// for Redo, and the reverse. A snapshot holds the pages, both selections and
// the id counters. A restore sets each counter to the larger of the current and
// the snapshot's, so an undone add never gives its id away again (a redo of New
// File therefore doesn't restart the ids). The restored selection's enclosing
// rows expand; expansion is otherwise view state and is not undone. A step that
// replaces the whole document (New File) is marked so, and the window asks
// undoSwapsDocument / redoSwapsDocument instead of matching its name.
//
// A run of edits with the same coalescing key (one node's frame, nudges) is one
// step; an undo or redo ends the run. A new edit clears Redo. The history keeps
// the last 100 steps. An edit that changed nothing records nothing.
// ponytail: one whole-document snapshot per step (copy-on-write, so edits share
// the nodes they didn't touch); switch to per-node diffs if files get large.
// Linux-safe.

/// The document as an undo step restores it.
struct DesignSnapshot: Sendable, Equatable {
    var pages: [DesignPage]
    var selectedPageID: String?
    var selectedNodeID: String?
    var expandedNodeIDs: Set<String>
    var pageCount: Int
    var nodeCount: Int
}

struct DesignHistory: Sendable, Equatable {
    struct Step: Sendable, Equatable {
        var name: String
        var snapshot: DesignSnapshot
        var coalescing: String?
        /// Undoing or redoing it replaces the whole document (New File over an open file).
        var swapsDocument = false
    }

    static let limit = 100
    var undo: [Step] = []
    var redo: [Step] = []
}

extension DesignWorkspace {
    public var canUndo: Bool { !history.undo.isEmpty }
    public var canRedo: Bool { !history.redo.isEmpty }
    /// "Undo Add Rectangle", or plain "Undo" with nothing to undo.
    public var undoActionName: String { history.undo.last.map { "Undo \($0.name)" } ?? "Undo" }
    /// "Redo Add Rectangle", or plain "Redo" with nothing to redo.
    public var redoActionName: String { history.redo.last.map { "Redo \($0.name)" } ?? "Redo" }
    /// The next Undo replaces the whole document, so the window forgets its file's location.
    public var undoSwapsDocument: Bool { history.undo.last?.swapsDocument ?? false }
    /// The next Redo replaces the whole document, so the window forgets its file's location.
    public var redoSwapsDocument: Bool { history.redo.last?.swapsDocument ?? false }

    /// Puts back the last edit. Ignored with nothing to undo, mid-drag and while editing text.
    public mutating func undo() {
        guard gesture == nil, editingTextID == nil, let step = history.undo.popLast() else { return }
        history.redo.append(
            DesignHistory.Step(name: step.name, snapshot: snapshot, swapsDocument: step.swapsDocument))
        restore(step.snapshot)
        endRun()
    }

    /// Makes the last undone edit again. Ignored with nothing to redo, mid-drag and while editing text.
    public mutating func redo() {
        guard gesture == nil, editingTextID == nil, let step = history.redo.popLast() else { return }
        history.undo.append(
            DesignHistory.Step(name: step.name, snapshot: snapshot, swapsDocument: step.swapsDocument))
        restore(step.snapshot)
        endRun()
    }

    var snapshot: DesignSnapshot {
        DesignSnapshot(
            pages: pages, selectedPageID: selectedPageID, selectedNodeID: selectedNodeID,
            expandedNodeIDs: expandedNodeIDs, pageCount: pageCount, nodeCount: nodeCount)
    }

    /// Records the edit just made as one step named `name`, undone by putting back `before`. Does
    /// nothing when the edit left the pages and selection as they were. With a `coalescing` key
    /// equal to the last step's, that step already puts back the state before this run.
    /// `swapsDocument` marks a step that replaces the whole document.
    mutating func record(
        _ name: String, before: DesignSnapshot, coalescing: String? = nil, swapsDocument: Bool = false
    ) {
        guard pages != before.pages || selectedPageID != before.selectedPageID || selectedNodeID != before.selectedNodeID
        else { return }
        history.redo.removeAll()
        if let coalescing, history.undo.last?.coalescing == coalescing { return }
        history.undo.append(DesignHistory.Step(
            name: name, snapshot: before, coalescing: coalescing, swapsDocument: swapsDocument))
        if history.undo.count > DesignHistory.limit {
            history.undo.removeFirst(history.undo.count - DesignHistory.limit)
        }
    }

    /// Undo and redo: the document goes back to `snapshot`, the counters never go back.
    private mutating func restore(_ snapshot: DesignSnapshot) {
        pages = snapshot.pages
        (selectedPageID, selectedNodeID) = (snapshot.selectedPageID, snapshot.selectedNodeID)
        (pageCount, nodeCount) = (Swift.max(pageCount, snapshot.pageCount), Swift.max(nodeCount, snapshot.nodeCount))
        if let page = selectedPage, let id = selectedNodeID { expandAncestors(of: id, in: page.nodes) }
    }

    /// A gesture or discarded text edit: the document goes back to `snapshot` exactly, counters
    /// and expansion included, because nothing it made was ever recorded.
    mutating func rewind(to snapshot: DesignSnapshot) {
        pages = snapshot.pages
        (selectedPageID, selectedNodeID, expandedNodeIDs) = (snapshot.selectedPageID, snapshot.selectedNodeID, snapshot.expandedNodeIDs)
        (pageCount, nodeCount) = (snapshot.pageCount, snapshot.nodeCount)
    }

    /// Stops the last step from absorbing the next edit.
    private mutating func endRun() {
        guard let last = history.undo.indices.last else { return }
        history.undo[last].coalescing = nil
    }
}
