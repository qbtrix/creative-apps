// LibraryFileFlow+Kernel.swift: Library's file-flow adapter (file-flow LF-1
// stubs, LF-3 bodies). The catalog is a `SuiteDocumentHost` (hand-offs from
// other apps) and a `FileFlowTarget` (Open In and drops). Library is one
// catalog, always open, so it has no recent files of its own. It accepts
// open and place hand-offs; a drop imports the photos it places as one
// "Import" step and selects them, and hands other apps' documents to them
// as `LibraryFileRequest`s the window runs. Open In hands the loupe's photo
// to another app that reads it. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteKernel
import SuiteModel

/// What a file-flow command asks the window to do.
public enum LibraryFileRequest: Hashable, Sendable {
    /// Open the file in a window; hand it to another app; show why a dropped file was refused.
    case open(path: String), handOff(path: String, app: String), refused(path: String, reason: String)
}

extension LibraryCatalog {
    /// Why Open In is off: it hands over the loupe's photo.
    public static let openInNeedsLoupe = "Open a photo in the loupe first."

    /// The loupe's photo, when it has a file on disk.
    var loupePhoto: PhotoItem? {
        guard mode == .loupe, let id = focusedItemID else { return nil }
        return items.first { $0.id == id && $0.path != nil }
    }

    /// Imports the image files at `paths` the catalog doesn't hold yet as one
    /// "Import" step, then selects them; a path that isn't a file is skipped.
    mutating func importDropped(_ paths: [String]) {
        let known = Set(items.map(\.id))
        var seen = Set<String>()
        let fresh = paths.filter { !known.contains($0) && seen.insert($0).inserted && FileManager.default.fileExists(atPath: $0) }
            .map { path in
                let date = (try? FileManager.default.attributesOfItem(atPath: path))?[.modificationDate] as? Date
                return PhotoItem(id: path, name: LiveImporter.fileStem(path), captureDate: date ?? Date(timeIntervalSince1970: 0),
                                 color: LiveImporter.neutralGrey, path: path)
            }
        guard !fresh.isEmpty else { return }
        appendImported(fresh)
        history.kernel.record("Import", CatalogChange(photos: [], removing: fresh))
        history.open = false
        select(Set(fresh.map(\.id)))
    }

    /// What the file-flow commands left for the window, oldest first; empties the list.
    public mutating func takeFileRequests() -> [LibraryFileRequest] {
        defer { fileRequests = [] }
        return fileRequests
    }
}

extension LibraryCatalog: SuiteDocumentHost {
    /// Why Library refuses a hand-off verb other than open and place.
    static let handOffRefusal = SuiteError.notAvailable("Library only imports photos.")

    public func refusal(for handOff: HandOff) async -> SuiteError? {
        [.open, .place].contains(handOff.verb) ? nil : Self.handOffRefusal
    }

    public func accept(_ handOff: HandOff) async throws(SuiteError) -> HandOffState {
        if let refusal = await refusal(for: handOff) { throw refusal }
        return .accepted
    }
}

extension LibraryCatalog: FileFlowTarget {
    public var appID: String { SuiteApp.library.rawValue }
    /// Library is one catalog: no recent list of its own.
    public var recentFiles: [RecentFileEntry] { [] }
    /// The catalog is always open, so a drop always has somewhere to go.
    public var hasDocument: Bool { true }
    /// What the import reads (`PhotoFileKind`); a dropped folder is expanded by the drop plan.
    public var placesExtensions: Set<String> { ["jpg", "jpeg", "png", "heic", "heif"] }

    /// The loupe photo's other readers.
    public var openInApps: [String] {
        loupeExtension.map { readers(ofExtension: $0).filter { $0 != appID } } ?? []
    }

    public var openInHelp: String? {
        guard let ext = loupeExtension else { return Self.openInNeedsLoupe }
        let type = SuiteTypeRegistry.standard.type(forExtension: ext)?.name ?? "these"
        return openInApps.isEmpty ? SuiteError.noOtherReader(typeName: type).message : nil
    }

    /// The loupe photo's extension; nil without a loupe photo on disk.
    var loupeExtension: String? {
        guard let path = loupePhoto?.path else { return nil }
        let name = LiveImporter.lastComponent(path)
        guard let dot = name.lastIndex(of: "."), dot != name.startIndex else { return "" }
        return String(name[name.index(after: dot)...]).lowercased()
    }

    public func readers(ofExtension ext: String) -> [String] {
        SuiteTypeRegistry.standard.type(forExtension: ext)?.readers.map(\.rawValue) ?? []
    }

    public mutating func openRecent(_ fileID: String) throws {
        throw LibraryError.invalid("Library has no recent files.")
    }

    public mutating func clearRecent() throws {}

    public mutating func openIn(_ app: String) throws {
        guard let path = loupePhoto?.path, openInApps.contains(app) else {
            throw LibraryError.invalid(openInHelp ?? "\(app) doesn't open this photo.")
        }
        fileRequests.append(.handOff(path: path, app: app))
    }

    /// The `.place` paths import as one step and are selected; each `.handOff` goes to its app.
    public mutating func perform(_ actions: [DropAction]) throws {
        importDropped(actions.compactMap { if case .place(let path) = $0 { path } else { nil } })
        for action in actions {
            switch action {
            case .open(let path): fileRequests.append(.open(path: path))
            case .handOff(let path, let app): fileRequests.append(.handOff(path: path, app: app))
            case .refuse(let path, let reason): fileRequests.append(.refused(path: path, reason: reason))
            case .place: continue
            }
        }
    }
}
