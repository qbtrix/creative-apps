// Fakes/FakeProjectHistory.swift: a small, predictable ProjectHistory (#208):
// 100 whole-document steps, a scrub coalesced into one step until it ends,
// and redo cleared by every record. Linux-safe; never used by `.live`.

public struct FakeProjectHistory: ProjectHistory {
    public let limit = 100
    public init() {}
    public func record(_ name: String, before: HaloDocumentState, coalesceKey: String?, in history: inout HaloHistory) {
        history.redo = []
        if let coalesceKey, history.undo.last?.coalesceKey == coalesceKey { return }
        history.undo.append(HaloHistoryEntry(name: name, before: before, coalesceKey: coalesceKey))
        if history.undo.count > limit { history.undo.removeFirst() }
    }
    public func endCoalescing(in history: inout HaloHistory) {
        guard !history.undo.isEmpty else { return }
        history.undo[history.undo.count - 1].coalesceKey = nil
    }
    public func undo(_ current: HaloDocumentState, in history: inout HaloHistory) -> HaloDocumentState? {
        guard let step = history.undo.popLast() else { return nil }
        history.redo.append(HaloHistoryEntry(name: step.name, before: current))
        return step.before
    }
    public func redo(_ current: HaloDocumentState, in history: inout HaloHistory) -> HaloDocumentState? {
        guard let step = history.redo.popLast() else { return nil }
        history.undo.append(HaloHistoryEntry(name: step.name, before: current))
        return step.before
    }
}
