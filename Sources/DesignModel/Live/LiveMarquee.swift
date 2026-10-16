// Live/LiveMarquee.swift: the shipped marquee, which layers a rectangle dragged on
// empty canvas selects. Invariants a reader must keep:
// - One level: the candidates are the direct children of the frame the marquee
//   started in (the top-level layers with no parent), never their descendants.
// - A hidden or locked layer is never picked, and neither is anything inside one:
//   a parent that is hidden or locked, or sits inside one, picks nothing. An id
//   that isn't on the page picks nothing too (the fakes fall back to the top level).
// - Touching is closed intervals, so a rectangle of zero size on an edge touches.
// - The result is in paint order (back to front), the order the level holds them.
// A read, so no help and no undo step. Linux-safe.

public struct LiveMarquee: MarqueeSelecting {
    public init() {}

    public func layers(touching rect: DesignRect, in parentID: String?, on page: DesignPage) -> [String] {
        let level = parentID.map { openChildren(of: $0, in: page.nodes) ?? [] } ?? page.nodes
        return level.filter { node in
            !node.isHidden && !node.isLocked
                && node.frame.x <= rect.maxX && rect.x <= node.frame.maxX
                && node.frame.y <= rect.maxY && rect.y <= node.frame.maxY
        }.map(\.id)
    }

    /// The children of `id`, reached only through visible, unlocked layers; nil when `id` isn't in
    /// `nodes` or it, or a layer around it, is hidden or locked.
    private func openChildren(of id: String, in nodes: [DesignNode]) -> [DesignNode]? {
        for node in nodes where !node.isHidden && !node.isLocked {
            if node.id == id { return node.children }
            if let children = openChildren(of: id, in: node.children) { return children }
        }
        return nil
    }
}
