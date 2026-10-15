// Live/LiveProjectHistory.swift (HF-1, #208): the live undo history. 100
// whole-document steps, a scrub coalesced into one step until it ends, and
// redo cleared by every record, all through HaloHistoryRules. Linux-safe.
// ponytail: whole-document snapshots (#208, D2); commands replace them once
// creative-core has a Halo document engine (blueprint 8.4).

public struct LiveProjectHistory: ProjectHistory {
    public let limit = 100
    public init() {}
    public var unavailableHelp: String? { nil }
    public func record(_ name: String, before: HaloDocumentState, coalesceKey: String?, in history: inout HaloHistory) {
        HaloHistoryRules.record(name, before: before, coalesceKey: coalesceKey, limit: limit, in: &history)
    }
    public func endCoalescing(in history: inout HaloHistory) {
        HaloHistoryRules.endCoalescing(in: &history)
    }
    public func undo(_ current: HaloDocumentState, in history: inout HaloHistory) -> HaloDocumentState? {
        HaloHistoryRules.step(current, from: &history.undo, to: &history.redo)
    }
    public func redo(_ current: HaloDocumentState, in history: inout HaloHistory) -> HaloDocumentState? {
        HaloHistoryRules.step(current, from: &history.redo, to: &history.undo)
    }
}
