// GridSelection.swift: the selection math behind ThumbnailGrid. Plain Swift
// with no SwiftUI, so the rules are unit-tested on their own. The grid owns no
// selection: each call takes the app's current selection and the anchor (the
// item the last click or arrow move landed on) and returns the new ones.
// Invariants: the result only names ids in `order`, never indexes past its
// ends, and an arrow move at an edge stays put.
public enum GridSelection {
    /// The modifier held during a click.
    public enum Click: Sendable {
        /// Select only this item.
        case plain
        /// Command: add or remove this item, keep the rest.
        case toggle
        /// Shift: select the range from the anchor to this item.
        case extend
    }

    public enum Direction: Sendable {
        case left, right, up, down
    }

    /// A new selection and the anchor that goes with it.
    public struct Result<ID: Hashable> {
        public let selection: Set<ID>
        public let anchor: ID?
    }

    /// The selection after clicking `id` in a grid showing `order`.
    public static func click<ID: Hashable>(
        _ id: ID, _ kind: Click, order: [ID], selection: Set<ID>, anchor: ID?
    ) -> Result<ID> {
        guard let target = order.firstIndex(of: id) else { return Result(selection: selection, anchor: anchor) }
        switch kind {
        case .plain:
            return Result(selection: [id], anchor: id)
        case .toggle:
            var next = selection
            if next.remove(id) == nil { next.insert(id) }
            return Result(selection: next, anchor: id)
        case .extend:
            guard let anchor, let start = order.firstIndex(of: anchor) else {
                return Result(selection: [id], anchor: id)
            }
            let range = min(start, target)...max(start, target)
            return Result(selection: Set(order[range]), anchor: anchor)
        }
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
        let next: Int
        switch direction {
        case .left: next = index - 1
        case .right: next = index + 1
        case .up: next = index - step
        case .down: next = index + step
        }
        let landed = order.indices.contains(next) ? order[next] : anchor
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
