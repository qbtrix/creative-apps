// FlareFileFlow+Kernel.swift: Flare's adapter onto the suite's file flow
// (file-flow FL-1 stubs, FL-3 bodies). FlareWorkspace is the
// SuiteDocumentHost the shell hands every hand-off to, and the FileFlowTarget
// the shared Open Recent, Clear Menu, Open In and drop commands run on.
// Until FL-3 it names itself "flare", places nothing into an open document
// (SVG import is E11), has no suite recent files and no Open In readers,
// refuses every hand-off with the reason, and Open Recent, Open In and drop
// throw "not built". Clear Menu is FlareFiles' `clearRecent()` until FL-3
// moves the list to the suite's. Linux-safe.
import SuiteKernel
import SuiteModel

extension FlareWorkspace: SuiteDocumentHost {
    /// Why every hand-off is refused until FL-3 writes `accept`.
    static let handOffRefusal = SuiteError.notAvailable("Flare can't take files from other apps yet.")

    public func refusal(for handOff: HandOff) async -> SuiteError? { Self.handOffRefusal }

    public func accept(_ handOff: HandOff) async throws(SuiteError) -> HandOffState { throw Self.handOffRefusal }
}

extension FlareWorkspace: FileFlowTarget {
    /// What a dropped SVG reads until SVG import (E11) lands.
    public static let svgRefusal = "Flare can't import SVG yet."

    public var appID: String { SuiteApp.flare.rawValue }
    public var recentFiles: [RecentFileEntry] { [] }
    public var hasDocument: Bool { document != nil }
    public var placesExtensions: Set<String> { [] }
    public var openInApps: [String] { [] }
    public var openInHelp: String? { "Open In isn't built yet." }

    public func readers(ofExtension ext: String) -> [String] { [] }

    public mutating func openRecent(_ fileID: String) throws { throw Self.notBuilt("file.open-recent") }

    public mutating func openIn(_ app: String) throws { throw Self.notBuilt("file.open-in") }

    public mutating func perform(_ actions: [DropAction]) throws { throw Self.notBuilt("file.drop") }

    static func notBuilt(_ id: String) -> CatalogError { .notBuilt(id: id, feature: "file-flow") }
}
