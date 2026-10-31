// OnboardingModel.swift: the welcome window's view-model (blueprint 5.7,
// HomeModel's shape; onboarding packet OB-1 stubs, OB-8 body). Views read it
// and call its methods (the app-state rule). Linux-safe: Observation ships
// with the Swift toolchain on Linux.
import Observation
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// The window's view-model (blueprint 5.7, HomeModel's shape). Linux-safe.
@MainActor @Observable
public final class OnboardingModel {
    public private(set) var pages: [OnboardingPage]        // services.onboarding.pages
    public private(set) var pageIndex = 0
    public private(set) var focus: OnboardingFocus?
    public private(set) var starters: [OnboardingStarter] = []  // tiles in SuiteOnboarding.order(for: focus)
    public private(set) var launching: SuiteApp?            // a hand-off in flight
    public private(set) var message: SuiteError?            // shown under the tile, never an alert
    public private(set) var failed: SuiteApp?               // the tile `message` belongs to; nil for a message with no tile
    public private(set) var isFinished = false              // the window closes when true

    @ObservationIgnored let services: SuiteServices
    @ObservationIgnored let samplesFolder: String
    @ObservationIgnored let documents: String
    @ObservationIgnored let present: @Sendable (String) -> Bool
    @ObservationIgnored let copy: @Sendable (String, String) throws(SuiteError) -> Void
    @ObservationIgnored let makeID: @Sendable () -> String

    /// The current page; an empty page when `pageIndex` has no page (never out of range).
    public var page: OnboardingPage { pages.indices.contains(pageIndex) ? pages[pageIndex] : OnboardingPage(id: "", title: "", body: "") }
    public var canGoBack: Bool { pageIndex > 0 }
    public var isLastPage: Bool { pageIndex + 1 >= pages.count }
    public var renderingNote: String { SuiteOnboarding.renderingNote }
    /// Why Skip, Back and Continue are held: a hand-off is sending. Nil when they act.
    public var sendingReason: String? { launching == nil ? nil : "A document is opening." }
    /// Each control's help (#3018): `sendingReason` while a hand-off holds it, else what it does.
    public var skipHelp: String { sendingReason ?? "Close the welcome window. Help > Welcome to AfterGlow opens it again." }
    public var backHelp: String { sendingReason ?? "Go back to the previous page." }
    public var startEmptyHelp: String { sendingReason ?? "Close the welcome window and go to the home with nothing open." }
    /// A tile's preset chips' help: the tile's own reason, then the hand-off's, then what a click does.
    public func presetsHelp(_ tile: NewTile) -> String { tile.disabledReason ?? sendingReason ?? SuiteOnboarding.presetsHelp(tile) }
    /// Why a starter's Open sample can't act (no sample, a missing file, a hand-off sending); nil when it can.
    public func sampleUnavailable(_ starter: OnboardingStarter) -> String? {
        guard starter.sample != nil else { return Self.sampleMissing(starter.tile.app).message }
        return starter.sampleReason ?? sendingReason
    }
    /// Open sample's help: why it can't act, else what it opens.
    public func sampleHelp(_ starter: OnboardingStarter) -> String {
        sampleUnavailable(starter) ?? "Open \(starter.sample?.title ?? "") in \(starter.tile.app.displayName)."
    }

    /// `present` is FileManager.default.fileExists in the app; `samplesFolder` the bundle's Resources/Samples;
    /// `documents` the support folder's Documents; `copy` moves bytes (tests pass a recorder).
    public init(services: SuiteServices, samplesFolder: String, documents: String,
                present: @escaping @Sendable (String) -> Bool,
                copy: @escaping @Sendable (String, String) throws(SuiteError) -> Void,
                makeID: @escaping @Sendable () -> String = HandOff.newID) {
        self.services = services; self.samplesFolder = samplesFolder; self.documents = documents
        self.present = present; self.copy = copy; self.makeID = makeID
        pages = services.onboarding.pages
    }

    /// The pages and the starters; once the tour has run, the focus whose order the saved homeOrder is.
    public func load() async {
        pages = services.onboarding.pages
        if let p = try? await services.preferences.load(), p.onboardingDoneVersion != nil {
            focus = Self.focusesThatReorder.first { SuiteOnboarding.order(for: $0) == p.homeOrder }
        }
        rebuildStarters()
    }

    /// Last page: finish(); else the next page.
    public func `continue`() {
        guard sendingReason == nil else { return }
        guard isLastPage else { pageIndex += 1; return }
        isFinished = true
        Task { await finish() }
    }
    /// Help > Welcome to AfterGlow: SwiftUI keeps a closed Window's state, so a tour that finished
    /// starts over on page 1 with nothing held. A tour still open stays where it is.
    public func reopen() {
        guard isFinished else { return }
        pageIndex = 0; isFinished = false
        launching = nil; failed = nil; message = nil
    }
    public func back() {
        guard sendingReason == nil else { return }
        pageIndex = max(pageIndex - 1, 0)
    }

    /// Toggles the focus (the same one again clears it) and reorders the starters.
    public func choose(_ focus: OnboardingFocus?) {
        self.focus = self.focus == focus ? nil : focus
        rebuildStarters()
    }

    /// Skip, Escape or closing the window: records the version and leaves the stored home order
    /// (and the focus, so a hand-off still in flight finishes with it) as they are.
    public func skip() async {
        guard sendingReason == nil else { return }
        await save { stored in
            var next = stored
            next.onboardingDoneVersion = SuiteOnboarding.version
            return next
        }
    }

    /// Saves `finishing(focus:)`. The window closes either way.
    public func finish() async {
        await save { services.onboarding.finishing($0, focus: focus, version: SuiteOnboarding.version) }
    }

    /// A preset chip: sends the `.new` hand-off (as the home's New tile does), then finishes.
    public func startNew(_ preset: NewDocumentPreset, now: Date) async {
        guard await send(services.creating.handOff(for: preset, id: makeID(), at: now)) else { return }
        await finish()
    }

    /// Open sample: copies the bundle's sample into Documents/Samples (never over an earlier copy),
    /// sends the `.open` hand-off for that copy, then finishes. A sample that can't open sends nothing.
    public func openSample(_ app: SuiteApp, now: Date) async {
        let starter = starters.first { $0.tile.app == app }
        guard let sample = starter?.sample else { refuse(Self.sampleMissing(app), for: app); return }
        let source = samplesFolder + "/" + sample.fileName
        guard starter?.sampleReason == nil, present(source) else { refuse(Self.sampleMissing(app), for: app); return }
        guard let destination = SampleCatalog.destination(for: sample, documents: documents, exists: present) else {
            refuse(.ioFailed("Documents/Samples has no free name for \(sample.fileName)."), for: app); return
        }
        do throws(SuiteError) { try copy(source, destination) } catch { refuse(error, for: app); return }
        let handOff = HandOff(id: makeID(), from: .launcher, to: app, verb: .open,
                              documents: [SampleCatalog.ref(for: sample, path: destination)], createdAt: now)
        guard await send(handOff) else { return }
        await finish()
    }

    /// The focuses that move apps forward; `.everything` keeps the usual order, as no focus does.
    private static let focusesThatReorder: [OnboardingFocus] = OnboardingFocus.allCases.filter {
        SuiteOnboarding.order(for: $0) != SuiteOnboarding.order(for: nil)
    }

    /// The start page's sentence for a sample that can't open, the one its tile's help shows.
    private static func sampleMissing(_ app: SuiteApp) -> SuiteError {
        .notAvailable("The \(app.displayName) sample isn't in this build.")
    }

    /// Saves `change` of the stored preferences; a stale save reloads and saves once more. Closes the window.
    private func save(_ change: (SuitePreferences) -> SuitePreferences) async {
        do throws(SuiteError) {
            do throws(SuiteError) { try await saveOnce(change) } catch .staleRevision { try await saveOnce(change) }
        } catch { message = error; failed = nil }
        isFinished = true
    }

    private func saveOnce(_ change: (SuitePreferences) -> SuitePreferences) async throws(SuiteError) {
        let stored = (try? await services.preferences.load()) ?? SuitePreferences()
        _ = try await services.preferences.save(change(stored))
    }

    /// Sends one hand-off; true when it went. A refusal leaves its message and the window open.
    private func send(_ handOff: HandOff) async -> Bool {
        launching = handOff.to
        message = nil; failed = nil
        do throws(SuiteError) { _ = try await services.sending.send(handOff) } catch {
            launching = nil; refuse(error, for: handOff.to)
            return false
        }
        return true
    }

    /// A start that didn't go: its sentence, kept with the tile it belongs to.
    private func refuse(_ error: SuiteError, for app: SuiteApp) {
        message = error; failed = app
    }

    private func rebuildStarters() {
        let tiles = services.creating.tiles(missing: [])
        starters = SuiteOnboarding.order(for: focus).compactMap { app in
            guard let tile = tiles.first(where: { $0.app == app }) else { return nil }
            let sample = SampleCatalog.sample(for: app)
            let reason = sample.flatMap { SampleCatalog.reason(for: $0, folder: samplesFolder, present: present) }
            return OnboardingStarter(tile: tile, sample: sample, sampleReason: reason)
        }
    }
}
