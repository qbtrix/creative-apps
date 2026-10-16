// Live/LiveGrouping.swift: Group and Ungroup on the live services. Until the
// grouping feature takes this file over, every help and write forwards to
// NotBuilt("Group"), so both commands are disabled with "Group isn't built
// yet." and never act. Linux-safe.

public struct LiveGrouping: LayerGrouping {
    private let base = NotBuilt("Group")
    public init() {}

    public func groupHelp(_ ids: [String], on page: DesignPage) -> String? { base.groupHelp(ids, on: page) }
    public func group(_ ids: [String], on page: DesignPage, mint: inout DesignIDMint) throws(DesignRefusal) -> DesignEdit {
        try base.group(ids, on: page, mint: &mint)
    }
    public func ungroupHelp(_ ids: [String], on page: DesignPage) -> String? { base.ungroupHelp(ids, on: page) }
    public func ungroup(_ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit { try base.ungroup(ids, on: page) }
}
