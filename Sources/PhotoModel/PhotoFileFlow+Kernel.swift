// PhotoFileFlow+Kernel.swift: Photo's adapter onto the suite's file flow
// (file-flow PF-1 stubs, PF-3 bodies). PhotoWorkspace is the
// SuiteDocumentHost the shell hands every hand-off to, and the FileFlowTarget
// the shared Open Recent, Clear Menu, Open In and drop commands run on.
// Until PF-3 it names itself "photo", lists the extensions it places into an
// open document, has no recent files and no Open In readers, refuses every
// hand-off with the reason, and each command throws "not built".
// Linux-safe.
import SuiteKernel
import SuiteModel

extension PhotoWorkspace: SuiteDocumentHost {
    /// Why Photo can't take a hand-off yet: every verb waits on PF-3.
    static let handOffRefusal = SuiteError.notAvailable("Photo can't take files from other apps yet.")

    public func refusal(for handOff: HandOff) async -> SuiteError? { Self.handOffRefusal }

    public func accept(_ handOff: HandOff) async throws(SuiteError) -> HandOffState { throw Self.handOffRefusal }
}

extension PhotoWorkspace: FileFlowTarget {
    public var appID: String { SuiteApp.photo.rawValue }

    public var recentFiles: [RecentFileEntry] { [] }

    public var hasDocument: Bool { canvas != nil }

    /// The image types Photo takes into an open document as a layer.
    public var placesExtensions: Set<String> { ["png", "jpg", "jpeg", "heic", "tiff", "psd"] }

    public var openInApps: [String] { [] }

    public var openInHelp: String? { "Open In isn't built yet." }

    public func readers(ofExtension ext: String) -> [String] { [] }

    public mutating func openRecent(_ fileID: String) throws { throw Self.notBuilt("file.open-recent") }

    public mutating func clearRecent() throws { throw Self.notBuilt("file.clear-recent") }

    public mutating func openIn(_ app: String) throws { throw Self.notBuilt("file.open-in") }

    public mutating func perform(_ actions: [DropAction]) throws { throw Self.notBuilt("file.drop") }

    /// The stub's error for a file-flow command.
    static func notBuilt(_ id: String) -> CatalogError { .notBuilt(id: id, feature: "file-flow") }
}
