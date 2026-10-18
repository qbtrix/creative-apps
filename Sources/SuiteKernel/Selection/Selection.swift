// Selection.swift (EK-2 stub, EK-10 body): the one ordered selection every
// app keeps, primary last, one `Pick` rule. `Nudge` and `Marquee` sit beside
// it in this folder.
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
    /// The ids the last Shift-click range added, which the next Shift-click
    /// from the same anchor takes back before it adds its own range.
    private var run: [ID] = []

    /// A selection of `ids`, in that order, each id once.
    public init(_ ids: [ID] = []) {
        ordered = Self.unique(ids)
    }

    /// Two selections are equal when they pick the same ids in the same order
    /// from the same anchor.
    public static func == (lhs: Selection, rhs: Selection) -> Bool {
        lhs.ordered == rhs.ordered && lhs.anchor == rhs.anchor
    }

    /// The primary item: the last picked, nil when empty.
    public var primary: ID? { ordered.last }
    /// The picked ids as a set, for membership tests in bulk.
    public var set: Set<ID> { Set(ordered) }
    /// True when `id` is picked.
    public func contains(_ id: ID) -> Bool { ordered.contains(id) }

    /// Applies one click: replace, toggle, or extend (from the anchor through
    /// `order` when given, both ends included; without an order the item
    /// alone joins). `canAdd` refuses an id that may not join, on every path.
    /// Returns whether the selection changed.
    @discardableResult
    public mutating func pick(_ id: ID, _ pick: Pick, order: [ID]? = nil, canAdd: (ID) -> Bool = { _ in true }) -> Bool {
        let before = self
        switch pick {
        case .replace:
            guard canAdd(id) else { return false }
            ordered = [id]
            anchor = id
            run = []
        case .toggle:
            if let index = ordered.firstIndex(of: id) {
                ordered.remove(at: index)
            } else if canAdd(id) {
                ordered.append(id)
            } else {
                return false
            }
            anchor = id
            run = []
        case .extend:
            guard contains(id) || canAdd(id) else { return false }
            if let order, let anchor, let a = order.firstIndex(of: anchor), let b = order.firstIndex(of: id) {
                extend(through: a <= b ? Array(order[a...b]) : Array(order[b...a].reversed()), canAdd: canAdd)
            } else {
                append(id)
                if anchor == nil { anchor = id }
            }
        }
        return self != before
    }

    /// Takes back the previous range from this anchor, then adds `range` in
    /// order, skipping what `canAdd` refuses; the clicked end lands last.
    private mutating func extend(through range: [ID], canAdd: (ID) -> Bool) {
        let previous = Set(run)
        ordered.removeAll { previous.contains($0) }
        run = []
        for item in range where contains(item) || canAdd(item) {
            if !contains(item) { run.append(item) }
            append(item)
        }
    }

    /// Puts `id` at the end, moving it there when it is already picked.
    private mutating func append(_ id: ID) {
        ordered.removeAll { $0 == id }
        ordered.append(id)
    }

    /// Makes `ids` the whole selection; the last becomes the primary and the anchor.
    public mutating func replace(_ ids: [ID]) {
        ordered = Self.unique(ids)
        anchor = ordered.last
        run = []
    }

    /// Empties the selection and its anchor.
    public mutating func clear() {
        ordered = []
        anchor = nil
        run = []
    }

    /// Picks every candidate `canAdd` allows, in order.
    public mutating func selectAll(_ candidates: [ID], canAdd: (ID) -> Bool = { _ in true }) {
        ordered = Self.unique(candidates.filter(canAdd))
        if let anchor, !contains(anchor) { self.anchor = nil }
        run = []
    }

    /// Drops every id `alive` says is gone; an anchor that is gone moves to
    /// the primary.
    public mutating func prune(alive: (ID) -> Bool) {
        ordered.removeAll { !alive($0) }
        run.removeAll { !alive($0) }
        if let anchor, !alive(anchor) { self.anchor = primary }
    }

    /// Moves a single selection by arrow from the primary through `order`,
    /// laid out in a grid of `columns`: left and right step through `order`
    /// (wrapping to the next or previous row), up and down step a column;
    /// past the grid's first or last cell it stays put.
    public mutating func move(_ direction: Direction, order: [ID], columns: Int) {
        guard columns > 0, let primary, let index = order.firstIndex(of: primary) else { return }
        let target: Int
        switch direction {
        case .left: target = index > 0 ? index - 1 : index
        case .right: target = index + 1 < order.count ? index + 1 : index
        case .up: target = index - columns >= 0 ? index - columns : index
        case .down: target = index + columns < order.count ? index + columns : index
        }
        let id = order[target]
        ordered = [id]
        anchor = id
        run = []
    }

    /// `ids` with repeats dropped, first occurrence kept.
    private static func unique(_ ids: [ID]) -> [ID] {
        var seen = Set<ID>()
        return ids.filter { seen.insert($0).inserted }
    }
}
