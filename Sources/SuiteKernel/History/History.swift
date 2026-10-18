// History.swift (EK-2 stub, EK-8 body): the one undo history every app keeps:
// named steps, a run under one key folded into one step, ids that never
// repeat, dirty read exactly. The stub answers like an empty history.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// What a menu, a toolbar or a title bar reads from a history: whether undo
/// and redo can run, their step names, and whether the document is dirty.
public protocol HistoryReading: Sendable {
    /// True when there is a step to undo.
    var canUndo: Bool { get }
    /// True when there is an undone step to redo.
    var canRedo: Bool { get }
    /// The name of the step undo would revert ("Move"), nil when there is none.
    var undoName: String? { get }
    /// The name of the step redo would reapply, nil when there is none.
    var redoName: String? { get }
    /// True when the current step is not the saved one.
    var isDirty: Bool { get }
}

/// An undo history of named steps, each holding the `Payload` that reverts it.
public struct History<Payload: Sendable>: Sendable, HistoryReading {
    /// The most steps kept; older ones roll into the base and can't be undone.
    private let limit: Int
    /// The id of the step the document is at now. Ids never repeat.
    public private(set) var currentStepID: Int = 0
    /// The id of the step last saved; the document is clean when it equals `currentStepID`.
    public var savedStepID: Int = 0
    /// An empty history that keeps at most `limit` steps.
    public init(limit: Int = 100) {
        self.limit = limit
    }
    /// True when the current step is not the saved one.
    public var isDirty: Bool { currentStepID != savedStepID }
    /// True when there is a step to undo. Stub: an empty history has none.
    public var canUndo: Bool { false }
    /// True when there is an undone step to redo. Stub: none.
    public var canRedo: Bool { false }
    /// The name of the step undo would revert. Stub: nil.
    public var undoName: String? { nil }
    /// The name of the step redo would reapply. Stub: nil.
    public var redoName: String? { nil }
    /// Every step's name, oldest first, undone ones included. Stub: none.
    public var steps: [String] { [] }
    /// How many of `steps` are applied: the place `jump(to:)` moves. Stub: 0.
    public var index: Int { 0 }
    /// Records a step named `name` whose `undo` payload reverts it. A `key`
    /// equal to the open run's key folds into that step instead of adding one.
    /// Stub: records nothing.
    public mutating func record(_ name: String, _ undo: Payload, key: String? = nil) {}
    /// Ends the open run, so the next `record` with the same key adds a step. Stub: nothing.
    public mutating func endRun() {}
    /// Reverts the last step through `apply`, which returns the redo payload;
    /// false when there is nothing to undo. Stub: false.
    public mutating func undo(_ apply: (Payload) -> Payload) -> Bool { false }
    /// Reapplies the last undone step through `apply`; false when there is none. Stub: false.
    public mutating func redo(_ apply: (Payload) -> Payload) -> Bool { false }
    /// Undoes or redoes until `index` steps are applied. Stub: nothing.
    public mutating func jump(to index: Int, _ apply: (Payload) -> Payload) {}
}
