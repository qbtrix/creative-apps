// OnboardingStubTests.swift: MJ-OB0, the onboarding contract slice (OB-1).
// The stubs return the fake's values, and every public signature is pinned
// to a typed function value so a drift stops this file compiling.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteModel
import Testing

@Suite(.timeLimit(.minutes(1))) struct OnboardingStubTests {
    @Test func suiteOnboardingReturnsTheFakesPagesAndTheRenderingLine() {
        #expect(SuiteOnboarding().pages == FakeOnboarding().pages)
        #expect(SuiteOnboarding.renderingNote.contains("View > Rendering"))
        #expect(SuiteOnboarding.renderingNote.contains("CPU"))
        #expect(SuiteOnboarding.order(for: nil) == SuiteApp.apps)
        #expect(SuiteOnboarding.order(for: .photos).prefix(2) == [.library, .photo])
    }

    @Test func launchPresentsUnlessTheSkipFlagSaysYes() {
        #expect(OnboardingLaunch.presents(arguments: [], stored: nil, flow: SuiteOnboarding()))
        #expect(!OnboardingLaunch.presents(arguments: ["-SuiteSkipOnboarding", "YES"], stored: nil, flow: SuiteOnboarding()))
        #expect(OnboardingLaunch.skipFlag == "-SuiteSkipOnboarding")
    }

    @Test func controlIdentifiers() {
        #expect(OnboardingControls.focus(.photos) == "afterglow.onboarding.focus.photos")
        #expect(OnboardingControls.sample(.flare) == "afterglow.onboarding.sample.flare")
        let preset = NewDocumentPreset(id: "flare.hd", app: .flare, title: "1080p 16:9", detail: "")
        #expect(OnboardingControls.preset(preset) == "afterglow.onboarding.new.flare.hd")
        #expect(OnboardingControls.page == "afterglow.onboarding.page")
        #expect(OnboardingLayout.width == 720 && OnboardingLayout.height == 520 && OnboardingLayout.margin == 24)
    }

    @Test func sampleCatalogNamesOneSamplePerApp() {
        #expect(SampleCatalog.samples.map(\.app) == SuiteApp.apps)
        #expect(SampleCatalog.sample(for: .flare)?.fileName == "Bounce.flare")
        #expect(SampleCatalog.folder(resources: "/R") == "/R/Samples")
    }

    @Test func storePreferencesOnAnEmptyFolderLoadsDefaults() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("OnboardingStubTests-\(UUID().uuidString)").path
        let prefs = StorePreferences(store: FileStore(folder: folder))
        #expect(try await prefs.load() == SuitePreferences())
    }

    @MainActor @Test func modelLoadsFiveStartersInAppOrder() async {
        let m = OnboardingModel(services: .fake(), samplesFolder: "/R/Samples", documents: "/D",
                                present: { _ in true }, copy: { _, _ in })
        await m.load()
        #expect(m.starters.map(\.tile.app) == SuiteApp.apps)
        #expect(m.starters.map(\.tile.title) == SuiteApp.apps.map { SuiteCreating.titles[$0] })
        #expect(m.starters.allSatisfy { $0.sample != nil && $0.sampleReason == nil })
        #expect(m.pages == FakeOnboarding().pages)
        #expect(m.page.id == "apps" && !m.canGoBack && !m.isLastPage && !m.isFinished)
        #expect(m.renderingNote == SuiteOnboarding.renderingNote)
    }

    @Test func signaturePins() async throws {
        let presents: ([String], SuitePreferences?, any OnboardingFlowing, Int) -> Bool = OnboardingLaunch.presents(arguments:stored:flow:version:)
        let stored: (FileStore) -> SuitePreferences? = OnboardingLaunch.stored(in:)
        let shouldShow: (SuiteOnboarding) -> (SuitePreferences, Int) -> Bool = SuiteOnboarding.shouldShow
        let finishing: (SuiteOnboarding) -> (SuitePreferences, OnboardingFocus?, Int) -> SuitePreferences = SuiteOnboarding.finishing
        let order: (OnboardingFocus?) -> [SuiteApp] = SuiteOnboarding.order(for:)
        let sample: (SuiteApp) -> SampleFile? = SampleCatalog.sample(for:)
        let folder: (String) -> String = SampleCatalog.folder(resources:)
        let reason: (SampleFile, String, (String) -> Bool) -> String? = SampleCatalog.reason(for:folder:present:)
        let destination: (SampleFile, String, (String) -> Bool) -> String = SampleCatalog.destination(for:documents:exists:)
        let ref: (SampleFile, String) -> SuiteDocumentRef = SampleCatalog.ref(for:path:)
        let ids: [(OnboardingFocus) -> String] = [OnboardingControls.focus(_:)]
        let presetID: (NewDocumentPreset) -> String = OnboardingControls.preset(_:)
        let sampleID: (SuiteApp) -> String = OnboardingControls.sample(_:)
        let makePrefs: (FileStore, @escaping @Sendable (String) -> Void) -> StorePreferences = StorePreferences.init(store:onWrite:)
        let p = makePrefs(FileStore(folder: "/tmp/OnboardingStubTests-unused"), { _ in })
        let load: () async throws(SuiteError) -> SuitePreferences = { try await p.load() }
        let save: (SuitePreferences) async throws(SuiteError) -> SuitePreferences = { try await p.save($0) }
        let changes: () async -> AsyncStream<Int> = { await p.changes() }
        let external: () async -> Void = { await p.externalChange() }
        let make: @MainActor (SuiteServices, String, String, @escaping @Sendable (String) -> Bool,
                              @escaping @Sendable (String, String) throws(SuiteError) -> Void,
                              @escaping @Sendable () -> String) -> OnboardingModel
            = OnboardingModel.init(services:samplesFolder:documents:present:copy:makeID:)
        _ = (presents, stored, shouldShow, finishing, order, sample, folder, reason, destination, ref, ids, presetID, sampleID)
        _ = (load, save, changes, external, make)
        try await modelPins(await make(.fake(), "/R", "/D", { _ in true }, { _, _ in }, HandOff.newID))
    }

    @MainActor private func modelPins(_ m: OnboardingModel) async throws {
        let load: @MainActor () async -> Void = m.load
        let next: @MainActor () -> Void = m.continue
        let back: @MainActor () -> Void = m.back
        let choose: @MainActor (OnboardingFocus?) -> Void = m.choose(_:)
        let skip: @MainActor () async -> Void = m.skip
        let finish: @MainActor () async -> Void = m.finish
        let startNew: @MainActor (NewDocumentPreset, Date) async -> Void = m.startNew(_:now:)
        let openSample: @MainActor (SuiteApp, Date) async -> Void = m.openSample(_:now:)
        await load(); next(); back(); choose(.photos); choose(.photos)
        #expect(m.pageIndex == 0 && m.focus == nil)
        _ = (skip, finish, startNew, openSample)
        let launching: SuiteApp? = m.launching
        let message: SuiteError? = m.message
        #expect(launching == nil && message == nil)
    }
}
