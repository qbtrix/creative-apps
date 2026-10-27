// DesignFileFlow+Kernel.swift (file-flow DF-1 stubs, DF-3 bodies): Design's document as a
// SuiteDocumentHost (UC-18) and as SuiteKernel's file-flow target (Open Recent, Open In, drop), the
// shapes DesignFileFlowTests specify for DF-3. The stubs answer like FakeDocumentHost(app: .design,
// verbs: [.open]) and hold no recents; every mutating member does nothing until DF-3. The app's live
// hand-off host is DesignDocumentHost, not this conformance. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteKernel
import SuiteModel

extension DesignDocument: SuiteDocumentHost {
    /// nil for an open; any other verb is refused, as the fake host refuses it (DF-3: open, new; place refused).
    public func refusal(for handOff: HandOff) -> SuiteError? {
        handOff.verb == .open ? nil : .notAvailable("\(SuiteApp.design.displayName) can't do that yet.")
    }

    /// Accepts what `refusal(for:)` allows, as the fake host does; the document is not changed (DF-3 acts).
    public func accept(_ handOff: HandOff) throws(SuiteError) -> HandOffState {
        if let refused = refusal(for: handOff) { throw refused }
        return .returned
    }
}

extension DesignDocument: FileFlowTarget {
    /// The suite's id for Design.
    public var appID: String { SuiteApp.design.rawValue }
    /// None yet: DF-3 reads Design's files from the suite list.
    public var recentFiles: [RecentFileEntry] { [] }
    /// A document with a page to place into.
    public var hasDocument: Bool { !pages.isEmpty }
    /// Design places no files until S20.
    public var placesExtensions: Set<String> { [] }
    /// No other app reads a Design document.
    public var openInApps: [String] { [] }
    /// Why Open In is off.
    public var openInHelp: String? { "No other app opens Design Document files." }
    /// None yet: DF-3 asks the suite's routing.
    public func readers(ofExtension ext: String) -> [String] { [] }
    /// Does nothing until DF-3.
    public mutating func openRecent(_ fileID: String) throws {}
    /// Does nothing until DF-3.
    public mutating func clearRecent() throws {}
    /// Does nothing until DF-3.
    public mutating func openIn(_ app: String) throws {}
    /// Does nothing until DF-3.
    public mutating func perform(_ actions: [DropAction]) throws {}
}
