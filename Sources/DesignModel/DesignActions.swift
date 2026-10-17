// DesignActions.swift: the workspace methods the window, the menus and the canvas call for every
// command that runs a use case, and the help each control shows, under the help law in
// EditContracts.swift: a nil help means `run` refuses with nothing but `.unchanged`, and a help
// means it throws. With exactly one layer selected, delete, nudge and align keep today's
// single-layer methods (`deleteSelection`, `nudge`, `alignLayer`) whatever the service holds
// (single-layer Align's "already there" help is that method's `.unchanged`), so nothing that works
// today goes off while `.live` holds NotBuilt. Every other selection runs its use case on the
// selected page through `services`.
//
// Invariants:
// - Each successful run applies one DesignEdit as one named undo step (merged into the run with
//   the same coalescing key); a refusal records nothing and leaves the workspace as it was.
// - With nothing selected every help is "Select a layer first."; while text is being edited it is
//   "Finish editing the text first.", and `run` refuses.
// - `apply` keeps the held-id index exact for the edited page and takes the mint's counter, so a
//   minted id is never handed out again, undo included.
// Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// A command on the selection that a menu item, a top bar item or a key runs.
public enum DesignCommand: Hashable, Sendable {
    case duplicate, group, ungroup, delete
    case nudge(DesignDirection, large: Bool)
    case align(DesignAlignEdge)
    case distribute(DesignDistributeAxis)
    case arrange(DesignArrangeStep)

    /// Delete, nudge and align: with one layer selected they keep today's methods.
    var hasOneLayerMethod: Bool {
        switch self {
        case .delete, .nudge, .align: true
        case .duplicate, .group, .ungroup, .distribute, .arrange: false
        }
    }
}

extension DesignWorkspace {
    /// Why `command` can't run now (the help law); nil when it can.
    public func help(_ command: DesignCommand) -> String? {
        let ids = selectedNodeIDs
        guard let page = selectedPage, !ids.isEmpty else { return DesignRefusal.nothingSelected.help }
        if editingTextID != nil { return Self.finishEditing }
        if ids.count == 1, command.hasOneLayerMethod { return oneLayerHelp(command) }
        return switch command {
        case .duplicate: services.duplicating.duplicateHelp(ids, on: page)
        case .group: services.grouping.groupHelp(ids, on: page)
        case .ungroup: services.grouping.ungroupHelp(ids, on: page)
        case .delete, .nudge: services.transforming.transformHelp(ids, on: page)
        case .align(let edge): services.aligning.alignHelp(edge, ids, on: page)
        case .distribute(let axis): services.aligning.distributeHelp(axis, ids, on: page)
        case .arrange(let step): services.ordering.arrangeHelp(step, ids, on: page)
        }
    }

    /// Runs `command` on the selection as one named undo step, or throws and records nothing.
    public mutating func run(_ command: DesignCommand) throws(DesignRefusal) {
        let ids = selectedNodeIDs
        guard let page = selectedPage, !ids.isEmpty else { throw .nothingSelected }
        guard editingTextID == nil else { throw .unchanged }
        if ids.count == 1, command.hasOneLayerMethod { return try runOneLayer(command) }
        var mint = mint()
        let edit: DesignEdit
        switch command {
        case .duplicate: edit = try services.duplicating.duplicate(ids, offset: DesignPoint(x: 10, y: 10), on: page, mint: &mint)
        case .group: edit = try services.grouping.group(ids, on: page, mint: &mint)
        case .ungroup: edit = try services.grouping.ungroup(ids, on: page)
        case .delete: edit = try services.transforming.delete(ids, on: page)
        case .nudge(let direction, let large): edit = try services.transforming.nudge(ids, direction, large: large, on: page)
        case .align(let edge): edit = try services.aligning.align(edge, ids, on: page)
        case .distribute(let axis): edit = try services.aligning.distribute(axis, ids, on: page)
        case .arrange(let step): edit = try services.ordering.arrange(step, ids, on: page)
        }
        apply(edit, mint: mint)
    }

    /// Why the selection can't be moved or resized by a drag; nil when it can. One layer keeps
    /// today's rule (a lock stops it); several ask the transforming service.
    public var transformHelp: String? {
        let ids = selectedNodeIDs
        guard let page = selectedPage, let id = ids.last else { return DesignRefusal.nothingSelected.help }
        if editingTextID != nil { return Self.finishEditing }
        return ids.count == 1 ? lockHelp(id) : services.transforming.transformHelp(ids, on: page)
    }

    /// What View > Zoom to Selection shows; nil with nothing selected (the command is then off).
    public var zoomToSelectionRect: DesignRect? {
        guard let page = selectedPage, !selectedNodeIDs.isEmpty else { return nil }
        return services.framing.rectToShow(selectedNodeIDs, on: page)
    }

    /// Why View > Zoom to Selection is off; nil exactly when `zoomToSelectionRect` is not.
    public var zoomToSelectionHelp: String? {
        guard let page = selectedPage, !selectedNodeIDs.isEmpty else { return DesignRefusal.nothingSelected.help }
        return services.framing.framingHelp(selectedNodeIDs, on: page)
    }

    /// Edit > Select All: every visible, unlocked layer at the primary selection's level (the page's
    /// top level when nothing is selected), back to front. Not an edit; it ends the edit run.
    public mutating func selectAll() {
        guard let page = selectedPage else { return }
        let parent = selectedNodeID.flatMap { page.nodes.ancestors(of: $0)?.last }
        let level = parent.flatMap { page.nodes.node($0)?.children } ?? page.nodes
        let ids = level.map(\.id).filter { canAddToSelection($0) }
        guard !ids.isEmpty else { return }
        commitTextEdit()
        endEditRun()
        selectedNodeIDs = ids
        for id in ids { expandAncestors(of: id, in: page.nodes) }
    }

    /// A mint over the file's ids, for a use case that adds nodes.
    func mint() -> DesignIDMint {
        DesignIDMint(taken: held.ids, after: nodeCount)
    }

    /// Records `edit` on the selected page as one step and takes the mint's counter.
    mutating func apply(_ edit: DesignEdit, mint: DesignIDMint? = nil) {
        guard let index = pages.firstIndex(where: { $0.id == selectedPageID }) else { return }
        let before = snapshot
        // A style edit keeps every id where it was, so the held ids stand; only a change to the
        // tree's ids rebuilds them, which on `crowd` is most of a scrub step (#2303).
        if !Self.sameIDs(pages[index].nodes, edit.nodes) {
            held.remove(pages[index].nodes)
            for id in Self.ids(in: edit.nodes) { held.insert(id) }
        }
        pages[index].nodes = edit.nodes
        selectedNodeIDs = edit.selection
        for id in edit.selection { expandAncestors(of: id, in: edit.nodes) }
        if let mint { nodeCount = Swift.max(nodeCount, mint.counter) }
        record(edit.name, before: before, coalescing: edit.coalescingKey)
    }

    // MARK: One layer

    /// Today's help for delete, nudge or align on the one selected layer.
    private func oneLayerHelp(_ command: DesignCommand) -> String? {
        guard case .align(let edge) = command else { return selectedNodeID.flatMap(lockHelp) }
        return alignHelp(edge)
    }

    /// Delete, nudge or align on the one selected layer through today's methods, which record their
    /// own step. A help refuses first: a lock as `.locked`, a hidden group as `.hidden`, a layer
    /// already in place (or one that can't move) as `.unchanged`.
    private mutating func runOneLayer(_ command: DesignCommand) throws(DesignRefusal) {
        if oneLayerHelp(command) != nil, let node = selectedNode {
            if isLockedInTree(node.id) { throw .locked(node.name) }
            if selectedPage?.hasHiddenAncestor(node.id) == true { throw .hidden(node.name) }
            throw .unchanged
        }
        switch command {
        case .delete: deleteSelection()
        case .nudge(let direction, let large): nudge(direction, shift: large)
        case .align(let edge): alignLayer(edge)
        case .duplicate, .group, .ungroup, .distribute, .arrange: break
        }
    }

    private static let finishEditing = "Finish editing the text first."

    /// Whether `old` and `new` hold the same ids in the same places, so they hold the same id set.
    static func sameIDs(_ old: [DesignNode], _ new: [DesignNode]) -> Bool {
        guard old.count == new.count else { return false }
        // Arrays sharing storage are one subtree: an edit copies only the path down to what it changed.
        let shared = old.withUnsafeBufferPointer { $0.baseAddress } == new.withUnsafeBufferPointer { $0.baseAddress }
        if shared { return true }
        for index in old.indices where old[index].id != new[index].id || !sameIDs(old[index].children, new[index].children) {
            return false
        }
        return true
    }

    private static func ids(in nodes: [DesignNode]) -> [String] {
        nodes.flatMap { [$0.id] + ids(in: $0.children) }
    }
}
