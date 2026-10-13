// DesignHistory.swift: Design's undo and redo. Every document edit records one
// step: its name ("Add Rectangle") and the snapshot of the document just before
// it. Undo swaps the current snapshot for the step's and keeps the current one
// for Redo, and the reverse. A snapshot holds the pages, both selections, the
// id counters and the held-id index (DesignHeldIDs). A restore sets each
// counter to the larger of the current and the snapshot's, so an undone add
// never gives its id away again (a redo of New File therefore doesn't restart
// the ids). The restored selection's enclosing
// rows expand; expansion is otherwise view state and is not undone. A step that
// replaces the whole document (New File) is marked so, and the window asks
// undoSwapsDocument / redoSwapsDocument instead of matching its name. Such a
// step also carries the documentURL its snapshot belongs to, so Undo New File
// puts the old file's location back with its document and Redo puts the new
// document's back (nil until it is saved), and Save writes the right file (#436).
//
// A run of edits with the same coalescing key (one node's frame, nudges) is one
// step; an undo or redo ends the run. A new edit clears Redo. The history keeps
// the last 100 steps. An edit that changed nothing records nothing.
// ponytail: one whole-document snapshot per step (copy-on-write, so edits share
// the nodes they didn't touch); switch to per-node diffs if files get large.
// Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// The document as an undo step restores it.
struct DesignSnapshot: Sendable, Equatable {
    var pages: [DesignPage]
    var selectedPageID: String?
    var selectedNodeID: String?
    var expandedNodeIDs: Set<String>
    var pageCount: Int
    var nodeCount: Int
    /// Every page and node id in `pages` (DesignHeldIDs).
    var heldIDs: Set<String>
}

struct DesignHistory: Sendable, Equatable {
    struct Step: Sendable, Equatable {
        var name: String
        var snapshot: DesignSnapshot
        var coalescing: String?
        /// Undoing or redoing it replaces the whole document (New File over an open file).
        var swapsDocument = false
        /// The file the snapshot's document was at; a swap step restores it.
        var documentURL: URL?
    }

    static let limit = 100
    var undo: [Step] = []
    var redo: [Step] = []
}

extension DesignWorkspace {
    /// Undo would run: there is a step, no drag is open and no text is being edited (#442).
    public var canUndo: Bool { historyIsLive && !history.undo.isEmpty }
    /// Redo would run: there is a step, no drag is open and no text is being edited (#442).
    public var canRedo: Bool { historyIsLive && !history.redo.isEmpty }
    /// "Undo Add Rectangle", or plain "Undo" with nothing to undo.
    public var undoActionName: String { history.undo.last.map { "Undo \($0.name)" } ?? "Undo" }
    /// "Redo Add Rectangle", or plain "Redo" with nothing to redo.
    public var redoActionName: String { history.redo.last.map { "Redo \($0.name)" } ?? "Redo" }
    /// The next Undo replaces the whole document, and with it `documentURL`.
    /// False mid-drag and while editing text, where Undo is ignored.
    public var undoSwapsDocument: Bool { historyIsLive && history.undo.last?.swapsDocument == true }
    /// The next Redo replaces the whole document, and with it `documentURL`.
    /// False mid-drag and while editing text, where Redo is ignored.
    public var redoSwapsDocument: Bool { historyIsLive && history.redo.last?.swapsDocument == true }

    /// Undo and Redo run: no drag is open and no text is being edited.
    private var historyIsLive: Bool { gesture == nil && editingTextID == nil }

    /// Puts back the last edit. Ignored with nothing to undo, mid-drag and while editing text.
    public mutating func undo() {
        guard historyIsLive, let step = history.undo.popLast() else { return }
        history.redo.append(DesignHistory.Step(
            name: step.name, snapshot: snapshot, swapsDocument: step.swapsDocument, documentURL: documentURL))
        restore(step)
        endRun()
    }

    /// Makes the last undone edit again. Ignored with nothing to redo, mid-drag and while editing text.
    public mutating func redo() {
        guard historyIsLive, let step = history.redo.popLast() else { return }
        history.undo.append(DesignHistory.Step(
            name: step.name, snapshot: snapshot, swapsDocument: step.swapsDocument, documentURL: documentURL))
        restore(step)
        endRun()
    }

    var snapshot: DesignSnapshot {
        DesignSnapshot(
            pages: pages, selectedPageID: selectedPageID, selectedNodeID: selectedNodeID,
            expandedNodeIDs: expandedNodeIDs, pageCount: pageCount, nodeCount: nodeCount, heldIDs: held.ids)
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
            name: name, snapshot: before, coalescing: coalescing, swapsDocument: swapsDocument,
            documentURL: documentURL))
        if history.undo.count > DesignHistory.limit {
            history.undo.removeFirst(history.undo.count - DesignHistory.limit)
        }
    }

    /// Undo and redo: the document goes back to the step's snapshot, the counters never go back.
    /// A swap step also puts back the file location that document had.
    private mutating func restore(_ step: DesignHistory.Step) {
        let snapshot = step.snapshot
        if step.swapsDocument { documentURL = step.documentURL }
        pages = snapshot.pages
        held.replace(with: snapshot.heldIDs)
        (selectedPageID, selectedNodeID) = (snapshot.selectedPageID, snapshot.selectedNodeID)
        (pageCount, nodeCount) = (Swift.max(pageCount, snapshot.pageCount), Swift.max(nodeCount, snapshot.nodeCount))
        if let page = selectedPage, let id = selectedNodeID { expandAncestors(of: id, in: page.nodes) }
    }

    /// A gesture or discarded text edit: the document goes back to `snapshot` exactly, counters
    /// and expansion included, because nothing it made was ever recorded.
    mutating func rewind(to snapshot: DesignSnapshot) {
        pages = snapshot.pages
        held.replace(with: snapshot.heldIDs)
        (selectedPageID, selectedNodeID, expandedNodeIDs) = (snapshot.selectedPageID, snapshot.selectedNodeID, snapshot.expandedNodeIDs)
        (pageCount, nodeCount) = (snapshot.pageCount, snapshot.nodeCount)
    }

    /// Stops the last step from absorbing the next edit.
    private mutating func endRun() {
        guard let last = history.undo.indices.last else { return }
        history.undo[last].coalescing = nil
    }
}
