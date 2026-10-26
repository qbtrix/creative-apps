// HaloFileFlow+Kernel.swift: Halo's adapter onto the suite's file flow
// (file-flow HF-1 stubs, HF-3 bodies). HaloProject is the FileFlowTarget the
// shared Open Recent, Clear Menu, Open In and drop commands run on. The
// SuiteDocumentHost the shell hands every hand-off to stays HaloDocumentHost
// (A-HA-1, #865): HaloProject is a value the window owns, so the host hands
// its command to the window instead of a second conformance here.
// A file dropped on the window places nothing (the canvas places an image
// through placed-images' PH-3, so one dropped off it goes to the app that
// reads it), offers the readers the suite's routing
// names for Open In once the project is saved, leaves what only the window
// can do as `HaloFileRequest`s, and hands its old Open Recent list to the
// suite's once. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteKernel
import SuiteModel

/// What a file-flow command asks the window to do.
public enum HaloFileRequest: Hashable, Sendable {
    /// Open the file in a window; hand it to another app; drop a missing file from the shared recents; empty them.
    case open(path: String), handOff(path: String, app: String), forget(fileID: String), clearRecent
}

/// The file flow's state on the project: the window's view of the shared recents and what it still has to do.
public struct HaloFileFlowState: Sendable, Equatable {
    /// Halo's recent files, newest first, as the window last read them.
    public internal(set) var recents: [RecentFileEntry] = []
    /// The window's requests, oldest first.
    var requests: [HaloFileRequest] = []
    public init() {}
}

extension HaloProject: FileFlowTarget {
    public var appID: String { SuiteApp.halo.rawValue }
    public var recentFiles: [RecentFileEntry] { fileFlow.recents }
    /// A composition to take content; the drop rule reads it.
    public var hasDocument: Bool { selectedComposition != nil }
    /// None: the canvas places an image (PH-3), so a file dropped off it goes to its reader.
    public var placesExtensions: Set<String> { [] }

    /// The other apps that read a .halo, from the suite's routing.
    public var openInApps: [String] {
        guard hasDocument else { return [] }
        return FakeRouting(registry: .standard).openInTargets(for: .haloProject, from: .halo).map(\.rawValue)
    }

    public var openInHelp: String? {
        guard hasDocument else { return "Create a composition first." }
        if let refusal = FakeRouting(registry: .standard).openInRefusal(for: .haloProject, from: .halo) {
            return refusal.message
        }
        return suiteDocument == nil ? "Save \(windowTitle) first." : nil
    }

    /// The type's owner, then its readers, without repeats.
    public func readers(ofExtension ext: String) -> [String] {
        guard let type = SuiteTypeRegistry.standard.type(forExtension: ext) else { return [] }
        var apps: [String] = []
        for app in [type.owner].compactMap({ $0 }) + type.readers where !apps.contains(app.rawValue) { apps.append(app.rawValue) }
        return apps
    }

    public mutating func openRecent(_ fileID: String) throws {
        guard let entry = fileFlow.recents.first(where: { $0.fileID == fileID }) else {
            throw CatalogError.failed(id: "file.open-recent", message: "\(fileID) is not in Recent Files.")
        }
        guard FileManager.default.fileExists(atPath: entry.path) else {
            fileFlow.recents.removeAll { $0.fileID == fileID }
            fileFlow.requests.append(.forget(fileID: fileID))
            throw CatalogError.failed(id: "file.open-recent", message: "\(entry.name) is no longer at \(entry.path).")
        }
        fileFlow.requests.append(.open(path: entry.path))
    }

    public mutating func clearRecent() throws {
        fileFlow.recents = []
        fileFlow.requests.append(.clearRecent)
    }

    public mutating func openIn(_ app: String) throws {
        guard let path = suiteDocument?.path, openInApps.contains(app) else {
            throw CatalogError.failed(id: "file.open-in", message: openInHelp ?? "\(app) doesn't open this project.")
        }
        fileFlow.requests.append(.handOff(path: path, app: app))
    }

    /// Opens and hand-offs become requests for the window; nothing touches the document or its undo.
    public mutating func perform(_ actions: [DropAction]) throws {
        for action in actions {
            switch action {
            case .open(let path): fileFlow.requests.append(.open(path: path))
            case .handOff(let path, let app): fileFlow.requests.append(.handOff(path: path, app: app))
            case .place, .refuse: continue
            }
        }
    }

    /// What the file-flow commands left for the window, oldest first; empties the list.
    public mutating func takeFileRequests() -> [HaloFileRequest] {
        defer { fileFlow.requests = [] }
        return fileFlow.requests
    }

    /// The window's latest read of Halo's shared recents, newest first.
    public mutating func updateFileFlow(recents: [RecentFileEntry]) {
        fileFlow.recents = recents
    }

    /// The saved project as the suite names it; nil before it has a path on disk.
    public var suiteDocument: SuiteDocumentRef? {
        guard let path = file.path else { return nil }
        return Self.suiteRef(path: path, name: file.name)
    }

    /// Halo's old Open Recent list (newest first) as suite refs, oldest first so noting them in order keeps the
    /// newest on top; empties `stored`, so a second call imports nothing.
    public static func takeOldRecents(_ stored: inout [HaloFileRef]?) -> [SuiteDocumentRef] {
        guard let old = stored else { return [] }
        stored = nil
        return old.reversed().map { suiteRef(path: $0.path, name: $0.name) }
    }

    /// The .halo at `path` as the suite names it, shown as `name` (else its last path component).
    static func suiteRef(path: String, name: String?) -> SuiteDocumentRef {
        let shown = name ?? path.split(separator: "/").last.map(String.init) ?? path
        return SuiteDocumentRef(path: path, fileID: SuiteDocumentRef.fileID(forPath: path), app: .halo,
                                type: .haloProject, displayName: shown)
    }
}
