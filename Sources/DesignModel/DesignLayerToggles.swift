// DesignLayerToggles.swift: the eye and lock toggles on a Layers panel row.
// Each toggle shows the node's own flag; when a group around the node is
// hidden or locked the off symbol says so, so a child row shows its parent's
// state. Each flag names every symbol it can show (`symbols`), and the panel
// reserves room for all of them so the eye and lock columns never move. A click flips the node's own flag through setNodeHidden or
// setNodeLocked, one undo step. A drag between rows maps through layerDrop to
// the (parent, index) LayerOrdering.move takes: rows list front to back while
// children are stored back to front, and the index counts the parent's children
// after the dragged layer is removed. Linux-safe: no UI imports.

/// The two flags a Layers row toggles; the raw value is the toggle's id.
public enum DesignLayerFlag: String, CaseIterable, Sendable {
    case hidden, locked

    /// Every symbol this flag's toggle shows in any state: its own flag on, off, or off inside a
    /// hidden or locked group.
    public var symbols: [String] {
        switch self {
        case .hidden: ["eye.slash", "eye"]
        case .locked: ["lock.fill", "lock.open", "lock"]
        }
    }
}

/// One row toggle as the panel draws it: `onSymbol` while the node's own flag is set, else `offSymbol`.
public struct DesignLayerToggle: Equatable, Sendable {
    public let flag: DesignLayerFlag
    /// The tooltip and accessibility label: what a click does.
    public let title: String
    public let onSymbol: String
    public let offSymbol: String
    public let isOn: Bool

    /// Every symbol the toggle can show, whatever the state: the room the panel reserves for it.
    public var symbols: [String] { flag.symbols }
}

/// Where a Layers drop lands relative to the row under it: in front of it, behind it, or inside it last.
public enum DesignDropPosition: Sendable {
    case above, below, into

    /// The position a pointer `y` points down from the top of a row `height` tall picks: the top
    /// quarter is above, the bottom quarter below, and the middle half into a row that
    /// `holdsChildren`; on any other row the nearer half decides. nil off the row, or for a row
    /// with no height.
    public init?(y: Double, height: Double, holdsChildren: Bool) {
        guard height > 0, y.isFinite, y >= 0, y <= height else { return nil }
        if holdsChildren, y >= height / 4, y <= height * 3 / 4 {
            self = .into
        } else {
            self = y < height / 2 ? .above : .below
        }
    }
}

extension DesignPage {
    /// The move target for dropping layer `draggedID` at row `rowID`'s `position`: the parent (nil: the
    /// top level) and the index among its children back to front, counted after `draggedID` is removed,
    /// as `LayerOrdering.move` expects. nil for an unknown id, a drop onto the dragged row itself, or
    /// `.into` a row that is not a frame or group. Other refusals (into its own subtree, a lock) are
    /// `moveLayerHelp`'s.
    public func layerDrop(_ draggedID: String, onto rowID: String, _ position: DesignDropPosition) -> (parentID: String?, index: Int)? {
        guard draggedID != rowID, nodes.node(draggedID) != nil, let row = nodes.node(rowID),
              let rowPath = nodes.ancestors(of: rowID) else { return nil }
        let parentID: String?
        var index: Int
        switch position {
        case .into:
            guard row.kind.holdsChildren else { return nil }
            (parentID, index) = (rowID, row.children.count)
        case .above, .below:
            parentID = rowPath.last
            let siblings = parentID.flatMap { nodes.node($0)?.children } ?? nodes
            guard let rowIndex = siblings.firstIndex(where: { $0.id == rowID }) else { return nil }
            index = position == .above ? rowIndex + 1 : rowIndex
        }
        let siblings = parentID.flatMap { nodes.node($0)?.children } ?? nodes
        if let draggedIndex = siblings.firstIndex(where: { $0.id == draggedID }), draggedIndex < index { index -= 1 }
        return (parentID, index)
    }

    /// Whether node `id` or any node enclosing it on this page is hidden; false for an id not on
    /// it. The one hidden-in-tree rule: the Layers rows, the selection and export all read it.
    public func isHiddenInTree(_ id: String) -> Bool {
        nodes.onPath(to: id) { $0.isHidden } == true
    }
}

extension DesignWorkspace {
    /// Whether node `id` or any node enclosing it is hidden (DesignPage's rule, on its page);
    /// false for an unknown id.
    public func isHiddenInTree(_ id: String) -> Bool {
        pages.contains { $0.isHiddenInTree(id) }
    }

    /// The move target for a Layers drop on the selected page (DesignPage's `layerDrop`); nil without one.
    public func layerDrop(_ draggedID: String, onto rowID: String, _ position: DesignDropPosition) -> (parentID: String?, index: Int)? {
        selectedPage?.layerDrop(draggedID, onto: rowID, position)
    }

    /// Where the insertion line goes while layer `draggedID` is dragged `y` points down a row
    /// `height` tall showing `rowID`: its position (DesignDropPosition's rule), or nil when the
    /// drop is refused (onto itself, into its own subtree, a lock, a row that is off the page).
    public func layerDropLine(_ draggedID: String, over rowID: String, y: Double, height: Double) -> DesignDropPosition? {
        guard let row = findNode(rowID),
              let position = DesignDropPosition(y: y, height: height, holdsChildren: row.kind.holdsChildren),
              let target = layerDrop(draggedID, onto: rowID, position),
              moveLayerHelp(draggedID, into: target.parentID, at: target.index) == nil else { return nil }
        return position
    }

    /// The eye and lock toggles for node `id`'s row, in that order; empty for an unknown id.
    public func layerToggles(_ id: String) -> [DesignLayerToggle] {
        guard let node = findNode(id) else { return [] }
        let hiddenByGroup = !node.isHidden && isHiddenInTree(id)
        let lockedByGroup = !node.isLocked && isLockedInTree(id)
        return [
            DesignLayerToggle(
                flag: .hidden,
                title: node.isHidden ? "Show Layer" : hiddenByGroup ? "Hide Layer (its group is hidden)" : "Hide Layer",
                onSymbol: "eye.slash", offSymbol: hiddenByGroup ? "eye.slash" : "eye", isOn: node.isHidden),
            DesignLayerToggle(
                flag: .locked,
                title: node.isLocked ? "Unlock Layer" : lockedByGroup ? "Lock Layer (its group is locked)" : "Lock Layer",
                onSymbol: "lock.fill", offSymbol: lockedByGroup ? "lock" : "lock.open", isOn: node.isLocked),
        ]
    }

    /// Flips node `id`'s own `flag`, as a click on its row toggle does: one undo step.
    public mutating func toggleNodeFlag(_ id: String, _ flag: DesignLayerFlag) throws(DesignTreeError) {
        guard let node = findNode(id) else { throw .unknownID(id) }
        switch flag {
        case .hidden: try setNodeHidden(id, !node.isHidden)
        case .locked: try setNodeLocked(id, !node.isLocked)
        }
    }
}
