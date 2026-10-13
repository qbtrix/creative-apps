// GridSelection.swift: the selection math behind ThumbnailGrid. Plain Swift
// with no SwiftUI, so the rules are unit-tested on their own. The grid owns no
// selection: each call takes the app's current selection and the anchor (the
// item the last click or arrow move landed on) and returns the new ones.
// Invariants: the result only names ids in `order`, never indexes past its
// ends, and an arrow move at an edge stays put. Shift-click replaces only the
// anchor's own run (the contiguous selected items around it, which the last
// Shift-click made) and keeps every other selected item, as a platform list does.
public enum GridSelection {
    /// The modifier held during a click.
    public enum Click: Sendable {
        case plain  // select only this item
        case toggle  // Command: add or remove this item, keep the rest
        case extend  // Shift: the anchor's range now ends at this item, keep the rest
    }

    public enum Direction: Sendable { case left, right, up, down }

    /// A new selection and the anchor that goes with it.
    public struct Result<ID: Hashable> {
        public let selection: Set<ID>
        public let anchor: ID?
    }

    /// The selection after clicking `id` in a grid showing `order`.
    public static func click<ID: Hashable>(
        _ id: ID, _ kind: Click, order: [ID], selection: Set<ID>, anchor: ID?
    ) -> Result<ID> {
        guard let target = order.firstIndex(of: id) else {
            return Result(selection: selection.intersection(order), anchor: anchor)
        }
        switch kind {
        case .plain:
            return Result(selection: [id], anchor: id)
        case .toggle:
            // Ids the grid no longer shows drop out, as Shift-click's do.
            var next = selection.intersection(order)
            if next.remove(id) == nil { next.insert(id) }
            return Result(selection: next, anchor: id)
        case .extend:
            guard let anchor, let start = order.firstIndex(of: anchor) else {
                return Result(selection: [id], anchor: id)
            }
            let previous = run(around: start, order: order, selection: selection)
            let range = min(start, target)...max(start, target)
            let kept = order.indices.filter { previous?.contains($0) != true && selection.contains(order[$0]) }
            return Result(selection: Set(kept.map { order[$0] }).union(order[range]), anchor: anchor)
        }
    }

    /// The indexes of the contiguous selected items around `index`, nil
    /// when the item there is not selected.
    private static func run<ID: Hashable>(around index: Int, order: [ID], selection: Set<ID>) -> ClosedRange<Int>? {
        guard order.indices.contains(index), selection.contains(order[index]) else { return nil }
        var low = index
        var high = index
        while low > order.startIndex, selection.contains(order[low - 1]) { low -= 1 }
        while high < order.endIndex - 1, selection.contains(order[high + 1]) { high += 1 }
        return low...high
    }

    /// The selection after an arrow key in a grid of `columns` columns: the
    /// one item next to the anchor. With no anchor it picks the first item.
    public static func move<ID: Hashable>(
        _ direction: Direction, order: [ID], columns: Int, anchor: ID?
    ) -> Result<ID> {
        guard let first = order.first else { return Result(selection: [], anchor: nil) }
        guard let anchor, let index = order.firstIndex(of: anchor) else {
            return Result(selection: [first], anchor: first)
        }
        let step = max(columns, 1)
        // Overflow-reporting math: a huge `columns` must not trap. An
        // overflowed step lands past the grid's ends, so the move stays put.
        let (next, overflow): (Int, Bool)
        switch direction {
        case .left: (next, overflow) = index.subtractingReportingOverflow(1)
        case .right: (next, overflow) = index.addingReportingOverflow(1)
        case .up: (next, overflow) = index.subtractingReportingOverflow(step)
        case .down: (next, overflow) = index.addingReportingOverflow(step)
        }
        let landed = !overflow && order.indices.contains(next) ? order[next] : anchor
        return Result(selection: [landed], anchor: landed)
    }

    /// How many columns an adaptive grid fits across `width`: cells at least
    /// `minimum` wide with `spacing` between them. Never less than 1.
    public static func columns(width: Double, minimum: Double, spacing: Double) -> Int {
        let pitch = minimum + spacing
        guard pitch > 0, width.isFinite, pitch.isFinite else { return 1 }
        let fit = ((width + spacing) / pitch).rounded(.down)
        // Clamped before Int(_:), which traps on a value past Int's range.
        return Int(min(max(fit, 1), 10_000))
    }
}
