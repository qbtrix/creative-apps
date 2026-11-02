// Facet.swift: one slice of an editor window's state in its own observable
// box (the AppKit window shell plan, option A's facets). An app's session
// (PhotoSession) keeps its Model value out of Observation and republishes it
// as a few small Equatable facets, each in a Facet. After every edit it
// re-derives them and `set`s each one; a facet whose value is unchanged is not
// written, so a view whose body reads only `tool.value` re-runs on a tool
// change and never on a layer pick. Observation tracks per property
// (developer.apple.com, "Managing model data in your app"), and `value` is the
// box's only property, so the box is the unit a body depends on.
// Invariant: `set` never writes an equal value; that is the whole point of the
// box, so it does not lean on the macro's own equality check.
import Observation

/// One facet of a window's state: an observable box that a body reading `value` depends on.
@MainActor @Observable public final class Facet<Value: Equatable> {
    /// The facet now. Written only by `set`, and only when it changed.
    public private(set) var value: Value

    public init(_ value: Value) { self.value = value }

    /// Publishes `new` when it differs from `value`; true when it did.
    @discardableResult public func set(_ new: Value) -> Bool {
        guard new != value else { return false }
        value = new
        return true
    }
}
