// Selection.swift (EK-2 stub, EK-10 body): the one ordered selection every
// app keeps, primary last, one `Pick` rule; `Nudge` and `Marquee` join this
// folder in EK-10. The stub keeps the ids it was built with, changes nothing.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// An ordered selection of ids with a primary and an anchor.
public struct Selection<ID: Hashable & Sendable>: Sendable, Equatable {
    /// The picked ids in the order they were picked, no repeats.
    public private(set) var ordered: [ID]
    /// Where a Shift-click range starts: the last item picked by replace or toggle.
    public var anchor: ID?
    /// A selection of `ids`, in that order.
    public init(_ ids: [ID] = []) {
        ordered = ids
    }
    /// The primary item: the last picked, nil when empty.
    public var primary: ID? { ordered.last }
    /// The picked ids as a set, for membership tests in bulk.
    public var set: Set<ID> { Set(ordered) }
    /// True when `id` is picked.
    public func contains(_ id: ID) -> Bool { ordered.contains(id) }
    /// Applies one click: replace, toggle, or extend (from the anchor through
    /// `order` when given). `canAdd` refuses an id that may not join. Returns
    /// whether the selection changed. Stub: changes nothing, false.
    @discardableResult
    public mutating func pick(_ id: ID, _ pick: Pick, order: [ID]? = nil, canAdd: (ID) -> Bool = { _ in true }) -> Bool {
        false
    }
    /// Makes `ids` the whole selection. Stub: nothing.
    public mutating func replace(_ ids: [ID]) {}
    /// Empties the selection and its anchor. Stub: nothing.
    public mutating func clear() {}
    /// Picks every candidate `canAdd` allows, in order. Stub: nothing.
    public mutating func selectAll(_ candidates: [ID], canAdd: (ID) -> Bool = { _ in true }) {}
    /// Drops every id `alive` says is gone. Stub: nothing.
    public mutating func prune(alive: (ID) -> Bool) {}
    /// Moves a single selection by arrow through `order`, laid out in a grid
    /// of `columns`. Stub: nothing.
    public mutating func move(_ direction: Direction, order: [ID], columns: Int) {}
}
