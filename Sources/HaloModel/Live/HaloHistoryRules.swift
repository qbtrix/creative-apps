// Live/HaloHistoryRules.swift (HF-1, #208): the one copy of the undo stack
// rules, called by LiveProjectHistory and FakeProjectHistory so the two can
// never disagree. Pure value code on HaloHistory; Linux-safe.

enum HaloHistoryRules {
    /// Adds a step whose undo returns `before`. Redo is always cleared, even
    /// when coalescing. A non-nil `coalesceKey` equal to the newest undo
    /// entry's keeps that entry (and its first `before`). Past `limit` the
    /// oldest step drops.
    static func record(_ name: String, before: HaloDocumentState, coalesceKey: String?,
                       limit: Int, in history: inout HaloHistory) {
        history.redo = []
        if let coalesceKey, history.undo.last?.coalesceKey == coalesceKey { return }
        history.undo.append(HaloHistoryEntry(name: name, before: before, coalesceKey: coalesceKey))
        let overflow = history.undo.count - max(limit, 0)
        if overflow > 0 { history.undo.removeFirst(overflow) }
    }

    /// Ends the newest step's coalescing, so the next record is its own step.
    static func endCoalescing(in history: inout HaloHistory) {
        guard let last = history.undo.indices.last else { return }
        history.undo[last].coalesceKey = nil
    }

    /// Pops the newest entry of `from`, pushes `current` under its name onto
    /// `to`, and returns the state to go to. Nil when `from` is empty.
    static func step(_ current: HaloDocumentState, from: inout [HaloHistoryEntry],
                     to: inout [HaloHistoryEntry]) -> HaloDocumentState? {
        guard let step = from.popLast() else { return nil }
        to.append(HaloHistoryEntry(name: step.name, before: current))
        return step.before
    }
}
