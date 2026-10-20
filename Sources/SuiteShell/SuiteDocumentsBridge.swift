// SuiteDocumentsBridge.swift (file-flow SF-2 over the services' recents, SF-7 live): the one place a suite
// process records every open and save in the shared recents list, reads one app's recent files, hands a
// document to another app and answers which apps read an extension. It keeps the list it last read and
// refreshes it after each note and on `refresh()`, so a menu reads it without waiting.
import Foundation
import Observation
import SuiteKernel
import SuiteModel

@Observable @MainActor public final class SuiteDocumentsBridge {
    /// The process this bridge records for.
    public let app: SuiteApp
    /// The type registry the drop rule and Open In read.
    public nonisolated let registry: SuiteTypeRegistry
    /// The shared recents list as last read, newest first.
    public private(set) var items: [RecentItem] = []
    @ObservationIgnored private let services: SuiteServices
    @ObservationIgnored private let now: @Sendable () -> Date

    public init(app: SuiteApp, services: SuiteServices, registry: SuiteTypeRegistry = .standard,
                now: @escaping @Sendable () -> Date = { Date() }) {
        self.app = app; self.services = services; self.registry = registry; self.now = now
    }

    /// Reads the shared list again; a failed read keeps the last one.
    public func refresh() async {
        if let list = try? await services.recents.list() { items = list.items }
    }

    /// Records an open or a save, then reads the list again.
    public func noted(_ ref: SuiteDocumentRef, _ event: RecentEvent) {
        let recents = services.recents, at = now()
        Task {
            try? await recents.note(ref, event: event, at: at, thumbnail: nil)
            await refresh()
        }
    }

    /// One app's recent files, newest first; the launcher's are every app's.
    public func recents(for app: SuiteApp) -> [RecentFileEntry] {
        items.filter { app == .launcher || $0.ref.app == app }.map {
            RecentFileEntry(fileID: $0.ref.fileID, name: $0.ref.displayName, path: $0.ref.path,
                            app: $0.ref.app.rawValue, lastUsed: $0.lastUsed)
        }
    }

    /// Empties one app's part of the list (the launcher's empties nothing else's).
    public func clear(app: SuiteApp) async {
        try? await services.recents.clear(app: app)
        await refresh()
    }

    /// Opens a recent file in the app that last used it.
    public func reopen(_ fileID: String) async throws(SuiteError) {
        guard let item = items.first(where: { $0.ref.fileID == fileID }) else { return }
        try await openIn(item.ref, app: item.ref.app)
    }

    /// Hands a document to `app` with the verb open.
    public func openIn(_ ref: SuiteDocumentRef, app: SuiteApp) async throws(SuiteError) {
        let handOff = HandOff(id: HandOff.newID(), from: self.app, to: app, verb: .open, documents: [ref], createdAt: now())
        _ = try await services.sending.send(handOff)
    }

    /// Hands each opened or handed-off file of a drop to the app that reads it. Places and refusals are
    /// the app's own (SF-8 performs the rest through its document host).
    public func handOff(_ actions: [DropAction]) async {
        for action in actions {
            let target: String?
            switch action {
            case .handOff(_, let to): target = to
            case .open: target = app == .launcher ? readers(ofExtension: Self.ext(action.path)).first : nil
            case .place, .refuse: target = nil
            }
            guard let target, let to = SuiteApp(rawValue: target), let ref = ref(action.path, app: to) else { continue }
            try? await openIn(ref, app: to)
        }
    }

    /// The apps that read an extension, the owner first.
    public func readers(ofExtension ext: String) -> [String] { Self.readers(in: registry, ofExtension: ext) }

    /// The readers rule without the bridge, for a drop worked out off the main actor.
    public nonisolated static func readers(in registry: SuiteTypeRegistry, ofExtension ext: String) -> [String] {
        guard let type = registry.type(forExtension: ext) else { return [] }
        var apps: [String] = []
        for app in [type.owner].compactMap({ $0 }) + type.readers where !apps.contains(app.rawValue) { apps.append(app.rawValue) }
        return apps
    }

    private func ref(_ path: String, app: SuiteApp) -> SuiteDocumentRef? {
        guard let type = registry.type(forExtension: Self.ext(path)) else { return nil }
        return SuiteDocumentRef(path: path, fileID: SuiteDocumentRef.fileID(forPath: path), app: app, type: type.id,
                                displayName: URL(fileURLWithPath: path).lastPathComponent)
    }

    private static func ext(_ path: String) -> String { URL(fileURLWithPath: path).pathExtension.lowercased() }
}
