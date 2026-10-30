// HaloHistory+Kernel.swift (AU-h1, #2747): Halo's undo history on the editor
// kernel's `History<HaloDocumentState>`, which keeps the steps, the open run,
// the 100-step limit, the step ids and the saved mark. Each step's payload is
// the whole document to go back to (or, on the redo stack, forward to). The
// adapter keeps only what the kernel doesn't show: the open run's key, so the
// newest undo entry reads its `coalesceKey`. `undo` and `redo` are the kernel's
// stacks projected as `HaloHistoryEntry` arrays, newest last, as before; the
// live and fake `ProjectHistory` both go through `record`, `endRun` and `step`
// here, so `record` stamps each agent step's time for the AI tab
// (`agentDates`, HaloAgentActivity+Kernel.swift). Linux-safe.
import SuiteKernel

/// Undo and redo stacks, newest last, read from the kernel history. Only a
/// `ProjectHistory` changes them.
public struct HaloHistory: Sendable, Hashable {
    /// How many steps undo keeps; the oldest drops past it.
    public static let limit = 100
    /// The steps, the open run, the limit, the step ids and the saved mark.
    var kernel = History<HaloDocumentState>(limit: HaloHistory.limit)
    /// The open run's key, as the kernel keeps it; nil once the run ends.
    var runKey: String?
    /// When each agent step was recorded (the AI tab's time; the kernel keeps no date).
    var agentDates = AgentStepDates()

    public init(undo: [HaloHistoryEntry] = [], redo: [HaloHistoryEntry] = []) {
        rebuild(undo: undo, redo: redo)
    }

    /// The steps undo reverts, the next one last; only the newest carries the
    /// open run's key.
    public var undo: [HaloHistoryEntry] {
        get {
            let steps = kernel.undoSteps
            return steps.indices.map { i in
                HaloHistoryEntry(
                    name: steps[i].name, before: steps[i].payload, coalesceKey: i == steps.count - 1 ? runKey : nil)
            }
        }
        set { rebuild(undo: newValue, redo: redo) }
    }

    /// The steps redo reapplies, the next one last; each holds the document
    /// redo goes forward to.
    public var redo: [HaloHistoryEntry] {
        get { kernel.redoSteps.map { HaloHistoryEntry(name: $0.name, before: $0.payload) } }
        set { rebuild(undo: undo, redo: newValue) }
    }

    /// "Undo New Layer"; nil when there is nothing to undo.
    public var undoTitle: String? { kernel.undoName.map { "Undo \($0)" } }
    /// "Redo New Layer"; nil when there is nothing to redo.
    public var redoTitle: String? { kernel.redoName.map { "Redo \($0)" } }
    /// True when the document is not at the step last saved or opened.
    public var isDirty: Bool { kernel.isDirty }

    /// Adds a step whose undo returns `before`, clearing redo. A `coalesceKey`
    /// equal to the open run's folds into the newest step, which keeps its
    /// first `before`.
    mutating func record(_ name: String, before: HaloDocumentState, coalesceKey: String?) {
        kernel.record(name, before, key: coalesceKey)
        runKey = coalesceKey
        agentDates.stamp(kernel, limit: HaloHistory.limit)
    }

    /// Ends the open run, so the next record is its own step.
    mutating func endRun() {
        kernel.endRun()
        runKey = nil
    }

    /// Undoes (`back`) or redoes one step from `current`: the kernel keeps
    /// `current` for the way back and the state to go to is returned. Nil when
    /// there is no step. Ends the open run.
    mutating func step(_ current: HaloDocumentState, back: Bool) -> HaloDocumentState? {
        var target: HaloDocumentState?
        let moved =
            back
            ? kernel.undo { target = $0; return current }
            : kernel.redo { target = $0; return current }
        runKey = nil
        return moved ? target : nil
    }

    /// Marks the current step as the saved one.
    mutating func markSaved() {
        kernel.markSaved()
    }

    /// Replaces the kernel with one holding `undo` then `redo`: each undo entry
    /// recorded in order (only the newest under its key), then each redo entry
    /// recorded and undone back onto the redo stack, the next one to redo last.
    private mutating func rebuild(undo: [HaloHistoryEntry], redo: [HaloHistoryEntry]) {
        var fresh = History<HaloDocumentState>(limit: HaloHistory.limit)
        for (i, entry) in undo.enumerated() {
            fresh.record(entry.name, entry.before, key: i == undo.count - 1 ? entry.coalesceKey : nil)
        }
        runKey = redo.isEmpty ? undo.last?.coalesceKey : nil
        for entry in redo.reversed() { fresh.record(entry.name, entry.before) }
        for entry in redo { _ = fresh.undo { _ in entry.before } }
        kernel = fresh
    }
}
