// History.swift: the one undo history every app keeps: named steps, a run
// under one key folded into one step, ids that never repeat, dirty read
// exactly as saved-vs-current, a limit that rolls old steps into the base.
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
    /// One recorded step: its name, the payload that undoes (or, on the redo
    /// stack, redoes) it, and the step ids before and after it.
    public struct Step: Sendable {
        public internal(set) var name: String
        public internal(set) var payload: Payload
        public internal(set) var idBefore: Int
        public internal(set) var idAfter: Int
    }

    /// The most steps kept; older ones roll into the base and can't be undone.
    private let limit: Int
    /// Applied steps, oldest first.
    private var done: [Step] = []
    /// Undone steps, the next one to redo last.
    private var undone: [Step] = []
    /// The key of the run the last `record` opened; nil when no run is open.
    private var openKey: String?
    /// The last id handed out. It never rewinds, so ids never repeat.
    private var lastIssuedID = 0
    /// The id of the step the document is at now. Ids never repeat.
    public private(set) var currentStepID: Int = 0
    /// The id of the step last saved; the document is clean when it equals `currentStepID`.
    public var savedStepID: Int = 0

    /// An empty history that keeps at most `limit` steps (0 or more).
    public init(limit: Int = 100) {
        self.limit = max(0, limit)
    }

    /// True when the current step is not the saved one.
    public var isDirty: Bool { currentStepID != savedStepID }
    /// True when there is a step to undo.
    public var canUndo: Bool { !done.isEmpty }
    /// True when there is an undone step to redo.
    public var canRedo: Bool { !undone.isEmpty }
    /// The name of the step undo would revert, nil when there is none.
    public var undoName: String? { done.last?.name }
    /// The name of the step redo would reapply, nil when there is none.
    public var redoName: String? { undone.last?.name }
    /// The steps undo can revert, oldest first (the next one to undo last).
    public var undoSteps: [Step] { done }
    /// The steps redo can reapply, the next one to redo last.
    public var redoSteps: [Step] { undone }
    /// Every step's name, oldest first, undone ones included.
    public var steps: [String] { done.map(\.name) + undone.reversed().map(\.name) }
    /// How many of `steps` are applied: the place `jump(to:)` moves.
    public var index: Int { done.count }

    /// Hands out the next id; the counter never rewinds.
    private mutating func nextID() -> Int {
        lastIssuedID += 1
        return lastIssuedID
    }

    /// Records a step named `name` whose `undo` payload reverts it. A `key`
    /// equal to the open run's key folds into that step instead of adding one;
    /// the folded step keeps the payload of the run's first edit.
    public mutating func record(_ name: String, _ undo: Payload, key: String? = nil) {
        if let key, key == openKey, !done.isEmpty {
            let folded = nextID()
            done[done.count - 1].idAfter = folded
            currentStepID = folded
            return
        }
        let before = currentStepID
        let after = nextID()
        done.append(Step(name: name, payload: undo, idBefore: before, idAfter: after))
        undone.removeAll()
        while done.count > limit { done.removeFirst() }
        openKey = key
        currentStepID = after
    }

    /// Ends the open run, so the next `record` with the same key adds a step.
    public mutating func endRun() {
        openKey = nil
    }

    /// Reverts the last step through `apply`, which returns the redo payload;
    /// false when there is nothing to undo. Ends the open run.
    public mutating func undo(_ apply: (Payload) -> Payload) -> Bool {
        openKey = nil
        guard var step = done.popLast() else { return false }
        step.payload = apply(step.payload)
        undone.append(step)
        currentStepID = step.idBefore
        return true
    }

    /// Reapplies the last undone step through `apply`, which returns the undo
    /// payload; false when there is none. Ends the open run.
    public mutating func redo(_ apply: (Payload) -> Payload) -> Bool {
        openKey = nil
        guard var step = undone.popLast() else { return false }
        step.payload = apply(step.payload)
        done.append(step)
        currentStepID = step.idAfter
        return true
    }

    /// Undoes or redoes until `index` steps are applied; an index past either
    /// end stops there.
    public mutating func jump(to index: Int, _ apply: (Payload) -> Payload) {
        let target = min(max(0, index), steps.count)
        while done.count > target, undo(apply) {}
        while done.count < target, redo(apply) {}
    }

    /// Marks the step the document is at now as the saved one.
    public mutating func markSaved() {
        savedStepID = currentStepID
    }
}

/// Two histories are equal when their steps, run, ids and limit are.
extension History: Equatable where Payload: Equatable {}
extension History.Step: Equatable where Payload: Equatable {}
extension History.Step: Hashable where Payload: Hashable {}

/// Hashes everything `==` compares, so an app's Hashable state can hold a history.
extension History: Hashable where Payload: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(limit)
        hasher.combine(done)
        hasher.combine(undone)
        hasher.combine(openKey)
        hasher.combine(lastIssuedID)
        hasher.combine(currentStepID)
        hasher.combine(savedStepID)
    }
}
