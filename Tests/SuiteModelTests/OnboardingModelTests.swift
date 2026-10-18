// OnboardingModelTests.swift: the welcome window's view-model on `.fake`
// (onboarding OB-8's acceptance row, written first by OB-2; disabled until
// OB-8's body). Saves retry a stale write once; hand-offs finish the window.
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

@MainActor @Suite(.timeLimit(.minutes(1))) struct OnboardingModelTests {
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

    @Test(.disabled("waits on OB-8")) func continueWalksThePagesAndTheThirdCallFinishes() async {
        let (m, _) = await model()
        m.continue()
        #expect(m.pageIndex == 1 && m.page.id == "focus" && m.canGoBack && !m.isFinished)
        m.continue()
        #expect(m.pageIndex == 2 && m.page.id == "start" && m.isLastPage && !m.isFinished)
        m.continue()
        #expect(m.pageIndex == 2 && m.isFinished)
    }

    @Test(.disabled("waits on OB-8")) func backStopsAtTheFirstPage() async {
        let (m, _) = await model()
        m.back()
        #expect(m.pageIndex == 0 && !m.canGoBack)
        m.continue(); m.continue(); m.back()
        #expect(m.pageIndex == 1)
        m.back(); m.back()
        #expect(m.pageIndex == 0 && m.page.id == "apps")
    }

    @Test(.disabled("waits on OB-8")) func chooseTogglesAndReordersTheStarters() async {
        let (m, _) = await model()
        #expect(m.starters.map(\.tile.app) == SuiteApp.apps)
        m.choose(.photos)
        #expect(m.focus == .photos && m.starters.map(\.tile.app) == SuiteOnboarding.order(for: .photos))
        m.choose(.photos)
        #expect(m.focus == nil && m.starters.map(\.tile.app) == SuiteOnboarding.order(for: nil))
        m.choose(.design); m.choose(.motion)
        #expect(m.focus == .motion && m.starters.map(\.tile.app) == SuiteOnboarding.order(for: .motion))
    }

    @Test(.disabled("waits on OB-8")) func skipSavesTheVersionWithTheAppOrder() async throws {
        let (m, s) = await model()
        m.choose(.photos)
        await m.skip()
        let p = try await saved(s)
        #expect(p.onboardingDoneVersion == 1 && p.homeOrder == SuiteApp.apps)
        #expect(m.isFinished && m.focus == nil && m.message == nil)
    }

    @Test(.disabled("waits on OB-8")) func finishAfterPhotosSavesLibraryAndPhotoFirst() async throws {
        let (m, s) = await model()
        m.choose(.photos)
        await m.finish()
        let p = try await saved(s)
        #expect(p.onboardingDoneVersion == SuiteOnboarding.version && p.revision == 1)
        #expect(Array(p.homeOrder.prefix(2)) == [.library, .photo])
        #expect(m.isFinished && m.message == nil)
    }

    @Test(.disabled("waits on OB-8")) func aStaleSaveReloadsAndSavesOnceMore() async throws {
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

    @Test(.disabled("waits on OB-8")) func aSecondStaleSaveShowsTheMessageAndStillCloses() async {
        let racing = RacingPreferences(races: 2)
        let (m, _) = await model { $0.preferences = racing }
        await m.finish()
        #expect(await racing.attempts == 2)
        #expect(await racing.inner.stored.onboardingDoneVersion == nil)
        #expect(m.message == .staleRevision && m.isFinished)
    }

    @Test(.disabled("waits on OB-8")) func startNewSendsOneNewHandOffThenFinishes() async throws {
        let (m, s) = await model()
        let preset = try flareHD()
        await m.startNew(preset, now: now)
        #expect(try await sent(s) == [s.creating.handOff(for: preset, id: "id-1", at: now)])
        #expect(try await sent(s).first?.verb == .new && m.launching == .flare)
        #expect(try await saved(s).onboardingDoneVersion == 1)
        #expect(m.isFinished && m.message == nil)
    }

    @Test(.disabled("waits on OB-8")) func openSampleCopiesThenSendsOneOpenAndFinishes() async throws {
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

    @Test(.disabled("waits on OB-8")) func openSampleNeverOverwritesAnEarlierCopy() async throws {
        let (m, s) = await model(present: { $0.hasPrefix("/R/Samples/") || $0 == "/D/Samples/Bounce.flare" })
        await m.openSample(.flare, now: now)
        #expect(log.all == [["/R/Samples/Bounce.flare", "/D/Samples/Bounce 2.flare"]])
        #expect(try await sent(s).first?.documents.map(\.path) == ["/D/Samples/Bounce 2.flare"])
    }

    @Test(.disabled("waits on OB-8")) func openSampleWithAReasonRecordsNothing() async throws {
        let (m, s) = await model(present: { $0.hasPrefix("/R/Samples/") && !$0.hasSuffix(".halo") })
        #expect(m.starters.first { $0.tile.app == .halo }?.sampleReason != nil)
        await m.openSample(.halo, now: now)
        #expect(log.all.isEmpty)
        #expect(try await sent(s).isEmpty)
        #expect(m.message != nil && !m.isFinished)
    }

    @Test(.disabled("waits on OB-8")) func aRefusedHandOffKeepsTheWindowOpen() async throws {
        let refusal = "Switching isn't available yet."
        let (m, s) = await model { $0.sending = FakeHandOffs(unavailable: refusal) }
        await m.startNew(try flareHD(), now: now)
        #expect(m.message == .notAvailable(refusal) && !m.isFinished)
        #expect(try await saved(s).onboardingDoneVersion == nil)
        await m.openSample(.flare, now: now)
        #expect(m.message == .notAvailable(refusal) && !m.isFinished)
    }
}
