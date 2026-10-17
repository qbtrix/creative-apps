// HomeModel.swift: the home window's view-model (blueprint suite.md 5.7,
// home packet HM-1b). Views read it and call its methods (the app-state
// rule). Linux-safe: Observation ships with the Swift toolchain on Linux.
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
    public private(set) var thumbnailStep = 1           // 0...3, View > Larger/Smaller
    public private(set) var launching: SuiteApp?        // the app a switch, open or new waits on

    @ObservationIgnored let services: SuiteServices
    @ObservationIgnored let fileExists: @Sendable (String) -> Bool
    @ObservationIgnored let makeID: @Sendable () -> String
    @ObservationIgnored private(set) var recents = RecentsList()
    @ObservationIgnored private var running: [SuiteApp] = []
    @ObservationIgnored private var order = SuiteApp.apps
    @ObservationIgnored private var missingApps: Set<SuiteApp> = []
    @ObservationIgnored private var missingFiles: Set<String> = []
    @ObservationIgnored private var lastRemoved: RecentItem?

    /// `fileExists` is `FileManager.default.fileExists(atPath:)` in the app; tests pass a rule.
    public init(services: SuiteServices, fileExists: @escaping @Sendable (String) -> Bool,
                makeID: @escaping @Sendable () -> String = HandOff.newID) {
        self.services = services; self.fileExists = fileExists; self.makeID = makeID
    }

    /// Whether Edit > Undo can put back the last removed card.
    public var canUndoRemove: Bool { lastRemoved != nil }

    /// "Logo.design removed from Recents." while Undo can put it back (#1865); nil otherwise.
    public var removedNotice: String? { lastRemoved.map { "\($0.ref.displayName) removed from Recents." } }

    /// The search line beside RECENT: "2 items matching “logo”" while a search is on (#1866).
    public var matching: String? { Self.matching(query: query, count: state.cards.count) }

    /// "1 item matching “q”" / "N items matching “q”"; nil for an empty query.
    public static func matching(query: String, count: Int) -> String? {
        query.isEmpty ? nil : "\(count) \(count == 1 ? "item" : "items") matching \u{201C}\(query)\u{201D}"
    }

    public func reload(now: Date) async {
        do { recents = try await services.recents.list() } catch { message = error }
        order = Self.ordered((try? await services.preferences.load())?.homeOrder ?? SuiteApp.apps)
        running = []; missingApps = []
        for app in SuiteApp.apps {
            switch await services.switching.runState(of: app) {
            case .running: running.append(app)
            case .missing: missingApps.insert(app)
            default: break
            }
        }
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

    public func search(_ text: String, now: Date) { query = text; rebuild(now: now) }
    public func filter(_ app: SuiteApp?, now: Date) { filter = app; rebuild(now: now) }
    public func select(_ fileID: String?) { selection = fileID; message = nil }
    public func larger() { thumbnailStep = min(thumbnailStep + 1, 3) }
    public func smaller() { thumbnailStep = max(thumbnailStep - 1, 0) }

    /// An open found the file gone: mark its card and say so in place.
    public func markMissing(_ fileID: String, now: Date) {
        missingFiles.insert(fileID)
        message = .fileMissing(name: item(fileID)?.ref.displayName ?? fileID)
        rebuild(now: now)
    }

    /// A tile or one of its presets (UC-3, UC-5).
    public func newDocument(_ preset: NewDocumentPreset, now: Date) async {
        await send(services.creating.handOff(for: preset, id: makeID(), at: now))
    }

    /// A running row or the Switch To menu (UC-1).
    public func switchTo(_ app: SuiteApp) async {
        launching = app
        do { _ = try await services.switching.switchTo(app, reason: .home) } catch { message = error }
        launching = nil
    }

    /// Open the selected card in its app (UC-5). A missing file sends nothing.
    public func openSelection(now: Date) async {
        guard let id = selection, let item = item(id) else { return }
        if missingFiles.contains(id) { message = .fileMissing(name: item.ref.displayName); return }
        await send(HandOff(id: makeID(), from: .launcher, to: item.ref.app, verb: .open, documents: [item.ref], createdAt: now))
    }

    /// Locate… on a missing card: re-point it to the file the person chose.
    public func locate(_ fileID: String, newPath: String, now: Date) async {
        guard let item = item(fileID) else { return }
        var ref = item.ref
        ref.path = newPath; ref.fileID = SuiteDocumentRef.fileID(forPath: newPath); ref.bookmark = nil
        ref.displayName = newPath.split(separator: "/").last.map(String.init) ?? ref.displayName
        do {
            try await services.recents.remove(fileID: fileID)
            try await services.recents.note(ref, event: .opened, at: now, thumbnail: item.thumbnail)
            if selection == fileID { selection = ref.fileID }; message = nil
        } catch { message = error }
        await reload(now: now)
    }

    public func removeSelection(now: Date) async {
        guard let id = selection, let item = item(id) else { return }
        do {
            try await services.recents.remove(fileID: id)
            recents.remove(fileID: id); lastRemoved = item; selection = nil; message = nil
        } catch { message = error }
        rebuild(now: now)
    }

    /// Edit > Undo after Remove from Recents: re-notes the card with its date and thumbnail.
    public func undoRemove(now: Date) async {
        guard let item = lastRemoved else { return }
        do {
            try await services.recents.note(item.ref, event: .opened, at: item.lastUsed, thumbnail: item.thumbnail)
            lastRemoved = nil; selection = item.ref.fileID
        } catch { message = error }
        await reload(now: now)
    }

    private func send(_ handOff: HandOff) async {
        launching = handOff.to
        do { _ = try await services.sending.send(handOff) } catch { message = error }
        launching = nil
    }

    private func item(_ fileID: String) -> RecentItem? { recents.items.first { $0.ref.fileID == fileID } }

    private func rebuild(now: Date) {
        var s = services.home.home(recents: recents, running: running, query: query, filter: filter, order: order,
                                   missingApps: missingApps, missingFiles: missingFiles, now: now)
        if let reason = services.pending["sending"] {
            for i in s.tiles.indices where s.tiles[i].disabledReason == nil { s.tiles[i].disabledReason = reason }
        }
        state = s
    }

    /// The saved order's apps first, once each, then any app it leaves out in the default order.
    static func ordered(_ saved: [SuiteApp]) -> [SuiteApp] {
        var out: [SuiteApp] = []
        for app in saved + SuiteApp.apps where SuiteApp.apps.contains(app) && !out.contains(app) { out.append(app) }
        return out
    }
}
