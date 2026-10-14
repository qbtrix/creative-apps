// Contracts.swift: one protocol per suite use case (SuiteModel, planned
// `Sources/SuiteModel/Contracts/`, one file per protocol there). UI and
// logic build against these in parallel: the home and the apps' menus on
// the fakes in Fakes.swift, the stores and SuiteShell's live types behind
// them. Every throwing requirement throws `SuiteError`, whose `message` is
// the sentence the UI shows.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// UC-1 Switch between apps (tier 1). Live: SuiteShell `AppLauncher`
/// (NSRunningApplication.activate, else NSWorkspace.openApplication).
public protocol AppSwitching: Sendable {
    func runState(of app: SuiteApp) async -> AppRunState
    /// Yields a counter each time any app's run state changes (launch, quit, crash).
    func changes() async -> AsyncStream<Int>
    /// Brings the app forward, launching it if needed; never opens a document.
    func switchTo(_ app: SuiteApp, reason: SwitchReason) async throws(SuiteError) -> SwitchReceipt
}

/// UC-2 One recents list (tier 1). Live: `FileStore` over `recents.json`
/// plus SuiteShell's change notification.
public protocol RecentWork: Sendable {
    func list() async throws(SuiteError) -> RecentsList
    func note(_ ref: SuiteDocumentRef, event: RecentEvent, at date: Date, thumbnail: String?) async throws(SuiteError)
    func remove(fileID: String) async throws(SuiteError)
    func clear(app: SuiteApp) async throws(SuiteError)
    /// Yields the new revision after any process writes `recents.json`.
    func changes() async -> AsyncStream<Int>
}

/// UC-3 New document by type (tier 1). Pure: presets come from each app's
/// own preset list (mirrored here), creating one makes the hand-off to send.
public protocol DocumentCreating: Sendable {
    func tiles(missing: Set<SuiteApp>) -> [NewTile]
    func handOff(for preset: NewDocumentPreset, id: String, at date: Date) -> HandOff
}

/// UC-4 Route a file to its app, and list Open In targets (tier 1 and 2). Pure.
public protocol DocumentRouting: Sendable {
    /// The app a file opens in, or `.unsupportedFile`.
    func route(fileName: String) throws(SuiteError) -> SuiteApp
    /// Other apps that read this type, default first, never `from` itself.
    func openInTargets(for type: SuiteTypeID, from app: SuiteApp) -> [SuiteApp]
    /// nil when Open In has targets; else why the submenu is disabled.
    func openInRefusal(for type: SuiteTypeID, from app: SuiteApp) -> SuiteError?
}

/// UC-5 Send a hand-off to another process (tier 1: home opens and new
/// documents ride on it). Live: SuiteShell `HandOffTransport`.
public protocol HandOffSending: Sendable {
    func send(_ handOff: HandOff) async throws(SuiteError) -> SwitchReceipt
}

/// UC-5b Receive and settle hand-offs (every app). Live: `FileStore` over `handoffs/`.
public protocol HandOffReceiving: Sendable {
    func receive(_ data: Data, now: Date) async throws(SuiteError) -> HandOff
    func settle(id: String, as state: HandOffState) async throws(SuiteError)
}

/// UC-6 Library to Photo and back (tier 2). Live: a store over `roundtrips/`
/// and hand-offs; Library and Photo each call their half.
public protocol RoundTripEditing: Sendable {
    /// Library: start; Photo receives an `.edit` hand-off with the session id.
    func begin(_ source: RoundTripSource, id: String, at date: Date) async throws(SuiteError) -> RoundTripSession
    /// Photo: the person saved; the flattened copy is for Library, the layered one for re-editing.
    func photoSaved(session id: String, flattened: SuiteDocumentRef, layered: SuiteDocumentRef) async throws(SuiteError) -> RoundTripSession
    /// Library: the copy is in the catalog, stacked on the original.
    func returned(session id: String, as ref: SuiteDocumentRef) async throws(SuiteError) -> RoundTripSession
    func cancel(session id: String) async throws(SuiteError)
    func session(_ id: String) async -> RoundTripSession?
}

/// UC-7 Typed pasteboard and drag data between apps (tier 1). Pure; SuiteShell
/// maps `TypedData` to and from NSPasteboard items and drag providers.
public protocol PasteboardCoding: Sendable {
    /// Richest first: the suite envelope, then SVG or PNG, then text.
    func representations(of item: SuiteClipItem) -> [TypedData]
    /// The best item this app can take from what is offered, or nil.
    func bestItem(from offered: [TypedData], for app: SuiteApp) -> SuiteClipItem?
    /// nil when Paste can act in this app; else why it is disabled.
    func pasteRefusal(for offered: [TypedData], in app: SuiteApp) -> SuiteError?
}

/// UC-8 The shared asset and colour library (tier 2). Live: `FileStore` over `assets/`.
public protocol AssetLibrary: Sendable {
    func index() async throws(SuiteError) -> AssetIndex
    func add(_ draft: AssetDraft, id: String, at date: Date) async throws(SuiteError) -> SuiteAsset
    /// New payload or colour; the revision goes up by one.
    func update(_ id: String, payload: Data?, color: SuiteColorValue?, at date: Date) async throws(SuiteError) -> SuiteAsset
    func remove(_ id: String) async throws(SuiteError)
    func payload(of asset: SuiteAsset) async throws(SuiteError) -> Data
    /// Assets added from this document, so its app can offer Update Asset.
    func assets(fromFileID fileID: String) async throws(SuiteError) -> [SuiteAsset]
    func changes() async -> AsyncStream<Int>
}

/// UC-9 Placed assets keep their link (tier 3). Pure over the index.
public protocol AssetLinking: Sendable {
    func link(to asset: SuiteAsset) -> AssetLink
    func status(of link: AssetLink, in index: AssetIndex) -> LinkStatus
    /// The link after Update; nil when there is nothing newer.
    func updated(_ link: AssetLink, in index: AssetIndex) -> AssetLink?
}

/// UC-10 Read a Flare animation for Halo (tier 3). Live: in HaloModel, which
/// already links FlareCore (SuiteModel never imports an engine).
public protocol AnimationSourceReading: Sendable {
    func summary(of ref: SuiteDocumentRef) async throws(SuiteError) -> AnimationSummary
}

/// UC-11 Shared preferences (tier 2). Live: `FileStore` over `preferences.json`.
public protocol PreferencesStoring: Sendable {
    func load() async throws(SuiteError) -> SuitePreferences
    /// Writes `revision + 1`; `.staleRevision` when another writer won (the caller reloads).
    func save(_ preferences: SuitePreferences) async throws(SuiteError) -> SuitePreferences
    func changes() async -> AsyncStream<Int>
}

/// UC-12 Open the one Settings window at a pane from any app (tier 2).
/// Live: an `.openSettings` hand-off to the launcher.
public protocol SettingsRouting: Sendable {
    func open(_ pane: SettingsPane, from app: SuiteApp) async throws(SuiteError)
}

/// UC-13 First-launch onboarding (tier 3). Pure.
public protocol OnboardingFlowing: Sendable {
    var pages: [OnboardingPage] { get }
    func shouldShow(_ preferences: SuitePreferences, version: Int) -> Bool
    func finishing(_ preferences: SuitePreferences, focus: OnboardingFocus?, version: Int) -> SuitePreferences
}

/// UC-14 One updater (tier 2). Live: URLSession download, CryptoKit Ed25519
/// verify, replace the bundle (in AfterGlowApp).
public protocol UpdateChecking: Sendable {
    func check(current: SuiteVersion) async throws(SuiteError) -> UpdateOffer?
    /// Downloads and verifies; returns the local path of the verified zip.
    func download(_ offer: UpdateOffer) async throws(SuiteError) -> String
    /// Asks every running suite app to quit (each runs its own unsaved flow), then replaces and relaunches.
    /// `.updatePostponed(app)` when an app cancelled its quit; nothing is replaced.
    func install(zipAt path: String) async throws(SuiteError)
}

/// UC-15 Thumbnails for the home (tier 1). Live: SuiteShell `ThumbnailWriter`.
public protocol ThumbnailPublishing: Sendable {
    /// Writes a 512 px PNG; returns its store-relative path.
    func publish(png: Data, for ref: SuiteDocumentRef) async throws(SuiteError) -> String
}

/// UC-16 Build the home's state (tier 1). Pure.
public protocol HomeBuilding: Sendable {
    func home(recents: RecentsList, running: [SuiteApp], query: String, filter: SuiteApp?,
              order: [SuiteApp], missingApps: Set<SuiteApp>, missingFiles: Set<String>, now: Date) -> HomeState
}

/// UC-18 Act on a hand-off (every app, tier 1). Each `<X>Model` conforms
/// (adoption issue A-x-1); `.suiteApp(_:host:)` in SuiteShell hands every
/// received hand-off to it. SuiteShell never sees an app Model, only this.
public protocol SuiteDocumentHost: Sendable {
    /// nil when the app can act on it now; else the reason it refuses.
    func refusal(for handOff: HandOff) async -> SuiteError?
    /// Open, new, edit, place, import or return: the app does it and says how it ended.
    func accept(_ handOff: HandOff) async throws(SuiteError) -> HandOffState
}
