// Live/LiveProjectHistory.swift (HF-1, #208): the live undo history. 100
// whole-document steps, a scrub coalesced into one step until it ends, and
// redo cleared by every record, on the kernel's History (AU-h1, #2747)
// through the HaloHistory adapter in HaloHistory+Kernel.swift. Linux-safe.
// ponytail: whole-document snapshots (#208, D2); commands replace them once
// creative-core has a Halo document engine (blueprint 8.4).

public struct LiveProjectHistory: ProjectHistory {
    public let limit = HaloHistory.limit
    public init() {}
    public var unavailableHelp: String? { nil }
    public func record(_ name: String, before: HaloDocumentState, coalesceKey: String?, in history: inout HaloHistory) {
        history.record(name, before: before, coalesceKey: coalesceKey)
    }
    public func endCoalescing(in history: inout HaloHistory) { history.endRun() }
    public func undo(_ current: HaloDocumentState, in history: inout HaloHistory) -> HaloDocumentState? {
        history.step(current, back: true)
    }
    public func redo(_ current: HaloDocumentState, in history: inout HaloHistory) -> HaloDocumentState? {
        history.step(current, back: false)
    }
}
