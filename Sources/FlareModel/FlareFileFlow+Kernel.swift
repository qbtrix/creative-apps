// FlareFileFlow+Kernel.swift: Flare's adapter onto the suite's file flow
// (file-flow FL-1 stubs, FL-3 bodies). FlareWorkspace is the
// SuiteDocumentHost the shell hands every hand-off to, and the FileFlowTarget
// the shared Open Recent, Clear Menu, Open In and drop commands run on.
// It accepts open and new hand-offs, refuses an SVG place with "Flare can't
// import SVG yet." until SVG import (E11), offers the readers the suite's
// routing names for Open In, leaves what only the window can do as
// `FlareFileRequest`s. Open Recent and Clear Menu read the suite's list as
// the window last gave it (`updateFileFlow`); Flare keeps no list of its
// own and never stored one, so there is nothing to import. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteKernel
import SuiteModel

/// What a file-flow command asks the window to do.
public enum FlareFileRequest: Hashable, Sendable {
    /// Open the file in a window; hand it to another app; drop a missing file from the shared recents; empty them.
    case open(path: String), handOff(path: String, app: String), forget(fileID: String), clearRecent
}

/// The file flow's state on the workspace: the window's view of the shared recents and what it still has to do.
public struct FlareFileFlowState: Sendable {
    /// Flare's recent files, newest first, as the window last read them.
    public internal(set) var recents: [RecentFileEntry] = []
    /// The window's requests (oldest first), and who reads each type.
    var requests: [FlareFileRequest] = [], registry = SuiteTypeRegistry.standard
    public init() {}
}

extension FlareWorkspace: SuiteDocumentHost {
    /// Why Flare refuses a hand-off other than open and new.
    static let handOffRefusal = SuiteError.notAvailable("Flare only opens and creates animations.")

    public func refusal(for handOff: HandOff) async -> SuiteError? {
        if [.open, .new].contains(handOff.verb) { return nil }
        let svg = handOff.documents.contains { $0.type == .svg || $0.path.lowercased().hasSuffix(".svg") }
        return handOff.verb == .place && svg ? .notAvailable(Self.svgRefusal) : Self.handOffRefusal
    }

    public func accept(_ handOff: HandOff) async throws(SuiteError) -> HandOffState {
        if let refusal = await refusal(for: handOff) { throw refusal }
        return .accepted
    }
}

extension FlareWorkspace: FileFlowTarget {
    /// What a placed SVG reads until SVG import (E11) lands.
    public static let svgRefusal = "Flare can't import SVG yet."

    public var appID: String { SuiteApp.flare.rawValue }
    public var recentFiles: [RecentFileEntry] { fileFlow.recents }
    public var hasDocument: Bool { document != nil }
    /// Nothing is placed into an open animation until SVG import (E11).
    public var placesExtensions: Set<String> { [] }

    /// The other apps that read a .flare, from the suite's routing.
    public var openInApps: [String] {
        guard document != nil else { return [] }
        return FakeRouting(registry: fileFlow.registry).openInTargets(for: .flareAnimation, from: .flare).map(\.rawValue)
    }

    public var openInHelp: String? {
        guard document != nil else { return "Open an animation first." }
        if let refusal = FakeRouting(registry: fileFlow.registry).openInRefusal(for: .flareAnimation, from: .flare) {
            return refusal.message
        }
        return suiteDocument == nil ? "Save \(title) first." : nil
    }

    /// The type's owner, then its readers, without repeats.
    public func readers(ofExtension ext: String) -> [String] {
        let type = fileFlow.registry.type(forExtension: ext)
        let apps = ([type?.owner].compactMap { $0 } + (type?.readers ?? [])).map(\.rawValue)
        return apps.enumerated().filter { !apps.prefix($0.offset).contains($0.element) }.map(\.element)
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
            throw CatalogError.failed(id: "file.open-in", message: openInHelp ?? "\(app) doesn't open this animation.")
        }
        fileFlow.requests.append(.handOff(path: path, app: app))
    }

    /// Opens and hand-offs become requests for the window; a refusal changes nothing (the drop's result says why).
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
    public mutating func takeFileRequests() -> [FlareFileRequest] {
        defer { fileFlow.requests = [] }
        return fileFlow.requests
    }

    /// The window's latest read of Flare's shared recents (newest first), and who reads each type.
    public mutating func updateFileFlow(recents: [RecentFileEntry], registry: SuiteTypeRegistry = .standard) {
        fileFlow.recents = recents
        fileFlow.registry = registry
    }

    /// Flare's suite ref for the .flare at `path`; nil for any other file.
    public static func suiteRef(_ path: String) -> SuiteDocumentRef? {
        let name = path.split(separator: "/").last.map(String.init) ?? path
        guard name.lowercased().hasSuffix(".flare") else { return nil }
        return SuiteDocumentRef(path: path, fileID: SuiteDocumentRef.fileID(forPath: path), app: .flare,
                                type: .flareAnimation, displayName: name)
    }
}
