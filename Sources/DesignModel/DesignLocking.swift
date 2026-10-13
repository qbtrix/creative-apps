// DesignLocking.swift: when a node can't be edited. A lock covers the node's
// whole subtree, the way canvas hit testing already treats it, so a layer
// inside a locked group is locked too. The inspector reads `lockHelp` to
// disable its fields and say why. Linux-safe: no UI imports.

extension DesignWorkspace {
    /// Whether node `id` or any node enclosing it is locked; false for an unknown id.
    public func isLockedInTree(_ id: String) -> Bool {
        anyInTree(id) { $0.isLocked }
    }

    /// Whether node `id` or any node enclosing it passes `test`; false for an unknown id.
    func anyInTree(_ id: String, _ test: (DesignNode) -> Bool) -> Bool {
        for page in pages {
            guard let path = page.nodes.ancestors(of: id) else { continue }
            return (path + [id]).contains { page.nodes.node($0).map(test) == true }
        }
        return false
    }

    /// Why node `id` can't be edited, or nil when it can.
    public func lockHelp(_ id: String) -> String? {
        guard isLockedInTree(id) else { return nil }
        return findNode(id)?.isLocked == true ? "Unlock the layer to edit it." : "Unlock the group around this layer to edit it."
    }
}
