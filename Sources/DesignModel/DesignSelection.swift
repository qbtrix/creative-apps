// DesignSelection.swift: several layers selected at once (#413, slice 1), kept in
// SuiteKernel's `Selection<String>` (adopt-kernel-selection AS-design). The
// kernel holds the ordered list; the last one in is the primary selection,
// which `selectedNodeID` and `selectedNodes` read, so single-selection callers
// keep working. A plain click (selectItem) replaces the list, Shift-click
// (toggleSelection) is the kernel's `.toggle` pick, and deselect (Escape, a
// click on empty canvas) clears it. Every change goes through `adopt`, which
// ends the edit run (DesignHistory), so nudging A, then selecting B and nudging
// it, is two undo steps; a pick the kernel refuses changes nothing.
//
// A layer that is locked or hidden, itself or through a group around it, is
// never added (`canAddToSelection`, the kernel's canAdd); one already selected
// can always be taken out. With several layers selected, nudge and delete act
// on all of them through `run` (DesignActions). While a marquee drag is live,
// showsSelectionHandles is false: the canvas draws the marquee and an outline
// on each layer it touches, never the box's handles. Linux-safe.
import SuiteKernel

extension DesignWorkspace {
    /// More than one layer is selected.
    public var hasMultipleSelection: Bool { selectedNodeIDs.count > 1 }

    /// Why single-layer edits (handles, frame, fill, nudge, delete) don't act, or nil with at most one layer selected.
    public var multipleSelectionHelp: String? {
        hasMultipleSelection ? "Editing several layers at once isn't available yet." : nil
    }

    /// Whether the canvas draws the selection's resize handles: never while a marquee drag is
    /// live (it shows the marquee and an outline on each layer it touches until the drag ends),
    /// otherwise when a drag can move the selection (`transformHelp` is nil).
    public var showsSelectionHandles: Bool {
        marquee == nil && transformHelp == nil
    }

    /// The selected layers in the order they were selected; the primary one is last.
    public var selectedNodes: [DesignNode] {
        guard let page = selectedPage else { return [] }
        return selectedNodeIDs.compactMap { page.nodes.node($0) }
    }

    /// The box around every selected layer the canvas shows (none hidden, itself or by a group), or nil.
    public var selectionBounds: DesignRect? { selectionBounds(on: selectedPage) }
    /// The same box as the canvas shows it at the playhead (`shownPage`): what a move snaps.
    var shownSelectionBounds: DesignRect? { selectionBounds(on: shownPage) }

    /// The box around the selected layers' frames on `page`, less the hidden ones.
    func selectionBounds(on page: DesignPage?) -> DesignRect? {
        guard let page else { return nil }
        let frames = selectedNodeIDs.compactMap { page.nodes.node($0) }.filter { !isHiddenInTree($0.id) }.map(\.frame)
        guard let first = frames.first else { return nil }
        let (minX, minY) = (frames.map(\.x).min() ?? first.x, frames.map(\.y).min() ?? first.y)
        let (maxX, maxY) = (frames.map(\.maxX).max() ?? first.maxX, frames.map(\.maxY).max() ?? first.maxY)
        return DesignRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// Whether Shift-click can add node `id`: it is on the selected page and neither it nor a
    /// group around it is locked or hidden.
    public func canAddToSelection(_ id: String) -> Bool {
        selectedPage?.nodes.node(id) != nil && !isLockedInTree(id) && !isHiddenInTree(id)
    }

    /// Shift-click: takes a selected layer out (the one selected before it becomes primary),
    /// or adds one as the new primary and expands the rows around it. A layer that can't be
    /// added (`canAddToSelection`) is refused by the kernel and changes nothing.
    public mutating func toggleSelection(_ id: String) {
        // Committing first: a blank placed text node goes away with its edit.
        commitTextEdit()
        var next = selection
        guard next.pick(id, .toggle, canAdd: canAddToSelection) else { return }
        adopt(next)
        if next.contains(id), let page = selectedPage { expandAncestors(of: id, in: page.nodes) }
    }

    /// Makes `next` the selection and ends the edit run: a run never spans two selections.
    /// The anchor follows the primary, so two workspaces with the same layers in the same
    /// order are equal however they got there.
    mutating func adopt(_ next: Selection<String>) {
        selection = next
        selection.anchor = selection.primary
        endEditRun()
    }
}
