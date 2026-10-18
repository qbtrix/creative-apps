// GridSelecting.swift: UC9, grid selection by click and arrow key, and
// FakeGridSelecting, which keeps single selection only on purpose (the live
// rule extends and toggles). Foundation only; verbatim from
// docs/blueprints/suiteui/contracts/Contracts.swift. GridArrow lives in
// ContractTypes.swift. The live rule is LL-3's SuiteGridSelecting.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public enum ClickKind: Sendable { case plain, extend, toggle }   // click, ⇧-click, ⌘-click

public struct GridPick<ID: Hashable & Sendable>: Equatable, Sendable {
    public var selection: Set<ID>
    public var anchor: ID?
    public init(selection: Set<ID> = [], anchor: ID? = nil) { self.selection = selection; self.anchor = anchor }
}

public protocol GridSelecting: Sendable {
    func click<ID: Hashable & Sendable>(_ id: ID, _ kind: ClickKind, current: GridPick<ID>, order: [ID]) -> GridPick<ID>
    func move<ID: Hashable & Sendable>(_ arrow: GridArrow, extend: Bool, current: GridPick<ID>, order: [ID], columns: Int) -> GridPick<ID>
    /// Adaptive columns for `width`; at least 1.
    func columns(width: Double, minimum: Double, spacing: Double) -> Int
}

/// Single selection only: every click selects just that item; arrows move one item and never extend.
public struct FakeGridSelecting: GridSelecting {
    public init() {}
    public func click<ID: Hashable & Sendable>(_ id: ID, _ kind: ClickKind, current: GridPick<ID>, order: [ID]) -> GridPick<ID> {
        order.contains(id) ? GridPick(selection: [id], anchor: id) : current
    }
    public func move<ID: Hashable & Sendable>(_ arrow: GridArrow, extend: Bool, current: GridPick<ID>, order: [ID], columns: Int) -> GridPick<ID> {
        guard let anchor = current.anchor, let i = order.firstIndex(of: anchor) else { return current }
        let step = switch arrow { case .left: -1; case .right: 1; case .up: -max(columns, 1); case .down: max(columns, 1) }
        let j = i + step
        guard order.indices.contains(j) else { return current }
        return GridPick(selection: [order[j]], anchor: order[j])
    }
    public func columns(width: Double, minimum: Double, spacing: Double) -> Int {
        guard minimum > 0, width.isFinite else { return 1 }
        return max(1, Int((width + spacing) / (minimum + spacing)))
    }
}
