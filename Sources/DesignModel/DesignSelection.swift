// DesignSelection.swift: several selected layers (#413, Shift-click). The
// workspace keeps `selectedNodeIDs`, the layers in the order they joined, and
// the last one is the primary selection `selectedNodeID` that single-selection
// callers (the inspector's fields, handles, Nudge, Delete) read. A plain click
// replaces the selection (`selectItem`), Shift-click on the canvas or in Layers
// adds one layer or takes it out (`toggleSelection`), and Escape or a click on
// empty canvas clears it (`deselect`). A layer that is locked, inside a locked
// group or inside a hidden group can't join, the same subtree checks the canvas
// uses (DesignLocking, DesignLayerToggles). Selection is not an undo step; a
// step's snapshot carries the whole set. The marquee is #413's second slice.
// Linux-safe.

extension DesignWorkspace {
    /// The text the inspector shows in place of values while several layers are selected.
    public static let multipleLayersText = "Multiple layers selected"
    /// Why the inspector can't edit frames or fills with several layers selected.
    public static let multipleLayersHelp = "Editing several layers at once isn't built yet."

    /// The selected layers, in the order they joined; the last is the primary selection.
    public var selectedNodes: [DesignNode] {
        guard let page = selectedPage else { return [] }
        return selectedNodeIDs.compactMap { page.nodes.node($0) }
    }

    public var hasMultipleSelection: Bool { selectedNodeIDs.count > 1 }

    public func isSelected(_ id: String) -> Bool { selectedNodeIDs.contains(id) }

    /// Whether Shift-click can add node `id`: it is on the selected page, and neither it nor a
    /// group around it is locked or hidden.
    public func canAddToSelection(_ id: String) -> Bool {
        selectedPage?.nodes.node(id) != nil && !isLockedInTree(id) && !isHiddenInTree(id)
    }

    /// The box around every selected layer the canvas shows, in page points; nil with none
    /// showing. A layer hidden since it joined is left out, as the canvas leaves it out.
    public var selectionBounds: DesignRect? {
        let frames = selectedNodes.filter { !isHiddenInTree($0.id) }.map(\.frame)
        guard let first = frames.first else { return nil }
        return frames.dropFirst().reduce(first) { box, frame in
            let (x, y) = (Swift.min(box.x, frame.x), Swift.min(box.y, frame.y))
            return DesignRect(
                x: x, y: y, width: Swift.max(box.maxX, frame.maxX) - x, height: Swift.max(box.maxY, frame.maxY) - y)
        }
    }

    /// Shift-click: takes node `id` out of the selection when it is in it, otherwise adds it as
    /// the primary selection. Adding is refused for a layer `canAddToSelection` turns down.
    public mutating func toggleSelection(_ id: String) {
        if let index = selectedNodeIDs.firstIndex(of: id) {
            commitTextEdit()
            selectedNodeIDs.remove(at: index)
            return
        }
        guard canAddToSelection(id), let page = selectedPage else { return }
        commitTextEdit()
        selectedNodeIDs.append(id)
        expandAncestors(of: id, in: page.nodes)
    }

    /// The Layers list's selection changed to `ids` (pages and layers). Without Shift one row
    /// selects that page or layer, no row clears the layer selection, and several rows (the
    /// system's Command-click) keep the layers that can join. With Shift only the clicked row
    /// toggles: the list may extend a range from the primary, so the clicked row is the added
    /// layer farthest from it in row order, or the one layer the list dropped.
    public mutating func selectRows(_ ids: Set<String>, shift: Bool) {
        let order = layerRows.map(\.id)
        let added = order.filter { ids.contains($0) && !isSelected($0) }
        if shift {
            let removed = selectedNodeIDs.filter { !ids.contains($0) }
            let anchor = selectedNodeID.flatMap { order.firstIndex(of: $0) }
            let clicked = anchor.map { at in
                added.max { distance(of: $0, from: at, in: order) < distance(of: $1, from: at, in: order) }
            } ?? added.last
            if let clicked {
                toggleSelection(clicked)
            } else if removed.count == 1, let id = removed.first {
                toggleSelection(id)
            }
            return
        }
        guard ids.count > 1 else {
            if let id = ids.first { selectItem(id) } else { deselect() }
            return
        }
        let kept = selectedNodeIDs.filter(ids.contains)
        let joined = added.filter(canAddToSelection)
        guard !(kept + joined).isEmpty else { return }
        commitTextEdit()
        selectedNodeIDs = kept + joined
    }

    private func distance(of id: String, from index: Int, in order: [String]) -> Int {
        order.firstIndex(of: id).map { abs($0 - index) } ?? 0
    }
}
