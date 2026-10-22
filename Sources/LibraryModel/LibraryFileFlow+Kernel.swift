// LibraryFileFlow+Kernel.swift: Library's file-flow adapter (file-flow LF-1
// stubs, LF-3 bodies). The catalog is a `SuiteDocumentHost` (hand-offs from
// other apps) and a `FileFlowTarget` (Open In and drops). Library is one
// catalog, always open; its recent files are the photos opened in the loupe,
// which the window notes in the suite's shared recents (LF-4) and reads back
// through `updateFileFlow(recents:)`. It accepts
// open and place hand-offs; a drop imports the photos it places as one
// "Import" step and selects them, and hands other apps' documents to them
// as `LibraryFileRequest`s the window runs. Open In hands the loupe's photo
// to another app that reads it; the loupe drags it out as its file and a PNG. Linux-safe.
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

/// Library's part of the suite recents (LF-4): the list the window last read and the loupe open it last noted.
public struct LibraryFileFlowState: Hashable, Sendable {
    /// Library's entries of the suite's shared recents, newest first.
    public internal(set) var recents: [RecentFileEntry] = []
    /// The path of the loupe photo last noted; nil once the loupe closes, so a reopen is noted again.
    var notedLoupe: String?
    public init() {}
}

extension LibraryCatalog {
    /// A suite ref to the photo at `path` for the recents and a drag, when Library reads its extension.
    public static func suiteRef(_ path: String) -> SuiteDocumentRef? {
        let name = LiveImporter.lastComponent(path)
        guard let dot = name.lastIndex(of: "."), dot != name.startIndex,
              let type = SuiteTypeRegistry.standard.type(forExtension: String(name[name.index(after: dot)...]).lowercased()),
              type.readers.contains(.library) else { return nil }
        return SuiteDocumentRef(path: path, fileID: SuiteDocumentRef.fileID(forPath: path), app: .library,
                                type: type.id, displayName: name)
    }

    /// The loupe's photo as a suite ref; nil without one on disk.
    public var loupeSuiteRef: SuiteDocumentRef? { loupePhoto?.path.flatMap(Self.suiteRef) }

    /// The loupe photo to note as opened, once per open: nil when it was the last one noted or the loupe is
    /// closed (which forgets it, so the next open is noted again).
    public mutating func takeLoupeOpen() -> SuiteDocumentRef? {
        let ref = loupeSuiteRef
        guard ref?.path != fileFlow.notedLoupe else { return nil }
        fileFlow.notedLoupe = ref?.path
        return ref
    }

    /// The suite recents the window read; Library keeps its own entries.
    public mutating func updateFileFlow(recents: [RecentFileEntry]) {
        fileFlow.recents = recents.filter { $0.app == appID }
    }

    /// What dragging the loupe's photo out carries: its file first (the Finder and other apps take that), then
    /// `png` at `size` when the window made one. Nothing without a loupe photo.
    public func loupeDragItems(png: Data?, size: PixelSize?) -> [SuiteClipItem] {
        guard let ref = loupeSuiteRef else { return [] }
        guard let png, let size else { return [.files([ref])] }
        return [.files([ref]), .image(png: png, pixelWidth: size.width, pixelHeight: size.height)]
    }
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
    /// The photos opened in the loupe, from the suite's shared recents.
    public var recentFiles: [RecentFileEntry] { fileFlow.recents }
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

    /// Opens a recent photo in the loupe; one the catalog no longer shows is refused.
    public mutating func openRecent(_ fileID: String) throws {
        guard let entry = fileFlow.recents.first(where: { $0.fileID == fileID }) else {
            throw LibraryError.invalid("\(fileID) is not in Recent Files.")
        }
        if let photo = items.first(where: { $0.path == entry.path }) { open(photo.id) }
        guard mode == .loupe, loupePhoto?.path == entry.path else {
            throw LibraryError.invalid("\(entry.name) isn't shown in the catalog.")
        }
    }

    /// Empties the list here; the window clears the suite's part through the bridge.
    public mutating func clearRecent() throws { fileFlow.recents = [] }

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
