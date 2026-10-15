// Live/LiveProjectHistory.swift: the W0 stub of ProjectHistory. It keeps no
// steps (limit 0), so undo and redo have nothing to return; the history
// feature (#208) replaces this file whole with the live type. Linux-safe.

public struct LiveProjectHistory: ProjectHistory {
    public init() {}
    public var unavailableHelp: String? { "Undo arrives with #208." }
    public var limit: Int { 0 }
    public func record(_ name: String, before: HaloDocumentState, coalesceKey: String?, in history: inout HaloHistory) {}
    public func endCoalescing(in history: inout HaloHistory) {}
    public func undo(_ current: HaloDocumentState, in history: inout HaloHistory) -> HaloDocumentState? { nil }
    public func redo(_ current: HaloDocumentState, in history: inout HaloHistory) -> HaloDocumentState? { nil }
}
