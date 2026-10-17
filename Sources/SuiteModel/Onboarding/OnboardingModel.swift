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

    /// The pages and the starters; OB-8 adds the saved focus from the preferences' homeOrder.
    public func load() async {
        pages = services.onboarding.pages
        rebuildStarters()
    }

    /// Last page: finish(); else the next page.
    public func `continue`() { if isLastPage { isFinished = true } else { pageIndex += 1 } }
    public func back() { pageIndex = max(pageIndex - 1, 0) }

    /// Toggles the focus (the same one again clears it) and reorders the starters.
    public func choose(_ focus: OnboardingFocus?) {
        self.focus = self.focus == focus ? nil : focus
        rebuildStarters()
    }

    /// Finishes with no focus; OB-8 saves the version.
    public func skip() async { focus = nil; isFinished = true }
    /// Finishes; OB-8 saves `finishing(focus:)` with one stale retry.
    public func finish() async { isFinished = true }
    /// A preset chip; OB-8 sends the `.new` hand-off before finishing.
    public func startNew(_ preset: NewDocumentPreset, now: Date) async { launching = preset.app; isFinished = true }
    /// Open sample; OB-8 copies the file and sends the `.open` hand-off before finishing.
    public func openSample(_ app: SuiteApp, now: Date) async { launching = app; isFinished = true }

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
