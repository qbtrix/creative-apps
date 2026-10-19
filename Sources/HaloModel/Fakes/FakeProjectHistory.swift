// Fakes/FakeProjectHistory.swift: a small, predictable ProjectHistory (#208):
// 100 whole-document steps, a scrub coalesced into one step until it ends,
// and redo cleared by every record. A thin wrapper over the HaloHistory
// adapter in HaloHistory+Kernel.swift, the kernel History the live type runs
// on too (AU-h1, #2747). Linux-safe; never used by `.live`.

public struct FakeProjectHistory: ProjectHistory {
    public let limit = HaloHistory.limit
    public init() {}
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
