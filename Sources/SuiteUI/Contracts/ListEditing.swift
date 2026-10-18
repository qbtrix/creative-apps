// ListEditing.swift: UC10, rename outcomes, reorder and drop index for lists,
// and FakeListEditing, which never refuses and never trims on purpose (the
// live rule runs the app's validate and trims). Foundation only; verbatim from
// docs/blueprints/suiteui/contracts/Contracts.swift. The live rule is LL-2's
// SuiteListEditing.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public enum RenameOutcome: Equatable, Sendable {
    case renamed(String)
    case refused(message: String, draft: String)   // the row keeps the draft and shows the message
    case unchanged                                 // empty, whitespace only, or the same title
    case cancelled                                 // Escape
}

public protocol ListEditing: Sendable {
    /// `validate` is the app's check: nil accepts, a message refuses (#577).
    func commitRename(_ draft: String, original: String, validate: (String) -> String?) -> RenameOutcome
    func cancelRename(_ draft: String, original: String) -> RenameOutcome
    /// The order after moving `id` to `index` (an index in the order without it, clamped).
    func reordered<ID: Hashable & Sendable>(_ order: [ID], moving id: ID, to index: Int) -> [ID]
    /// Where a drop at `y` (points from the list's top) lands among `count` rows of `rowHeight`.
    func dropIndex(atY y: Double, rowHeight: Double, count: Int) -> Int
}

/// Never refuses and never trims: it ignores `validate`, so refusal UI can't be built on it.
public struct FakeListEditing: ListEditing {
    public init() {}
    public func commitRename(_ draft: String, original: String, validate: (String) -> String?) -> RenameOutcome {
        draft == original ? .unchanged : .renamed(draft)
    }
    public func cancelRename(_ draft: String, original: String) -> RenameOutcome { .cancelled }
    public func reordered<ID: Hashable & Sendable>(_ order: [ID], moving id: ID, to index: Int) -> [ID] {
        var rest = order.filter { $0 != id }
        guard rest.count < order.count else { return order }
        rest.insert(id, at: min(max(index, 0), rest.count))
        return rest
    }
    public func dropIndex(atY y: Double, rowHeight: Double, count: Int) -> Int {
        guard rowHeight > 0, y.isFinite else { return 0 }
        return min(max(Int((y / rowHeight).rounded()), 0), count)
    }
}
