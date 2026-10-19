// Fakes/FakeProjectHistory.swift: a small, predictable ProjectHistory (#208):
// 100 whole-document steps, a scrub coalesced into one step until it ends,
// and redo cleared by every record. A thin wrapper over HaloHistoryRules, the
// kernel History the live type runs on too (AU-h1, #2747). Linux-safe; never
// used by `.live`.

public struct FakeProjectHistory: ProjectHistory {
    public let limit = HaloHistory.limit
    public init() {}
    public func record(_ name: String, before: HaloDocumentState, coalesceKey: String?, in history: inout HaloHistory) {
        HaloHistoryRules.record(name, before: before, coalesceKey: coalesceKey, in: &history)
    }
    public func endCoalescing(in history: inout HaloHistory) { HaloHistoryRules.endCoalescing(in: &history) }
    public func undo(_ current: HaloDocumentState, in history: inout HaloHistory) -> HaloDocumentState? {
        HaloHistoryRules.step(current, back: true, in: &history)
    }
    public func redo(_ current: HaloDocumentState, in history: inout HaloHistory) -> HaloDocumentState? {
        HaloHistoryRules.step(current, back: false, in: &history)
    }
}
