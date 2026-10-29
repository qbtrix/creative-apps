// Live/LiveDuplicating.swift: Duplicate (Command-D) on the live services, and the
// copy an Option-drag moves (copy-group C-1, #414, blueprint 5.4). Each selected
// layer is copied with its whole subtree, every id fresh from the mint, and the
// copy goes directly above its original in the same parent, moved by `offset`.
// DesignCanvasEditing routes Option-drag here with a zero offset and moves the
// copies itself, so both gestures share this one duplicate. `copySubtree` is the
// id-refreshing copy the clipboard reuses (C-3). An adapter over SuiteKernel's
// LayerTree (DesignNode+Kernel): the kernel copies and places each layer; this
// file picks the outermost layers, then offsets and unlocks the copies.
//
// Invariants:
// - No id repeats: every copied node takes the mint's next id.
// - The copy equals its original except ids, the offset, and the top copy's
//   lock (a Locked layer duplicates unlocked; its children keep theirs).
// - A layer whose ancestor is also selected is copied once, inside that ancestor.
// - Nothing selected throws `.nothingSelected` and changes nothing.
// - Each help is nil exactly when its write succeeds (the help law).
// Linux-safe.

import SuiteKernel

public struct LiveDuplicating: LayerDuplicating {
    public init() {}

    public func duplicateHelp(_ ids: [String], on page: DesignPage) -> String? {
        fakeHelp { () throws(DesignRefusal) in
            var scratch = DesignIDMint(taken: [], after: 0)
            return try duplicate(ids, offset: DesignPoint(x: 0, y: 0), on: page, mint: &scratch)
        }
    }

    /// One "Duplicate" step: each copy right above its original, moved by `offset`, unlocked; the copies selected.
    public func duplicate(_ ids: [String], offset: DesignPoint, on page: DesignPage,
                          mint: inout DesignIDMint) throws(DesignRefusal) -> DesignEdit {
        var tree = page.nodes.layerTree
        let copies = tree.duplicate(outermost(ids, in: page.nodes), mint: { mint.nextNodeID() })
        guard !copies.isEmpty else { throw .nothingSelected }
        var nodes = tree.designNodes
        for id in copies {
            _ = nodes.update(id) { copy in
                copy.translate(by: offset, carryingKeys: true)
                copy.isLocked = false
            }
        }
        return DesignEdit(name: "Duplicate", nodes: nodes, selection: copies)
    }

    /// `node` and its subtree, parent before children, each with the mint's next id.
    public func copySubtree(_ node: DesignNode, mint: inout DesignIDMint) -> DesignNode {
        let id = mint.nextNodeID()
        var copy = DesignNode(id: id, copying: node)
        copy.children = node.children.map { copySubtree($0, mint: &mint) }
        return copy
    }

    /// The selected layers that are on the page and have no selected ancestor, once each, in
    /// selection order.
    private func outermost(_ ids: [String], in nodes: [DesignNode]) -> [String] {
        let wanted = Set(ids)
        var seen: Set<String> = []
        var out: [String] = []
        for id in ids where seen.insert(id).inserted {
            guard let path = nodes.ancestors(of: id) else { continue }
            guard !path.contains(where: wanted.contains) else { continue }
            out.append(id)
        }
        return out
    }
}
