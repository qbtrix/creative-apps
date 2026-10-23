// DesignLocking.swift: when a node can't be edited. A lock covers the node's
// whole subtree, the way canvas hit testing already treats it, so a layer
// inside a locked group is locked too. The kernel's LayerTree owns that cascade
// and the walk to a node's ancestors (DesignNode+Kernel). The inspector reads
// `lockHelp` to disable its fields and say why. Linux-safe: no UI imports.
import SuiteKernel

extension DesignWorkspace {
    /// Whether node `id` or any node enclosing it is locked; false for an unknown id.
    public func isLockedInTree(_ id: String) -> Bool {
        pages.contains { $0.nodes.layerTree.isEffectivelyLocked(id) }
    }

    /// Whether node `id` or any node enclosing it passes `test`; false for an unknown id.
    func anyInTree(_ id: String, _ test: (DesignNode) -> Bool) -> Bool {
        for page in pages {
            let tree = page.nodes.layerTree
            guard let path = tree.ancestors(of: id) else { continue }
            return (path + [id]).contains { tree.node($0).map { test($0.payload.node) } == true }
        }
        return false
    }

    /// Why node `id` can't be edited, or nil when it can.
    public func lockHelp(_ id: String) -> String? {
        guard isLockedInTree(id) else { return nil }
        return findNode(id)?.isLocked == true ? "Unlock the layer to edit it." : "Unlock the group around this layer to edit it."
    }
}
