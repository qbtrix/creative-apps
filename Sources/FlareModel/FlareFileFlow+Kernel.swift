// FlareFileFlow+Kernel.swift: Flare's adapter onto the suite's file flow
// (file-flow FL-1 stubs, FL-3 bodies). FlareWorkspace is the
// SuiteDocumentHost the shell hands every hand-off to, and the FileFlowTarget
// the shared Open Recent, Clear Menu, Open In and drop commands run on.
// It accepts open and new hand-offs, places a dropped SVG as layers through
// the same `place` as File > Place… (svg-place), points a placed-SVG
// hand-off from another app at the window (`svgRefusal`), offers the readers the suite's
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
    /// Why another app's SVG place hand-off is refused: the place reads the file in a Flare window.
    public static let svgRefusal = "Drop the SVG on a Flare window, or choose File > Place…."

    public var appID: String { SuiteApp.flare.rawValue }
    public var recentFiles: [RecentFileEntry] { fileFlow.recents }
    public var hasDocument: Bool { document != nil }
    /// A dropped SVG is placed into the open animation as layers (svg-place).
    public var placesExtensions: Set<String> { ["svg"] }

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

    /// Opens and hand-offs become requests for the window, the SVGs are placed (`place(paths:)`), and a refusal
    /// changes nothing (the drop's result says why).
    public mutating func perform(_ actions: [DropAction]) throws {
        var places: [String] = []
        for action in actions {
            switch action {
            case .open(let path): fileFlow.requests.append(.open(path: path))
            case .handOff(let path, let app): fileFlow.requests.append(.handOff(path: path, app: app))
            case .place(let path): places.append(path)
            case .refuse: continue
            }
        }
        if !places.isEmpty { place(paths: places) }
    }

    /// Places the files at `paths` as File > Place… does; one that can't be read stops the place and says so.
    public mutating func place(paths: [String]) {
        var files: [(name: String, data: Data)] = []
        for path in paths {
            let name = path.split(separator: "/").last.map(String.init) ?? path
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
                placeStatus = "Can't read \(name)."
                return
            }
            files.append((name, data))
        }
        place(files)
    }

    /// A drop's actions split: the files to place, and the rest, in order.
    public static func placeDrops(_ actions: [DropAction]) -> (places: [String], rest: [DropAction]) {
        var places: [String] = [], rest: [DropAction] = []
        for action in actions {
            if case .place(let path) = action { places.append(path) } else { rest.append(action) }
        }
        return (places, rest)
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
