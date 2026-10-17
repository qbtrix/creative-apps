// Live/LiveOrdering.swift: stacking order and nesting on the live services.
// Until the reordering feature takes this file over, every help and write
// forwards to NotBuilt("Reordering layers"), so Move Layer and Object > Arrange
// are disabled with "Reordering layers isn't built yet." and never act.
// Linux-safe.

public struct LiveOrdering: LayerOrdering {
    private let base = NotBuilt("Reordering layers")
    public init() {}

    public func moveHelp(_ id: String, into parentID: String?, at index: Int, on page: DesignPage) -> String? {
        base.moveHelp(id, into: parentID, at: index, on: page)
    }
    public func move(_ id: String, into parentID: String?, at index: Int, on page: DesignPage) throws(DesignRefusal) -> DesignEdit {
        try base.move(id, into: parentID, at: index, on: page)
    }
    public func arrangeHelp(_ step: DesignArrangeStep, _ ids: [String], on page: DesignPage) -> String? {
        base.arrangeHelp(step, ids, on: page)
    }
    public func arrange(_ step: DesignArrangeStep, _ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit {
        try base.arrange(step, ids, on: page)
    }
}
