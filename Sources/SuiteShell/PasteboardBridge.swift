// PasteboardBridge.swift (clipboard-interop CB-1 stub, CB-4c body): the one SuiteShell transport that writes
// SuitePasteboardCoding's items to the system pasteboard and reads what is offered there. It replaces the apps'
// own writers and their change-count polls: the count is read when the Edit menu opens or the window becomes
// key, never on a timer.
#if canImport(AppKit)
import AppKit
import SuiteModel

/// The system pasteboard as `TypedData`. Until CB-4c, writing does nothing and nothing is offered.
@MainActor public struct PasteboardBridge {
    let pasteboard: NSPasteboard

    public init(_ pasteboard: NSPasteboard = .general) { self.pasteboard = pasteboard }

    /// Writes `items` as one pasteboard item: one clearContents, one write.
    public func write(_ items: [TypedData]) {}

    /// What the pasteboard offers now, read lazily per type.
    public func offered() -> [TypedData] { [] }

    /// The pasteboard's change count, read on menu open and window key, never on a timer.
    public var changeCount: Int { pasteboard.changeCount }
}
#endif
