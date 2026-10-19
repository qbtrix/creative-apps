// Live/HaloHistoryRules.swift (HF-1, #208): the one place LiveProjectHistory
// and FakeProjectHistory reach the undo stack, so the two can never disagree.
// Since AU-h1 (#2747) the rules are the kernel History's, through the adapter
// in HaloHistory+Kernel.swift; AU-h2 removes this forwarding. Linux-safe.

enum HaloHistoryRules {
    /// Adds a step whose undo returns `before`, clearing redo; a `coalesceKey`
    /// equal to the open run's folds into the newest step. The kernel drops
    /// the oldest step past `HaloHistory.limit`.
    static func record(_ name: String, before: HaloDocumentState, coalesceKey: String?, in history: inout HaloHistory) {
        history.record(name, before: before, coalesceKey: coalesceKey)
    }

    /// Ends the open run, so the next record is its own step.
    static func endCoalescing(in history: inout HaloHistory) {
        history.endRun()
    }

    /// Undoes (`back`) or redoes one step from `current`; the state to go to,
    /// nil when there is no step.
    static func step(_ current: HaloDocumentState, back: Bool, in history: inout HaloHistory) -> HaloDocumentState? {
        history.step(current, back: back)
    }
}
