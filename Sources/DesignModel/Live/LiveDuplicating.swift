// Live/LiveDuplicating.swift: Duplicate (Command-D) on the live services, and the
// copy an Option-drag moves (copy-group C-1, #414, blueprint 5.4). Each selected
// layer is copied with its whole subtree, every id fresh from the mint, and the
// copy goes directly above its original in the same parent, moved by `offset`.
// DesignCanvasEditing routes Option-drag here with a zero offset and moves the
// copies itself, so both gestures share this one duplicate. `copySubtree` is the
// id-refreshing copy the clipboard reuses (C-3). The whole duplicate is two walks
// of the tree however many layers are selected: one finds the outermost selected
// layers, one rebuilds the tree with each copy placed above its original. A
// per-layer tree walk made 1,500 layers take seconds (#5838).
//
// Invariants:
// - No id repeats: every copied node takes the mint's next id.
// - The copy equals its original except ids, the offset, and the top copy's
//   lock (a Locked layer duplicates unlocked; its children keep theirs).
// - A layer whose ancestor is also selected is copied once, inside that ancestor.
// - Nothing selected throws `.nothingSelected` and changes nothing.
// - Each help is nil exactly when its write succeeds (the help law).
// Linux-safe.

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
        let byID = outermost(ids, in: page.nodes)
        var copies: [String: DesignNode] = [:], selection: [String] = []
        for id in ids {
            guard let original = byID[id], copies[id] == nil else { continue }
            var copy = copySubtree(original, mint: &mint)
            copy.translate(by: offset)
            copy.isLocked = false
            copies[id] = copy
            selection.append(copy.id)
        }
        guard !selection.isEmpty else { throw .nothingSelected }
        func placed(_ nodes: [DesignNode]) -> [DesignNode] {
            var out: [DesignNode] = []
            out.reserveCapacity(nodes.count)
            for var node in nodes {
                if !node.children.isEmpty { node.children = placed(node.children) }
                out.append(node)
                if let copy = copies[node.id] { out.append(copy) }
            }
            return out
        }
        return DesignEdit(name: "Duplicate", nodes: placed(page.nodes), selection: selection)
    }

    /// `node` and its subtree, parent before children, each with the mint's next id.
    public func copySubtree(_ node: DesignNode, mint: inout DesignIDMint) -> DesignNode {
        let id = mint.nextNodeID()
        var copy = DesignNode(id: id, copying: node)
        copy.children = node.children.map { copySubtree($0, mint: &mint) }
        return copy
    }

    /// The selected layers that are on the page and have no selected ancestor, by id, in one walk.
    private func outermost(_ ids: [String], in nodes: [DesignNode]) -> [String: DesignNode] {
        let wanted = Set(ids)
        var out: [String: DesignNode] = [:]
        func walk(_ nodes: [DesignNode]) {
            for node in nodes {
                if wanted.contains(node.id) { out[node.id] = node } else { walk(node.children) }
            }
        }
        walk(nodes)
        return out
    }
}
