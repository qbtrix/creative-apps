// OnboardingModelTests.swift: the welcome window's view-model on `.fake`
// (onboarding OB-8's acceptance row, written first by OB-2). Saves retry a
// stale write once; hand-offs finish the window; a sample copy never
// overwrites, and a starter that shows a reason opens nothing.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteModel
import Synchronization
import Testing

/// Every copy the model asks for, as [from, to].
final class SampleCopyLog: Sendable {
    private let pairs = Mutex<[[String]]>([])
    func record(_ from: String, _ to: String) { pairs.withLock { $0.append([from, to]) } }
    var all: [[String]] { pairs.withLock { $0 } }
}

/// A flag a `present` closure reads, so a sample can turn up or vanish after the starters were built.
final class SampleFlag: Sendable {
    private let raised = Mutex(false)
    func raise() { raised.withLock { $0 = true } }
    var isRaised: Bool { raised.withLock { $0 } }
}

/// Preferences another writer beats on the first `races` saves, so each of those is refused as stale.
actor RacingPreferences: PreferencesStoring {
    let inner = FakePreferences()
    private var races: Int
    private(set) var attempts = 0
    init(races: Int) { self.races = races }
    func load() async throws(SuiteError) -> SuitePreferences { try await inner.load() }
    func save(_ p: SuitePreferences) async throws(SuiteError) -> SuitePreferences {
        attempts += 1
        if races > 0 { races -= 1; _ = try await inner.save(try await inner.load()) }
        return try await inner.save(p)
    }
    func changes() async -> AsyncStream<Int> { await inner.changes() }
}

@MainActor @Suite(.timeLimit(.minutes(5))) struct OnboardingModelTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let log = SampleCopyLog()

    /// A loaded model whose bundle holds every sample (and nothing under /D unless `present` says so).
    func model(_ edit: (inout SuiteServices) -> Void = { _ in },
               present: @escaping @Sendable (String) -> Bool = { $0.hasPrefix("/R/Samples/") }) async -> (OnboardingModel, SuiteServices) {
        var s = SuiteServices.fake()
        edit(&s)
        let log = self.log
        let m = OnboardingModel(services: s, samplesFolder: "/R/Samples", documents: "/D", present: present,
                                copy: { log.record($0, $1) }, makeID: { "id-1" })
        await m.load()
        return (m, s)
    }

    func saved(_ s: SuiteServices) async throws -> SuitePreferences {
        try await #require(s.preferences as? FakePreferences).stored
    }

    func sent(_ s: SuiteServices) async throws -> [HandOff] {
        try await #require(s.sending as? FakeHandOffs).sent
    }

    func flareHD() throws -> NewDocumentPreset {
        try #require(SuiteCreating.presets[.flare]?.first { $0.id == "flare.hd" })
    }

    @Test func continueWalksThePagesAndTheThirdCallFinishes() async {
        let (m, _) = await model()
        m.continue()
        #expect(m.pageIndex == 1 && m.page.id == "focus" && m.canGoBack && !m.isFinished)
        m.continue()
        #expect(m.pageIndex == 2 && m.page.id == "start" && m.isLastPage && !m.isFinished)
        m.continue()
        #expect(m.pageIndex == 2 && m.isFinished)
    }

    @Test func backStopsAtTheFirstPage() async {
        let (m, _) = await model()
        m.back()
        #expect(m.pageIndex == 0 && !m.canGoBack)
        m.continue(); m.continue(); m.back()
        #expect(m.pageIndex == 1)
        m.back(); m.back()
        #expect(m.pageIndex == 0 && m.page.id == "apps")
    }

    @Test func chooseTogglesAndReordersTheStarters() async {
        let (m, _) = await model()
        #expect(m.starters.map(\.tile.app) == SuiteApp.apps)
        m.choose(.photos)
        #expect(m.focus == .photos && m.starters.map(\.tile.app) == SuiteOnboarding.order(for: .photos))
        m.choose(.photos)
        #expect(m.focus == nil && m.starters.map(\.tile.app) == SuiteOnboarding.order(for: nil))
        m.choose(.design); m.choose(.motion)
        #expect(m.focus == .motion && m.starters.map(\.tile.app) == SuiteOnboarding.order(for: .motion))
    }

    @Test func skipSavesTheVersionWithTheAppOrder() async throws {
        let (m, s) = await model()
        m.choose(.photos)
        await m.skip()
        let p = try await saved(s)
        #expect(p.onboardingDoneVersion == 1 && p.homeOrder == SuiteApp.apps)
        #expect(m.isFinished && m.message == nil)
    }

    @Test func skipOnAReopenedTourKeepsTheHomeOrder() async throws {
        let done = FakeOnboarding().finishing(SuitePreferences(), focus: .photos, version: 1)
        let (m, s) = await model { $0.preferences = FakePreferences(done) }
        await m.skip()
        let p = try await saved(s)
        #expect(p.onboardingDoneVersion == 1 && Array(p.homeOrder.prefix(2)) == [.library, .photo])
        #expect(m.isFinished && m.message == nil)
    }

    @Test func aHandOffThatLandsAfterTheWindowClosedKeepsTheFocus() async throws {
        let done = FakeOnboarding().finishing(SuitePreferences(), focus: .photos, version: 1)
        let (m, s) = await model { $0.preferences = FakePreferences(done) }
        await m.skip()
        await m.openSample(.flare, now: now)
        #expect(try await sent(s).count == 1)
        #expect(Array(try await saved(s).homeOrder.prefix(2)) == [.library, .photo])
    }

    @Test func aMissingSampleSaysItIsNotInThisBuild() async throws {
        let (m, _) = await model(present: { $0.hasPrefix("/R/Samples/") && !$0.hasSuffix(".flare") })
        await m.openSample(.flare, now: now)
        #expect(m.message?.message == "The Flare sample isn't in this build.")
    }

    @Test func finishAfterPhotosSavesLibraryAndPhotoFirst() async throws {
        let (m, s) = await model()
        m.choose(.photos)
        await m.finish()
        let p = try await saved(s)
        #expect(p.onboardingDoneVersion == SuiteOnboarding.version && p.revision == 1)
        #expect(Array(p.homeOrder.prefix(2)) == [.library, .photo])
        #expect(m.isFinished && m.message == nil)
    }

    @Test func aStaleSaveReloadsAndSavesOnceMore() async throws {
        let racing = RacingPreferences(races: 1)
        let (m, _) = await model { $0.preferences = racing }
        m.choose(.photos)
        await m.finish()
        #expect(await racing.attempts == 2)
        let p = await racing.inner.stored
        #expect(p.onboardingDoneVersion == 1 && p.revision == 2)
        #expect(Array(p.homeOrder.prefix(2)) == [.library, .photo])
        #expect(m.isFinished && m.message == nil)
    }

    @Test func aSecondStaleSaveShowsTheMessageAndStillCloses() async {
        let racing = RacingPreferences(races: 2)
        let (m, _) = await model { $0.preferences = racing }
        await m.finish()
        #expect(await racing.attempts == 2)
        #expect(await racing.inner.stored.onboardingDoneVersion == nil)
        #expect(m.message == .staleRevision && m.isFinished)
    }

    @Test func startNewSendsOneNewHandOffThenFinishes() async throws {
        let (m, s) = await model()
        let preset = try flareHD()
        await m.startNew(preset, now: now)
        #expect(try await sent(s) == [s.creating.handOff(for: preset, id: "id-1", at: now)])
        #expect(try await sent(s).first?.verb == .new && m.launching == .flare)
        #expect(try await saved(s).onboardingDoneVersion == 1)
        #expect(m.isFinished && m.message == nil)
    }

    @Test func openSampleCopiesThenSendsOneOpenAndFinishes() async throws {
        let (m, s) = await model()
        let sample = try #require(SampleCatalog.sample(for: .flare))
        await m.openSample(.flare, now: now)
        #expect(log.all == [["/R/Samples/Bounce.flare", "/D/Samples/Bounce.flare"]])
        let handOffs = try await sent(s)
        #expect(handOffs.count == 1)
        let h = try #require(handOffs.first)
        #expect(h.id == "id-1" && h.from == .launcher && h.to == .flare && h.verb == .open && h.createdAt == now)
        #expect(h.documents == [SampleCatalog.ref(for: sample, path: "/D/Samples/Bounce.flare")])
        #expect(m.isFinished && m.message == nil)
    }

    /// Home's RECENT lists the copy even when its app doesn't note its own opens yet (Design, #5947 OJ2).
    @Test func openSampleNotesTheCopyInRecents() async throws {
        let (m, s) = await model()
        let sample = try #require(SampleCatalog.sample(for: .design))
        await m.openSample(.design, now: now)
        let items = try await s.recents.list().items
        #expect(items.map(\.ref) == [SampleCatalog.ref(for: sample, path: "/D/Samples/Cards.design")])
        #expect(items.first?.lastUsed == now)
    }

    @Test func openSampleThatIsRefusedNotesNothing() async throws {
        let (m, s) = await model { $0.sending = FakeHandOffs(unavailable: "Design can't do that yet.") }
        await m.openSample(.design, now: now)
        #expect(try await s.recents.list().items.isEmpty)
        #expect(!m.isFinished)
    }

    @Test func openSampleNeverOverwritesAnEarlierCopy() async throws {
        let (m, s) = await model(present: { $0.hasPrefix("/R/Samples/") || $0 == "/D/Samples/Bounce.flare" })
        await m.openSample(.flare, now: now)
        #expect(log.all == [["/R/Samples/Bounce.flare", "/D/Samples/Bounce 2.flare"]])
        #expect(try await sent(s).first?.documents.map(\.path) == ["/D/Samples/Bounce 2.flare"])
    }

    @Test func openSampleWithAReasonRecordsNothing() async throws {
        let shipped = SampleFlag()
        let (m, s) = await model(present: { $0.hasPrefix("/R/Samples/") && (!$0.hasSuffix(".halo") || shipped.isRaised) })
        #expect(m.starters.first { $0.tile.app == .halo }?.sampleReason != nil)
        await m.openSample(.halo, now: now)
        #expect(log.all.isEmpty)
        #expect(try await sent(s).isEmpty)
        #expect(m.message != nil && !m.isFinished)
        // The tile still shows its reason, so the file turning up later opens nothing either.
        shipped.raise()
        await m.openSample(.halo, now: now)
        #expect(log.all.isEmpty)
        #expect(try await sent(s).isEmpty)
        #expect(m.message != nil && !m.isFinished && m.launching == nil)
    }

    @Test func aRefusedHandOffKeepsTheWindowOpen() async throws {
        let refusal = "Switching isn't available yet."
        let (m, s) = await model { $0.sending = FakeHandOffs(unavailable: refusal) }
        await m.startNew(try flareHD(), now: now)
        #expect(m.message == .notAvailable(refusal) && !m.isFinished && m.launching == nil)
        #expect(try await saved(s).onboardingDoneVersion == nil)
        await m.openSample(.flare, now: now)
        #expect(m.message == .notAvailable(refusal) && !m.isFinished && m.launching == nil)
    }

    @Test func aSendAfterARefusalClearsTheOldSentence() async throws {
        let gate = GateSending()
        let (m, _) = await model { $0.sending = gate }
        let preset = try flareHD()
        let refused = Task { await m.startNew(preset, now: now) }
        await gate.waitUntilWaiting()
        await gate.finish(.failure(.timedOut))
        await refused.value
        #expect(m.message == .timedOut && m.launching == nil && !m.isFinished)
        let next = Task { await m.openSample(.design, now: now) }
        await gate.waitUntilWaiting()
        #expect(m.message == nil && m.failed == nil && m.launching == .design)
        await gate.finish(.success(SwitchReceipt(app: .design, wasRunning: false, requestedAt: 1)))
        await next.value
        #expect(m.message == nil && m.isFinished)
        #expect(await gate.sent.map(\.to) == [.flare, .design])
    }

    @Test func openSampleWhoseFileIsGoneRecordsNothing() async throws {
        let (m, s) = await model(present: { $0.hasPrefix("/R/Samples/") && !$0.hasSuffix(".flare") })
        await m.openSample(.flare, now: now)
        #expect(log.all.isEmpty)
        #expect(try await sent(s).isEmpty)
        #expect(m.message == .notAvailable("The Flare sample isn't in this build.") && !m.isFinished && m.launching == nil)
    }

    @Test func openSampleWhoseFileVanishedAfterLoadRecordsNothing() async throws {
        let removed = SampleFlag()
        let (m, s) = await model(present: { $0.hasPrefix("/R/Samples/") && !($0.hasSuffix(".flare") && removed.isRaised) })
        #expect(m.starters.first { $0.tile.app == .flare }?.sampleReason == nil)
        removed.raise()
        await m.openSample(.flare, now: now)
        #expect(log.all.isEmpty)
        #expect(try await sent(s).isEmpty)
        #expect(m.message == .notAvailable("The Flare sample isn't in this build.") && !m.isFinished && m.launching == nil)
    }

    @Test func openSampleWithNoFreeNameRefusesUnderItsTile() async throws {
        let (m, s) = await model(present: { _ in true })
        await m.openSample(.flare, now: now)
        #expect(log.all.isEmpty)
        #expect(try await sent(s).isEmpty)
        #expect(m.message == .ioFailed("Documents/Samples has no free name for Bounce.flare."))
        #expect(m.failed == .flare && !m.isFinished && m.launching == nil)
    }

    @Test func aRefusedCopySendsNothing() async throws {
        let s = SuiteServices.fake()
        let m = OnboardingModel(services: s, samplesFolder: "/R/Samples", documents: "/D", present: { $0.hasPrefix("/R/") },
                                copy: { _, _ throws(SuiteError) in throw .ioFailed("the sample") }, makeID: { "id-1" })
        await m.load()
        await m.openSample(.design, now: now)
        #expect(try await sent(s).isEmpty)
        #expect(m.message == .ioFailed("the sample") && !m.isFinished)
    }

    @Test func loadRestoresTheSavedFocus() async throws {
        let done = FakeOnboarding().finishing(SuitePreferences(), focus: .photos, version: 1)
        let (m, _) = await model { $0.preferences = FakePreferences(done) }
        #expect(m.focus == .photos && m.starters.map(\.tile.app) == SuiteOnboarding.order(for: .photos))
        let skipped = FakeOnboarding().finishing(SuitePreferences(), focus: nil, version: 1)
        let (n, _) = await model { $0.preferences = FakePreferences(skipped) }
        #expect(n.focus == nil)
        var unset = SuitePreferences()
        unset.homeOrder = SuiteOnboarding.order(for: .design)
        let (o, _) = await model { $0.preferences = FakePreferences(unset) }
        #expect(o.focus == nil)
    }

    @Test func continueOnTheLastPageSavesTheVersion() async throws {
        let (m, s) = await model()
        let saves = await s.preferences.changes()
        m.choose(.design)
        m.continue(); m.continue(); m.continue()
        #expect(m.isFinished)
        for await _ in saves where try await saved(s).onboardingDoneVersion != nil { break }
        #expect(try await saved(s).onboardingDoneVersion == 1)
        #expect(try await saved(s).homeOrder.first == .design)
    }

    @Test func skipBackAndContinueHoldWhileAHandOffSends() async throws {
        let gate = GateSending()
        let (m, s) = await model { $0.sending = gate }
        m.continue(); m.continue()
        #expect(m.isLastPage && m.sendingReason == nil)
        let preset = try flareHD()
        let send = Task { await m.startNew(preset, now: now) }
        await gate.waitUntilWaiting()
        #expect(m.launching == .flare && m.sendingReason == "A document is opening.")
        m.back(); m.continue()
        await m.skip()
        #expect(m.pageIndex == 2 && !m.isFinished)
        #expect(try await saved(s).onboardingDoneVersion == nil)
        await gate.finish(.failure(.timedOut))
        await send.value
        #expect(m.sendingReason == nil && !m.isFinished)
        m.back()
        #expect(m.pageIndex == 1)
    }

    /// #3018: every control held by a hand-off says why in its help, and says what it does otherwise.
    @Test func everyHeldControlsHelpSaysADocumentIsOpening() async throws {
        let gate = GateSending()
        let (m, _) = await model({ $0.sending = gate }, present: { $0.hasPrefix("/R/Samples/") && !$0.contains("Bounce") })
        m.continue(); m.continue()
        let flare = try #require(m.starters.first { $0.tile.app == .flare })
        let design = try #require(m.starters.first { $0.tile.app == .design })
        let missing = "The Flare sample isn't in this build."
        #expect(m.skipHelp == "Close the welcome window. Help > Welcome to AfterGlow opens it again.")
        #expect(m.backHelp == "Go back to the previous page.")
        #expect(m.startEmptyHelp == "Close the welcome window and go to the home with nothing open.")
        #expect(m.presetsHelp(design.tile) == SuiteOnboarding.presetsHelp(design.tile))
        #expect(m.sampleUnavailable(design) == nil && m.sampleHelp(design) == "Open \(design.sample?.title ?? "") in Design.")
        #expect(m.sampleUnavailable(flare) == missing && m.sampleHelp(flare) == missing)
        let bare = OnboardingStarter(tile: design.tile, sample: nil, sampleReason: nil)
        #expect(m.sampleUnavailable(bare) == "The Design sample isn't in this build.")
        let blocked = NewTile(app: .halo, title: "New Composition", presets: [], disabledReason: "Halo isn't installed.")
        #expect(m.presetsHelp(blocked) == "Halo isn't installed.")
        let preset = try flareHD()
        let send = Task { await m.startNew(preset, now: now) }
        await gate.waitUntilWaiting()
        let opening = "A document is opening."
        #expect([m.skipHelp, m.backHelp, m.startEmptyHelp, m.presetsHelp(design.tile), m.sampleHelp(design)]
            == Array(repeating: opening, count: 5))
        #expect(m.sampleUnavailable(design) == opening && m.sampleHelp(flare) == missing)
        #expect(m.presetsHelp(blocked) == "Halo isn't installed.")
        await gate.finish(.failure(.timedOut))
        await send.value
        #expect(m.skipHelp != opening && m.sampleUnavailable(design) == nil)
    }

    @Test func aRefusedHandOffKeepsItsTile() async throws {
        let refusal = "Switching isn't available yet."
        let (m, _) = await model { $0.sending = FakeHandOffs(unavailable: refusal) }
        #expect(m.failed == nil)
        await m.openSample(.design, now: now)
        #expect(m.message == .notAvailable(refusal) && m.failed == .design && m.launching == nil)
        await m.startNew(try flareHD(), now: now)
        #expect(m.message == .notAvailable(refusal) && m.failed == .flare)
    }

    @Test func aSampleThatCantOpenKeepsItsTileAndTheNextStartClearsIt() async throws {
        let (m, _) = await model(present: { $0.hasPrefix("/R/Samples/") && !$0.hasSuffix(".flare") })
        await m.openSample(.flare, now: now)
        #expect(m.message == .notAvailable("The Flare sample isn't in this build.") && m.failed == .flare)
        await m.openSample(.design, now: now)
        #expect(m.message == nil && m.failed == nil && m.isFinished)
    }

    /// Help > Welcome to AfterGlow on a window SwiftUI kept: the tour starts over on page 1, unheld,
    /// and Skip closes it again (#5947: the reopened window read "start" and Escape left it open).
    @Test func reopenAfterAFinishStartsOverOnTheFirstPage() async throws {
        let (m, _) = await model()
        m.continue(); m.continue()
        await m.openSample(.flare, now: now)
        #expect(m.isFinished && m.launching == .flare)
        m.reopen()
        #expect(m.pageIndex == 0 && m.page.id == "apps" && !m.isFinished)
        #expect(m.launching == nil && m.sendingReason == nil && m.message == nil && m.failed == nil)
        await m.skip()
        #expect(m.isFinished)
    }

    @Test func reopenLeavesAnOpenTourWhereItIs() async {
        let (m, _) = await model()
        m.continue()
        m.reopen()
        #expect(m.pageIndex == 1 && !m.isFinished)
    }
}
