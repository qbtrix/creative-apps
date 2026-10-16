// Live/LiveDuplicating.swift: Duplicate on the live services. Until the
// duplicate feature takes this file over, every help and write forwards to
// NotBuilt("Duplicate"), so Command-D is disabled with "Duplicate isn't built
// yet." and never acts. Linux-safe.

public struct LiveDuplicating: LayerDuplicating {
    private let base = NotBuilt("Duplicate")
    public init() {}

    public func duplicateHelp(_ ids: [String], on page: DesignPage) -> String? { base.duplicateHelp(ids, on: page) }
    public func duplicate(_ ids: [String], offset: DesignPoint, on page: DesignPage,
                          mint: inout DesignIDMint) throws(DesignRefusal) -> DesignEdit {
        try base.duplicate(ids, offset: offset, on: page, mint: &mint)
    }
    public func copySubtree(_ node: DesignNode, mint: inout DesignIDMint) -> DesignNode { base.copySubtree(node, mint: &mint) }
}
