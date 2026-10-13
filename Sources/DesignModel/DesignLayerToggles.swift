// DesignLayerToggles.swift: the eye and lock toggles on a Layers panel row.
// Each toggle shows the node's own flag; when a group around the node is
// hidden or locked the off symbol says so, so a child row shows its parent's
// state. A click flips the node's own flag through setNodeHidden or
// setNodeLocked, one undo step. Linux-safe: no UI imports.

/// The two flags a Layers row toggles; the raw value is the toggle's id.
public enum DesignLayerFlag: String, CaseIterable, Sendable {
    case hidden, locked
}

/// One row toggle as the panel draws it: `onSymbol` while the node's own flag is set, else `offSymbol`.
public struct DesignLayerToggle: Equatable, Sendable {
    public let flag: DesignLayerFlag
    /// The tooltip and accessibility label: what a click does.
    public let title: String
    public let onSymbol: String
    public let offSymbol: String
    public let isOn: Bool
}

extension DesignWorkspace {
    /// Whether node `id` or any node enclosing it is hidden; false for an unknown id.
    public func isHiddenInTree(_ id: String) -> Bool {
        anyInTree(id) { $0.isHidden }
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
