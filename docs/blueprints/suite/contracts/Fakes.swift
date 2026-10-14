// Fakes.swift: one fake per contract (SuiteModel, planned
// `Sources/SuiteModel/Fakes/`, one file each there). In memory, no disk, no
// AppKit. Every fake takes `unavailable:`; set, its reads are empty and its
// writes throw `.notAvailable(reason)`, so `.live` can point at a fake that
// isn't integrated yet and the control shows disabled with that reason.
// The pure contracts' fakes are also their reference behavior: the live
// type for those is this code moved to its component folder.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Holds the continuations of `changes()` streams for an actor fake.
struct ChangeFeed {
    private var continuations: [AsyncStream<Int>.Continuation] = []
    mutating func stream() -> AsyncStream<Int> {
        let (s, c) = AsyncStream<Int>.makeStream()
        continuations.append(c)
        return s
    }
    func send(_ revision: Int) { for c in continuations { c.yield(revision) } }
}

public actor FakeSwitching: AppSwitching {
    public private(set) var states: [SuiteApp: AppRunState]
    public private(set) var ticks: Double = 0
    var feed = ChangeFeed()
    let unavailable: String?
    public init(running: [SuiteApp] = [], missing: Set<SuiteApp> = [], unavailable: String? = nil) {
        var s: [SuiteApp: AppRunState] = [:]
        for app in SuiteApp.allCases { s[app] = missing.contains(app) ? .missing : running.contains(app) ? .running(windows: 1) : .notRunning }
        s[.launcher] = .running(windows: 1)
        states = s
        self.unavailable = unavailable
    }
    public func runState(of app: SuiteApp) -> AppRunState { states[app] ?? .notRunning }
    public func changes() -> AsyncStream<Int> { feed.stream() }
    public func switchTo(_ app: SuiteApp, reason: SwitchReason) throws(SuiteError) -> SwitchReceipt {
        if let unavailable { throw .notAvailable(unavailable) }
        let before = states[app] ?? .notRunning
        if before == .missing { throw .appMissing(app) }
        ticks += 1
        if case .running = before {} else { states[app] = .running(windows: 1); feed.send(Int(ticks)) }
        if case .running = before { return SwitchReceipt(app: app, wasRunning: true, requestedAt: ticks) }
        return SwitchReceipt(app: app, wasRunning: false, requestedAt: ticks)
    }
    /// Test hook: the app quit or crashed.
    public func terminate(_ app: SuiteApp) { states[app] = .notRunning; ticks += 1; feed.send(Int(ticks)) }
}

public actor FakeRecents: RecentWork {
    public private(set) var stored: RecentsList {
        didSet { if stored.revision != oldValue.revision { feed.send(stored.revision) } }
    }
    var feed = ChangeFeed()
    let unavailable: String?
    public init(_ list: RecentsList = RecentsList(), unavailable: String? = nil) { stored = list; self.unavailable = unavailable }
    public func list() throws(SuiteError) -> RecentsList { if let unavailable { throw .notAvailable(unavailable) }; return stored }
    public func note(_ ref: SuiteDocumentRef, event: RecentEvent, at date: Date, thumbnail: String?) throws(SuiteError) {
        if let unavailable { throw .notAvailable(unavailable) }
        let keep = stored.items.first { $0.ref.fileID == ref.fileID }?.thumbnail
        stored.note(RecentItem(ref: ref, lastUsed: date, thumbnail: thumbnail ?? keep))
        stored.revision += 1
    }
    public func remove(fileID: String) throws(SuiteError) {
        if let unavailable { throw .notAvailable(unavailable) }
        stored.remove(fileID: fileID); stored.revision += 1
    }
    public func clear(app: SuiteApp) throws(SuiteError) {
        if let unavailable { throw .notAvailable(unavailable) }
        stored.clear(app: app); stored.revision += 1
    }
    public func changes() -> AsyncStream<Int> { feed.stream() }
}

public struct FakeCreating: DocumentCreating {
    let unavailable: String?
    public init(unavailable: String? = nil) { self.unavailable = unavailable }

    /// Mirrors each app's own preset list (Flare's New Animation sheet, Halo's New Composition, …).
    public static let presets: [SuiteApp: [NewDocumentPreset]] = [
        .flare: [NewDocumentPreset(id: "flare.hd", app: .flare, title: "1080p 16:9", detail: "1920 × 1080, 24 fps", parameters: ["width": "1920", "height": "1080", "fps": "24"]),
                 NewDocumentPreset(id: "flare.square", app: .flare, title: "Square", detail: "1080 × 1080, 24 fps", parameters: ["width": "1080", "height": "1080", "fps": "24"]),
                 NewDocumentPreset(id: "flare.vertical", app: .flare, title: "Vertical 9:16", detail: "1080 × 1920, 30 fps", parameters: ["width": "1080", "height": "1920", "fps": "30"])],
        .design: [NewDocumentPreset(id: "design.blank", app: .design, title: "Blank", detail: "One page")],
        .photo: [NewDocumentPreset(id: "photo.sheet", app: .photo, title: "New Image…", detail: "Choose a size")],
        .library: [NewDocumentPreset(id: "library.import", app: .library, title: "Import Folder…", detail: "PNG, JPEG, HEIC")],
        .halo: [NewDocumentPreset(id: "halo.sheet", app: .halo, title: "New Composition…", detail: "Choose size, rate and length")],
    ]

    public func tiles(missing: Set<SuiteApp>) -> [NewTile] {
        let titles: [SuiteApp: String] = [.flare: "New Animation", .design: "New Design", .photo: "New Image",
                                          .library: "Import Photos…", .halo: "New Composition"]
        return SuiteApp.apps.map { app in
            let reason = missing.contains(app) ? SuiteError.appMissing(app).message : unavailable
            return NewTile(app: app, title: titles[app] ?? app.displayName, presets: Self.presets[app] ?? [], disabledReason: reason)
        }
    }

    public func handOff(for preset: NewDocumentPreset, id: String, at date: Date) -> HandOff {
        HandOff(id: id, from: .launcher, to: preset.app, verb: .new, preset: preset, createdAt: date)
    }
}

public struct FakeRouting: DocumentRouting {
    public var registry: SuiteTypeRegistry
    public init(registry: SuiteTypeRegistry = .standard) { self.registry = registry }

    public func route(fileName: String) throws(SuiteError) -> SuiteApp {
        let ext = fileName.split(separator: ".").last.map(String.init) ?? ""
        if fileName.hasSuffix(".aghandoff") { return .launcher }
        guard fileName.contains("."), let t = registry.type(forExtension: ext), let app = registry.defaultApp(for: t.id) else {
            throw .unsupportedFile(name: fileName)
        }
        return app
    }

    public func openInTargets(for type: SuiteTypeID, from app: SuiteApp) -> [SuiteApp] {
        (registry.type(type)?.readers ?? []).filter { $0 != app }
    }

    public func openInRefusal(for type: SuiteTypeID, from app: SuiteApp) -> SuiteError? {
        openInTargets(for: type, from: app).isEmpty ? .noOtherReader(typeName: registry.type(type)?.name ?? "these") : nil
    }
}

public actor FakeHandOffs: HandOffSending, HandOffReceiving {
    public private(set) var sent: [HandOff] = []
    public private(set) var settled: [String: HandOffState] = [:]
    let unavailable: String?
    let switching: FakeSwitching
    public init(switching: FakeSwitching = FakeSwitching(), unavailable: String? = nil) {
        self.switching = switching; self.unavailable = unavailable
    }
    public func send(_ handOff: HandOff) async throws(SuiteError) -> SwitchReceipt {
        if let unavailable { throw .notAvailable(unavailable) }
        sent.append(handOff)
        return try await switching.switchTo(handOff.to, reason: .handOff)
    }
    public func receive(_ data: Data, now: Date) throws(SuiteError) -> HandOff {
        var h = try HandOffCodec.decode(data)
        if h.isExpired(now: now) { h.state = .expired; settled[h.id] = .expired; throw .notAvailable("This request expired.") }
        h.state = .accepted
        settled[h.id] = .accepted
        return h
    }
    public func settle(id: String, as state: HandOffState) throws(SuiteError) {
        if let unavailable { throw .notAvailable(unavailable) }
        settled[id] = state
    }
}

public actor FakeRoundTrips: RoundTripEditing {
    public private(set) var sessions: [String: RoundTripSession] = [:]
    let unavailable: String?
    let missingOriginals: Set<String>   // fileIDs whose original is gone
    public init(missingOriginals: Set<String> = [], unavailable: String? = nil) {
        self.missingOriginals = missingOriginals; self.unavailable = unavailable
    }

    public func begin(_ source: RoundTripSource, id: String, at date: Date) throws(SuiteError) -> RoundTripSession {
        if let unavailable { throw .notAvailable(unavailable) }
        if missingOriginals.contains(source.original.fileID) {
            let name = source.original.displayName.split(separator: ".").first.map(String.init) ?? source.original.displayName
            throw .originalMissing(name: name)
        }
        let base = source.original.displayName.split(separator: ".").first.map(String.init) ?? source.original.displayName
        let s = RoundTripSession(id: id, source: source, title: "\(base) (Library edit)", state: .open, startedAt: date)
        sessions[id] = s
        return s
    }
    public func photoSaved(session id: String, flattened: SuiteDocumentRef, layered: SuiteDocumentRef) throws(SuiteError) -> RoundTripSession {
        guard var s = sessions[id], s.state == .open || isSaved(s.state) else { throw .notAvailable("This edit is no longer open in Library.") }
        s.state = .saved(flattened: flattened, layered: layered)
        sessions[id] = s
        return s
    }
    public func returned(session id: String, as ref: SuiteDocumentRef) throws(SuiteError) -> RoundTripSession {
        guard var s = sessions[id], isSaved(s.state) else { throw .notAvailable("Nothing to bring back yet.") }
        s.state = .returned(ref)
        sessions[id] = s
        return s
    }
    public func cancel(session id: String) throws(SuiteError) {
        guard var s = sessions[id] else { return }
        s.state = .cancelled
        sessions[id] = s
    }
    public func session(_ id: String) -> RoundTripSession? { sessions[id] }

    func isSaved(_ state: RoundTripState) -> Bool { if case .saved = state { return true }; return false }
}

public struct FakePasteboard: PasteboardCoding {
    public init() {}

    /// What each app can take, best first.
    public static let accepts: [SuiteApp: [SuiteTypeID]] = [
        .flare: [.assetEnvelope, .flareLayers, .svg, .plainText, .fileURL],
        .design: [.assetEnvelope, .designLayers, .svg, .png, .plainText, .fileURL],
        .photo: [.assetEnvelope, .png, .jpeg, .heic, .plainText, .fileURL],
        .library: [.png, .jpeg, .heic, .fileURL],
        .halo: [.assetEnvelope, .plainText, .fileURL],
        .launcher: [.fileURL, .assetEnvelope, .svg, .png],
    ]

    public func representations(of item: SuiteClipItem) -> [TypedData] {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        switch item {
        case .envelope(let e):
            var reps = [TypedData]()
            if let d = try? enc.encode(e) { reps.append(TypedData(type: .assetEnvelope, data: d)) }
            if let svg = e.svg { reps.append(TypedData(type: .svg, data: Data(svg.utf8))) }
            if let c = e.color { reps.append(TypedData(type: .plainText, data: Data(("#" + c.hex).utf8))) }
            return reps
        case .vector(let svg, _): return [TypedData(type: .svg, data: Data(svg.utf8))]
        case .image(let png, _, _): return [TypedData(type: .png, data: png)]
        case .color(let c):
            let e = AssetEnvelope(name: "#" + c.hex, kind: .color, from: .launcher, color: c)
            return representations(of: .envelope(e))
        case .text(let t): return [TypedData(type: .plainText, data: Data(t.utf8))]
        case .files(let refs): return refs.map { TypedData(type: .fileURL, data: Data(("file://" + $0.path).utf8)) }
        }
    }

    public func bestItem(from offered: [TypedData], for app: SuiteApp) -> SuiteClipItem? {
        for type in Self.accepts[app] ?? [] {
            guard let rep = offered.first(where: { $0.type == type }) else { continue }
            switch type {
            case .assetEnvelope:
                guard let e = try? JSONDecoder().decode(AssetEnvelope.self, from: rep.data) else { continue }   // damaged: fall back
                if e.kind == .image, app == .flare || app == .halo { continue }
                return .envelope(e)
            case .svg: return .vector(svg: String(decoding: rep.data, as: UTF8.self), name: "Pasted art")
            case .png, .jpeg, .heic: return .image(png: rep.data, pixelWidth: 0, pixelHeight: 0)
            case .plainText: return .text(String(decoding: rep.data, as: UTF8.self))
            case .fileURL:
                let routing = FakeRouting()
                let refs = offered.filter { $0.type == .fileURL }.compactMap { r -> SuiteDocumentRef? in
                    let path = String(String(decoding: r.data, as: UTF8.self).dropFirst("file://".count))
                    let name = path.split(separator: "/").last.map(String.init) ?? path
                    guard let target = try? routing.route(fileName: name),
                          let type = routing.registry.type(forExtension: name.split(separator: ".").last.map(String.init) ?? "")
                    else { return nil }
                    return SuiteDocumentRef(path: path, fileID: path, app: target, type: type.id, displayName: name)
                }
                if refs.isEmpty { continue }
                return .files(refs)
            default: continue   // an app's own layer types are read by that app's model, not here
            }
        }
        return nil
    }

    public func pasteRefusal(for offered: [TypedData], in app: SuiteApp) -> SuiteError? {
        if offered.isEmpty { return .nothingToPaste }
        if bestItem(from: offered, for: app) != nil { return nil }
        if offered.contains(where: { [.png, .jpeg, .heic].contains($0.type) }) { return .cannotPaste(app: app, kind: "images") }
        return .cannotPaste(app: app, kind: "this")
    }
}

public actor FakeAssets: AssetLibrary {
    public private(set) var stored: AssetIndex {
        didSet { if stored.revision != oldValue.revision { feed.send(stored.revision) } }
    }
    var feed = ChangeFeed()
    var payloads: [String: Data] = [:]
    let unavailable: String?
    public init(_ index: AssetIndex = AssetIndex(), unavailable: String? = nil) { stored = index; self.unavailable = unavailable }

    public func index() throws(SuiteError) -> AssetIndex { if let unavailable { throw .notAvailable(unavailable) }; return stored }
    public func add(_ draft: AssetDraft, id: String, at date: Date) throws(SuiteError) -> SuiteAsset {
        if let unavailable { throw .notAvailable(unavailable) }
        let path = draft.payload == nil ? nil : "assets/\(id)/1.\(draft.payloadExtension ?? "bin")"
        let a = SuiteAsset(id: id, kind: draft.kind, name: draft.name, color: draft.color, payload: path, source: draft.source, modifiedAt: date)
        if let p = path, let d = draft.payload { payloads[p] = d }
        stored.assets.insert(a, at: 0); stored.revision += 1
        return a
    }
    public func update(_ id: String, payload: Data?, color: SuiteColorValue?, at date: Date) throws(SuiteError) -> SuiteAsset {
        if let unavailable { throw .notAvailable(unavailable) }
        guard let i = stored.assets.firstIndex(where: { $0.id == id }) else { throw .notAvailable("This asset was removed.") }
        var a = stored.assets[i]
        a.revision += 1; a.modifiedAt = date
        if let color { a.color = color }
        if let payload, let old = a.payload {
            let ext = old.split(separator: ".").last.map(String.init) ?? "bin"
            a.payload = "assets/\(id)/\(a.revision).\(ext)"
            if let p = a.payload { payloads[p] = payload }
        }
        stored.assets[i] = a; stored.revision += 1
        return a
    }
    public func remove(_ id: String) throws(SuiteError) {
        if let unavailable { throw .notAvailable(unavailable) }
        stored.assets.removeAll { $0.id == id }; stored.revision += 1
    }
    public func payload(of asset: SuiteAsset) throws(SuiteError) -> Data {
        guard let p = asset.payload, let d = payloads[p] else { throw .fileMissing(name: asset.name) }
        return d
    }
    public func assets(fromFileID fileID: String) throws(SuiteError) -> [SuiteAsset] {
        if let unavailable { throw .notAvailable(unavailable) }
        return stored.assets.filter { $0.source?.fileID == fileID }
    }
    public func changes() -> AsyncStream<Int> { feed.stream() }
}

public struct FakeLinking: AssetLinking {
    public init() {}
    public func link(to asset: SuiteAsset) -> AssetLink { AssetLink(assetID: asset.id, kind: asset.kind, placedRevision: asset.revision) }
    public func status(of link: AssetLink, in index: AssetIndex) -> LinkStatus {
        guard let a = index.asset(link.assetID) else { return .missing }
        return a.revision > link.placedRevision ? .updateAvailable(revision: a.revision) : .current
    }
    public func updated(_ link: AssetLink, in index: AssetIndex) -> AssetLink? {
        guard case .updateAvailable(let r) = status(of: link, in: index) else { return nil }
        return AssetLink(assetID: link.assetID, kind: link.kind, placedRevision: r)
    }
}

public struct FakeAnimationSource: AnimationSourceReading {
    public var summaries: [String: AnimationSummary]   // keyed by fileID
    let unavailable: String?
    public init(summaries: [String: AnimationSummary] = [:], unavailable: String? = nil) {
        self.summaries = summaries; self.unavailable = unavailable
    }
    public func summary(of ref: SuiteDocumentRef) throws(SuiteError) -> AnimationSummary {
        if let unavailable { throw .notAvailable(unavailable) }
        guard let s = summaries[ref.fileID] else { throw .fileMissing(name: ref.displayName) }
        return s
    }
}

public actor FakePreferences: PreferencesStoring {
    public private(set) var stored: SuitePreferences {
        didSet { if stored.revision != oldValue.revision { feed.send(stored.revision) } }
    }
    var feed = ChangeFeed()
    let unavailable: String?
    public init(_ p: SuitePreferences = SuitePreferences(), unavailable: String? = nil) { stored = p; self.unavailable = unavailable }
    public func load() throws(SuiteError) -> SuitePreferences { if let unavailable { throw .notAvailable(unavailable) }; return stored }
    public func save(_ p: SuitePreferences) throws(SuiteError) -> SuitePreferences {
        if let unavailable { throw .notAvailable(unavailable) }
        guard p.revision == stored.revision else { throw .staleRevision }
        var next = p
        next.revision += 1
        stored = next
        return next
    }
    public func changes() -> AsyncStream<Int> { feed.stream() }
}

public actor FakeSettingsRoute: SettingsRouting {
    public private(set) var opened: [SettingsPane] = []
    let unavailable: String?
    public init(unavailable: String? = nil) { self.unavailable = unavailable }
    public func open(_ pane: SettingsPane, from app: SuiteApp) throws(SuiteError) {
        if let unavailable { throw .notAvailable(unavailable) }
        opened.append(pane)
    }
}

public struct FakeOnboarding: OnboardingFlowing {
    public init() {}
    public var pages: [OnboardingPage] {
        [OnboardingPage(id: "apps", title: "Five apps, one AfterGlow",
                        body: "Flare animates, Design draws, Photo retouches, Library sorts your photos, Halo composites. Switch with Control-Command 1 to 5."),
         OnboardingPage(id: "focus", title: "What do you make most?", body: "AfterGlow puts those apps first. You can change this in Settings.",
                        choices: OnboardingFocus.allCases),
         OnboardingPage(id: "start", title: "Start with a sample", body: "Open a sample to see each app at work, or start from an empty home.")]
    }
    public func shouldShow(_ p: SuitePreferences, version: Int) -> Bool { p.onboardingDoneVersion == nil }
    public func finishing(_ p: SuitePreferences, focus: OnboardingFocus?, version: Int) -> SuitePreferences {
        var next = p
        next.onboardingDoneVersion = version
        let first: [SuiteApp]
        switch focus {
        case .animation: first = [.flare, .halo]
        case .design: first = [.design]
        case .photos: first = [.library, .photo]
        case .motion: first = [.halo, .flare]
        case .everything, nil: first = []
        }
        next.homeOrder = first + SuiteApp.apps.filter { !first.contains($0) }
        return next
    }
}

public actor FakeUpdates: UpdateChecking {
    public var feed: Data
    public private(set) var installed: [String] = []
    let unavailable: String?
    let validSignatures: Set<String>
    let refusesQuit: SuiteApp?          // an app whose unsaved-changes prompt is cancelled
    public init(feed: Data = Data("[]".utf8), validSignatures: Set<String> = [], refusesQuit: SuiteApp? = nil,
                unavailable: String? = nil) {
        self.feed = feed; self.validSignatures = validSignatures; self.refusesQuit = refusesQuit; self.unavailable = unavailable
    }
    public func check(current: SuiteVersion) throws(SuiteError) -> UpdateOffer? {
        if let unavailable { throw .notAvailable(unavailable) }
        return try UpdateFeed.newest(in: feed, above: current)
    }
    public func download(_ offer: UpdateOffer) throws(SuiteError) -> String {
        guard validSignatures.contains(offer.signature) else { throw .updateNotVerified }
        return "/tmp/AfterGlow-\(offer.version.major).\(offer.version.minor).\(offer.version.patch).zip"
    }
    public func install(zipAt path: String) throws(SuiteError) {
        if let app = refusesQuit { throw .updatePostponed(app) }
        installed.append(path)
    }
}

public actor FakeThumbnails: ThumbnailPublishing {
    public private(set) var written: [String: Data] = [:]
    let unavailable: String?
    public init(unavailable: String? = nil) { self.unavailable = unavailable }
    public func publish(png: Data, for ref: SuiteDocumentRef) throws(SuiteError) -> String {
        if let unavailable { throw .notAvailable(unavailable) }
        let path = "thumbnails/\(ref.fileID).png"
        written[path] = png
        return path
    }
}

public struct FakeHome: HomeBuilding {
    let creating: any DocumentCreating
    public init(creating: any DocumentCreating = FakeCreating()) { self.creating = creating }

    public func home(recents: RecentsList, running: [SuiteApp], query: String, filter: SuiteApp?,
                     order: [SuiteApp], missingApps: Set<SuiteApp>, missingFiles: Set<String>, now: Date) -> HomeState {
        let tiles = creating.tiles(missing: missingApps)
        let ordered = order.compactMap { app in tiles.first { $0.app == app } }
        let cards = recents.filtered(app: filter, query: query).map {
            RecentCard(item: $0, age: Self.age(of: $0.lastUsed, now: now), isMissing: missingFiles.contains($0.ref.fileID))
        }
        let empty: String?
        if !cards.isEmpty { empty = nil }
        else if recents.items.isEmpty { empty = "No recent work yet. Start something new above, or open a file." }
        else { empty = "Nothing matches \u{201C}\(query)\u{201D}." }
        return HomeState(tiles: ordered, cards: cards, running: running.filter { $0 != .launcher }, emptyMessage: empty)
    }

    /// "Today", "Yesterday", else days ago; the live type formats weekday and date with the locale.
    static func age(of date: Date, now: Date) -> String {
        let days = Int(now.timeIntervalSince(date) / 86_400)
        return days <= 0 ? "Today" : days == 1 ? "Yesterday" : "\(days) days ago"
    }
}

/// A host that records what it was asked to do; refuses the verbs it doesn't take.
public actor FakeDocumentHost: SuiteDocumentHost {
    public let app: SuiteApp
    public let verbs: Set<HandOffVerb>
    public private(set) var accepted: [HandOff] = []
    public init(app: SuiteApp, verbs: Set<HandOffVerb>) { self.app = app; self.verbs = verbs }
    public func refusal(for handOff: HandOff) -> SuiteError? {
        verbs.contains(handOff.verb) ? nil : .notAvailable("\(app.displayName) can't do that yet.")
    }
    public func accept(_ handOff: HandOff) throws(SuiteError) -> HandOffState {
        if let r = refusal(for: handOff) { throw r }
        accepted.append(handOff)
        return handOff.verb == .edit ? .accepted : .returned
    }
}

/// The journeys' fixtures as store files (section 4.1). The launcher writes them
/// into `-SuiteSupportDir` with `FileStore`, then every process runs on `.live`,
/// so what one app writes the others read. Document files come from
/// `UITests/Fixtures/suite/` (each app line's fixture export, A-x-0).
public enum SuiteFixtures {
    public static let names = ["empty", "firstLaunch", "weekOfWork", "missing", "roundTrip", "assets", "crowd"]

    public struct Store: Equatable, Sendable {
        public var recents: RecentsList
        public var assets: AssetIndex
        public var preferences: SuitePreferences
    }

    public static let weekOfWorkFiles: [(String, SuiteApp, SuiteTypeID)] = [
        ("Logo.design", .design, .designDocument), ("Cards.design", .design, .designDocument),
        ("Bounce.flare", .flare, .flareAnimation), ("Intro.halo", .halo, .haloProject),
        ("beach.ora", .photo, .photoOpenRaster), ("Title.flare", .flare, .flareAnimation),
        ("Sunset.png", .photo, .png), ("Logo animated.flare", .flare, .flareAnimation),
    ]

    /// nil for an unknown name. `documents` is the folder holding the fixture documents.
    public static func store(_ name: String, documents: String, now: Date) -> Store? {
        func ref(_ f: (String, SuiteApp, SuiteTypeID)) -> SuiteDocumentRef {
            let path = documents + "/" + f.0
            return SuiteDocumentRef(path: path, fileID: SuiteDocumentRef.fileID(forPath: path), app: f.1, type: f.2, displayName: f.0)
        }
        let done = SuitePreferences(onboardingDoneVersion: 1)
        switch name {
        case "empty", "roundTrip":
            return Store(recents: RecentsList(), assets: AssetIndex(), preferences: done)
        case "firstLaunch":
            return Store(recents: RecentsList(), assets: AssetIndex(), preferences: SuitePreferences())
        case "weekOfWork", "missing":
            let items = weekOfWorkFiles.enumerated().map { i, f in
                RecentItem(ref: ref(f), lastUsed: now - Double(i) * 75_600, thumbnail: "thumbnails/\(f.0).png")
            }
            return Store(recents: RecentsList(revision: 1, items: items), assets: AssetIndex(), preferences: done)
        case "assets":
            let colors = [("Brand blue", SuiteColorSpace.sRGB, 0.094, 0.467, 0.949), ("Ink", .sRGB, 0.1, 0.1, 0.12),
                          ("Paper", .sRGB, 0.98, 0.97, 0.94), ("Coral", .sRGB, 1, 0.42, 0.36),
                          ("Vivid green", .displayP3, 0.2, 0.9, 0.3), ("Vivid red", .displayP3, 1, 0.1, 0.1)]
            var assets = colors.enumerated().map { i, c in
                SuiteAsset(id: "c\(i)", kind: .color, name: c.0, color: SuiteColorValue(space: c.1, red: c.2, green: c.3, blue: c.4),
                           modifiedAt: now - Double(i))
            }
            let cards = ref(("Cards.design", .design, .designDocument))
            assets.append(SuiteAsset(id: "v0", kind: .vector, name: "Card", payload: "assets/v0/1.svg", source: cards, modifiedAt: now - 10))
            assets.append(SuiteAsset(id: "v1", kind: .vector, name: "Badge", payload: "assets/v1/1.svg", source: cards, modifiedAt: now - 11))
            assets.append(SuiteAsset(id: "i0", kind: .image, name: "Sunset", payload: "assets/i0/1.png", modifiedAt: now - 12))
            assets.append(SuiteAsset(id: "a0", kind: .animation, name: "Bounce", payload: "assets/a0/1.flare", modifiedAt: now - 13))
            return Store(recents: RecentsList(), assets: AssetIndex(revision: 1, assets: assets), preferences: done)
        case "crowd":
            let items = (0..<200).map { i in
                RecentItem(ref: SuiteDocumentRef(path: documents + "/Doc \(i).flare", fileID: SuiteDocumentRef.fileID(forPath: documents + "/Doc \(i).flare"), app: .flare,
                                                 type: .flareAnimation, displayName: "Doc \(i).flare"), lastUsed: now - Double(i))
            }
            return Store(recents: RecentsList(revision: 1, items: items), assets: AssetIndex(), preferences: done)
        default:
            return nil
        }
    }
}
