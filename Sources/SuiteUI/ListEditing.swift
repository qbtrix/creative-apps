// ListEditing.swift: SuiteListEditing, the live UC10 rule the list rows call
// (lists-and-layers LL-2). A rename trims the draft, treats an empty or
// unchanged name as no change, and runs the app's validate; a refusal keeps
// the draft exactly as typed so the field can stay open with the message.
// A reorder moves one id to an index in the order without it, clamped, and
// leaves an order without that id as it was. A drop index never divides by a
// zero row height and ignores a non-finite y. Foundation only, pure.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public struct SuiteListEditing: ListEditing {
    public init() {}

    public func commitRename(_ draft: String, original: String, validate: (String) -> String?) -> RenameOutcome {
        let name = Self.trimmed(draft)
        if name.isEmpty || name == original { return .unchanged }
        if let message = validate(name) { return .refused(message: message, draft: draft) }
        return .renamed(name)
    }

    public func cancelRename(_ draft: String, original: String) -> RenameOutcome { .cancelled }

    public func reordered<ID: Hashable & Sendable>(_ order: [ID], moving id: ID, to index: Int) -> [ID] {
        guard let from = order.firstIndex(of: id) else { return order }
        var rest = order
        rest.remove(at: from)
        rest.insert(id, at: min(max(index, 0), rest.count))
        return rest
    }

    public func dropIndex(atY y: Double, rowHeight: Double, count: Int) -> Int {
        guard rowHeight > 0, rowHeight.isFinite, y.isFinite, count > 0 else { return 0 }
        let rows = (y / rowHeight).rounded()
        guard rows > 0 else { return 0 }
        guard rows < Double(count) else { return count }
        return Int(rows)
    }

    /// The draft without leading or trailing whitespace and newlines.
    static func trimmed(_ text: String) -> String {
        guard let start = text.firstIndex(where: { !$0.isWhitespace }),
              let end = text.lastIndex(where: { !$0.isWhitespace }) else { return "" }
        return String(text[start...end])
    }
}
