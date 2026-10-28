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
// step; an undo or redo ends the run, and so does endEditRun, which the
// inspector sends when a scrub drag or field entry ends (#536). A new edit clears Redo. The history keeps
// the last 100 steps. An edit that changed nothing records nothing; New File
// over a file with a location changes that location, so it always records (#492).
//
// The steps, their runs, the cap and the saved marker are the editor kernel's
// (SuiteKernel History, #2938): Design keeps no step ids of its own. Saved state
// (#270, files-history FH-2): didSave records the save on documentSession, the
// kernel DocumentSession on those step ids (DesignSession+Kernel.swift), and ends
// the edit run; a New File swap marks its own step, as an untouched new file is
// clean. isDirty, the save state's word and the close prompt read it
// (DocumentSession.stateText, UnsavedPrompt), shared with the other apps.
// undoTarget routes Edit > Undo to a focused text field's own undo.
// ponytail: one whole-document snapshot per step (copy-on-write, so edits share
// the nodes they didn't touch); switch to per-node diffs if files get large.
// Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteKernel

/// The document as an undo step restores it.
struct DesignSnapshot: Sendable, Equatable {
    var pages: [DesignPage]
    var selectedPageID: String?
    var selectedNodeIDs: [String]
    var expandedNodeIDs: Set<String>
    var pageCount: Int
    var nodeCount: Int
    /// Every page and node id in `pages` (DesignHeldIDs).
    var heldIDs: Set<String>
}

struct DesignHistory: Sendable, Equatable {
    /// What one kernel step puts back: the document, and for a swap its file location.
    struct Revert: Sendable, Equatable {
        var snapshot: DesignSnapshot
        /// Undoing or redoing it replaces the whole document (New File over an open file).
        var swapsDocument = false
        /// The file the snapshot's document was at; a swap step restores it.
        var documentURL: URL?
    }

    static let limit = 100
    /// The kernel history: names, runs, the cap, step ids and the saved marker.
    var kernel = History<Revert>(limit: DesignHistory.limit)
    /// The steps Undo reverts, the next one last.
    var undo: [History<Revert>.Step] { kernel.undoSteps }
    /// The steps Redo reapplies, the next one last.
    var redo: [History<Revert>.Step] { kernel.redoSteps }
}

/// Where Edit > Undo and Redo go.
public enum DesignUndoTarget: Sendable, Equatable {
    /// The focused text field's own undo (its typing).
    case field
    /// The document's history (`undo()`, `redo()`).
    case document
}

extension DesignWorkspace {
    /// Undo would run: there is a step, no drag is open and no text is being edited (#442).
    public var canUndo: Bool { historyIsLive && history.kernel.canUndo }
    /// Redo would run: there is a step, no drag is open and no text is being edited (#442).
    public var canRedo: Bool { historyIsLive && history.kernel.canRedo }
    /// "Undo Add Rectangle", or plain "Undo" with nothing to undo.
    public var undoActionName: String { history.kernel.undoName.map { "Undo \($0)" } ?? "Undo" }
    /// "Redo Add Rectangle", or plain "Redo" with nothing to redo.
    public var redoActionName: String { history.kernel.redoName.map { "Redo \($0)" } ?? "Redo" }
    /// The next Undo replaces the whole document, and with it `documentURL`.
    /// False mid-drag and while editing text, where Undo is ignored.
    public var undoSwapsDocument: Bool { historyIsLive && history.undo.last?.payload.swapsDocument == true }
    /// The next Redo replaces the whole document, and with it `documentURL`.
    /// False mid-drag and while editing text, where Redo is ignored.
    public var redoSwapsDocument: Bool { historyIsLive && history.redo.last?.payload.swapsDocument == true }

    /// Undo and Redo run: no drag is open and no text is being edited.
    private var historyIsLive: Bool { gesture == nil && editingTextID == nil }

    /// Puts back the last edit. Ignored with nothing to undo, mid-drag and while editing text.
    public mutating func undo() {
        guard historyIsLive else { return }
        var steps = history.kernel
        var applied: DesignHistory.Revert?
        guard steps.undo({ step in applied = step; return reverse(of: step) }), let applied else { return }
        history.kernel = steps
        restore(applied)
    }

    /// Makes the last undone edit again. Ignored with nothing to redo, mid-drag and while editing text.
    public mutating func redo() {
        guard historyIsLive else { return }
        var steps = history.kernel
        var applied: DesignHistory.Revert?
        guard steps.redo({ step in applied = step; return reverse(of: step) }), let applied else { return }
        history.kernel = steps
        restore(applied)
    }

    /// The step that takes the document from `step`'s state back to the one on screen now.
    private func reverse(of step: DesignHistory.Revert) -> DesignHistory.Revert {
        DesignHistory.Revert(snapshot: snapshot, swapsDocument: step.swapsDocument, documentURL: documentURL)
    }

    var snapshot: DesignSnapshot {
        DesignSnapshot(
            pages: pages, selectedPageID: selectedPageID, selectedNodeIDs: selectedNodeIDs,
            expandedNodeIDs: expandedNodeIDs, pageCount: pageCount, nodeCount: nodeCount, heldIDs: held.ids)
    }

    /// Records the edit just made as one step named `name`, undone by putting back `before`. Does
    /// nothing when the edit left the pages and selection as they were. With a `coalescing` key
    /// equal to the last step's, that step already puts back the state before this run.
    /// `swapsDocument` marks a step that replaces the whole document; it records even over equal
    /// pages while the document has a location, since the swap clears it (#492).
    mutating func record(
        _ name: String, before: DesignSnapshot, coalescing: String? = nil, swapsDocument: Bool = false
    ) {
        guard pages != before.pages || selectedPageID != before.selectedPageID || selectedNodeIDs != before.selectedNodeIDs
            || (swapsDocument && documentURL != nil)
        else { return }
        history.kernel.record(
            name, DesignHistory.Revert(snapshot: before, swapsDocument: swapsDocument, documentURL: documentURL),
            key: coalescing)
        if swapsDocument { history.kernel.markSaved() }
    }

    /// True when the document differs from the last save or open (undoing back to it clears it).
    public var isDirty: Bool { isOpen && documentSession.isDirty }

    /// "Saved" after a save, "Edited" with unsaved changes, nil with no file open.
    public var saveStateText: String? {
        guard isOpen else { return nil }
        return documentSession.stateText
    }

    /// The close prompt's message, or nil when the window may close at once.
    public var closePrompt: String? {
        guard isDirty else { return nil }
        let name = documentURL?.lastPathComponent ?? "Untitled"
        return UnsavedPrompt.message(for: name)
    }

    /// Where Edit > Undo and Redo go: the focused text field's own undo, or the document's.
    public func undoTarget(textFieldFocused: Bool) -> DesignUndoTarget {
        textFieldFocused ? .field : .document
    }

    /// Undo and redo: the document goes back to the step's snapshot, the counters never go back.
    /// A swap step also puts back the file location that document had.
    private mutating func restore(_ step: DesignHistory.Revert) {
        let snapshot = step.snapshot
        if step.swapsDocument { documentURL = step.documentURL }
        pages = snapshot.pages
        held.replace(with: snapshot.heldIDs)
        (selectedPageID, selectedNodeIDs) = (snapshot.selectedPageID, snapshot.selectedNodeIDs)
        (pageCount, nodeCount) = (Swift.max(pageCount, snapshot.pageCount), Swift.max(nodeCount, snapshot.nodeCount))
        if let page = selectedPage { expandAncestors(of: selectedNodeIDs, in: page.nodes) }
    }

    /// A gesture or discarded text edit: the document goes back to `snapshot` exactly, counters
    /// and expansion included, because nothing it made was ever recorded.
    mutating func rewind(to snapshot: DesignSnapshot) {
        pages = snapshot.pages
        held.replace(with: snapshot.heldIDs)
        (selectedPageID, selectedNodeIDs, expandedNodeIDs) = (snapshot.selectedPageID, snapshot.selectedNodeIDs, snapshot.expandedNodeIDs)
        (pageCount, nodeCount) = (snapshot.pageCount, snapshot.nodeCount)
    }

    /// Ends the edit run in progress (one scrub drag, one committed field entry), so the next
    /// coalescing edit, even to the same field of the same node, is its own undo step (#536).
    public mutating func endEditRun() { endRun() }

    /// Stops the last step from absorbing the next edit.
    private mutating func endRun() {
        history.kernel.endRun()
    }
}
