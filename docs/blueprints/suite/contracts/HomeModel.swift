// HomeModel.swift: the home window's view-model (SuiteModel, planned
// `Sources/SuiteModel/Home/HomeModel.swift`, owned by the home feature).
// The views in `Sources/AfterGlowApp/Home*.swift` read it and call its
// methods; they never assign its state (the app-state rule). The Assets
// page, Settings, onboarding and the update sheet get the same shape:
// `AssetsModel`, `SettingsModel`, `OnboardingModel`, `UpdateModel`, each in
// its feature's SuiteModel folder.
import Observation
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

@MainActor @Observable
public final class HomeModel {
    public private(set) var state = HomeState(tiles: [], cards: [], running: [], emptyMessage: nil)
    public private(set) var query = ""
    public private(set) var filter: SuiteApp?
    public private(set) var selection: String?          // a fileID
    public private(set) var message: SuiteError?        // shown in place, never an alert
    let services: SuiteServices
    var recents = RecentsList()
    var running: [SuiteApp] = []
    var order = SuiteApp.apps
    var missingApps: Set<SuiteApp> = []
    var missingFiles: Set<String> = []
    let fileExists: @Sendable (String) -> Bool

    /// `fileExists` is `FileManager.default.fileExists(atPath:)` in the app; tests pass a set.
    public init(services: SuiteServices, fileExists: @escaping @Sendable (String) -> Bool) {
        self.services = services; self.fileExists = fileExists
    }

    public func reload(now: Date) async {
        do { recents = try await services.recents.list() } catch { message = error }
        var r: [SuiteApp] = []
        var missing: Set<SuiteApp> = []
        for app in SuiteApp.apps {
            switch await services.switching.runState(of: app) {
            case .running: r.append(app)
            case .missing: missing.insert(app)
            default: break
            }
        }
        running = r
        missingApps = missing
        missingFiles = Set(recents.items.filter { !fileExists($0.ref.path) }.map(\.ref.fileID))
        rebuild(now: now)
    }

    /// Reloads whenever another process writes recents or an app starts or quits.
    /// The window runs it in a `.task`, so it ends when the window closes.
    public func observe(now: @escaping @Sendable () -> Date) async {
        let recentChanges = await services.recents.changes()
        let runChanges = await services.switching.changes()
        await withTaskGroup(of: Void.self) { group in
            group.addTask { for await _ in recentChanges { await self.reload(now: now()) } }
            group.addTask { for await _ in runChanges { await self.reload(now: now()) } }
        }
    }

    /// A tile or one of its presets (UC-3, UC-5).
    public func newDocument(_ preset: NewDocumentPreset, now: Date) async {
        let h = services.creating.handOff(for: preset, id: "new-\(preset.id)-\(Int(now.timeIntervalSince1970))", at: now)
        do { _ = try await services.sending.send(h) } catch { message = error }
    }

    /// A running row or the Switch To menu (UC-1).
    public func switchTo(_ app: SuiteApp) async {
        do { _ = try await services.switching.switchTo(app, reason: .home) } catch { message = error }
    }

    /// Locate… on a missing card: re-point it to the file the person chose.
    public func locate(_ fileID: String, newPath: String, now: Date) async {
        guard let item = recents.items.first(where: { $0.ref.fileID == fileID }) else { return }
        var ref = item.ref
        ref.path = newPath
        ref.fileID = SuiteDocumentRef.fileID(forPath: newPath)
        do {
            try await services.recents.remove(fileID: fileID)
            try await services.recents.note(ref, event: .opened, at: now, thumbnail: item.thumbnail)
        } catch { message = error }
        await reload(now: now)
    }

    public func search(_ text: String, now: Date) { query = text; rebuild(now: now) }
    public func filter(_ app: SuiteApp?, now: Date) { filter = app; rebuild(now: now) }
    public func select(_ fileID: String?) { selection = fileID; message = nil }
    public func markMissing(_ fileID: String, now: Date) {
        missingFiles.insert(fileID)
        message = .fileMissing(name: recents.items.first { $0.ref.fileID == fileID }?.ref.displayName ?? fileID)
        rebuild(now: now)
    }

    /// Open the selected card in its app (UC-5).
    public func openSelection(now: Date) async {
        guard let id = selection, let item = recents.items.first(where: { $0.ref.fileID == id }) else { return }
        if missingFiles.contains(id) { message = .fileMissing(name: item.ref.displayName); return }
        let h = HandOff(id: "open-\(id)", from: .launcher, to: item.ref.app, verb: .open, documents: [item.ref], createdAt: now)
        do { _ = try await services.sending.send(h) } catch { message = error }
    }

    public func removeSelection(now: Date) async {
        guard let id = selection else { return }
        do { try await services.recents.remove(fileID: id); recents.remove(fileID: id); selection = nil } catch { message = error }
        rebuild(now: now)
    }

    func rebuild(now: Date) {
        state = services.home.home(recents: recents, running: running, query: query, filter: filter, order: order,
                                   missingApps: missingApps, missingFiles: missingFiles, now: now)
    }
}
