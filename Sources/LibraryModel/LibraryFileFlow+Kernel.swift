// LibraryFileFlow+Kernel.swift: Library's file-flow adapter (file-flow LF-1
// stubs, LF-3 bodies). The catalog is a `SuiteDocumentHost` (hand-offs from
// other apps) and a `FileFlowTarget` (Open In and drops). Library is one
// catalog, always open, so it has no recent files of its own; a drop places
// the photos it imports (the existing import, one step) and hands other apps'
// documents to them. LF-1: routing and the extensions are real, every action
// refuses with `fileFlowUnavailable` until LF-3. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteKernel
import SuiteModel

extension LibraryCatalog {
    /// Why the file-flow actions are off until LF-3 gives them bodies.
    public static let fileFlowUnavailable = "Library can't take dropped files yet (file-flow)."
}

extension LibraryCatalog: SuiteDocumentHost {
    /// LF-1: every hand-off is refused with `fileFlowUnavailable`.
    public func refusal(for handOff: HandOff) async -> SuiteError? {
        .notAvailable(Self.fileFlowUnavailable)
    }

    /// LF-3: `.place` and `.open` of images import them as one step and select them.
    public func accept(_ handOff: HandOff) async throws(SuiteError) -> HandOffState {
        throw .notAvailable(Self.fileFlowUnavailable)
    }
}

extension LibraryCatalog: FileFlowTarget {
    public var appID: String { SuiteApp.library.rawValue }
    /// Library is one catalog: no recent list of its own.
    public var recentFiles: [RecentFileEntry] { [] }
    /// The catalog is always open, so a drop always has somewhere to go.
    public var hasDocument: Bool { true }
    /// What the import reads (`PhotoFileKind`); a dropped folder is expanded by the import.
    public var placesExtensions: Set<String> { ["jpg", "jpeg", "png", "heic", "heif"] }
    /// The loupe photo's other readers. LF-1: none yet.
    public var openInApps: [String] { [] }
    public var openInHelp: String? { Self.fileFlowUnavailable }

    public func readers(ofExtension ext: String) -> [String] {
        SuiteTypeRegistry.standard.type(forExtension: ext)?.readers.map(\.rawValue) ?? []
    }

    public mutating func openRecent(_ fileID: String) throws {
        throw LibraryError.invalid("Library has no recent files.")
    }

    public mutating func clearRecent() throws {}

    public mutating func openIn(_ app: String) throws {
        throw LibraryError.invalid(Self.fileFlowUnavailable)
    }

    /// LF-3: the `.place` paths import as one step and are selected; each `.handOff` goes to its app.
    public mutating func perform(_ actions: [DropAction]) throws {
        throw LibraryError.invalid(Self.fileFlowUnavailable)
    }
}
