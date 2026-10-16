// HomeModelTests.swift: HomeModel on `.fake` (home packet HM-1b's acceptance row).
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteModel
import Testing

/// A sender that holds each send until the test finishes it.
actor GateSending: HandOffSending {
    private var waiter: CheckedContinuation<Result<SwitchReceipt, SuiteError>, Never>?
    private(set) var sent: [HandOff] = []
    var isWaiting: Bool { waiter != nil }
    func send(_ handOff: HandOff) async throws(SuiteError) -> SwitchReceipt {
        sent.append(handOff)
        let result = await withCheckedContinuation { waiter = $0 }
        return try result.get()
    }
    func finish(_ result: Result<SwitchReceipt, SuiteError>) { waiter?.resume(returning: result); waiter = nil }
}

@MainActor @Suite(.timeLimit(.minutes(1))) struct HomeModelTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let docs = "/tmp/Documents"
    var cardsPath: String { docs + "/Cards.design" }
    var logoID: String { SuiteDocumentRef.fileID(forPath: docs + "/Logo.design") }

    func week() throws -> RecentsList {
        try #require(SuiteFixtures.store("weekOfWork", documents: docs, now: now)).recents
    }

    /// weekOfWork on `.fake` with Cards.design missing on disk.
    func model(_ edit: (inout SuiteServices) -> Void = { _ in },
               makeID: @escaping @Sendable () -> String = HandOff.newID) async throws -> (HomeModel, SuiteServices) {
        var s = SuiteServices.fake(recents: try week())
        edit(&s)
        let missing = cardsPath
        let m = HomeModel(services: s, fileExists: { $0 != missing }, makeID: makeID)
        await m.reload(now: now)
        return (m, s)
    }

    func sent(_ s: SuiteServices) async throws -> [HandOff] {
        try await #require(s.sending as? FakeHandOffs).sent
    }

    @Test func reloadSearchAndFilter() async throws {
        let (m, _) = try await model()
        #expect(m.state.cards.count == 8)
        #expect(m.state.cards.filter(\.isMissing).map(\.item.ref.displayName) == ["Cards.design"])
        #expect(m.state.tiles.map(\.app) == SuiteApp.apps)
        #expect(m.message == nil)
        m.search("logo", now: now)
        #expect(m.state.cards.count == 2)
        m.filter(.design, now: now)
        #expect(m.query == "logo" && m.filter == .design)
        #expect(m.state.cards.map(\.item.ref.displayName) == ["Logo.design"])
    }

    @Test func homeOrderOrdersTheTilesAndNotConnectedKeepsTheDefaultSilently() async throws {
        let (m, _) = try await model { $0.preferences = FakePreferences(SuitePreferences(homeOrder: [.library, .photo])) }
        #expect(m.state.tiles.map(\.app) == [.library, .photo, .flare, .design, .halo])
        let reason = try #require(SuiteServices.notConnected("preferences"))
        let (off, _) = try await model { $0.preferences = FakePreferences(unavailable: reason) }
        #expect(off.state.tiles.map(\.app) == SuiteApp.apps && off.message == nil)
    }

    @Test func recentsFailureIsTheMessageAndPendingSendingDisablesTiles() async throws {
        let (m, _) = try await model { $0.recents = FakeRecents(unavailable: "Recents are off.") }
        #expect(m.message == .notAvailable("Recents are off.") && m.state.cards.isEmpty)
        let reason = try #require(SuiteServices.notConnected("sending"))
        let (p, _) = try await model { $0.pending = ["sending": reason] }
        #expect(p.state.tiles.allSatisfy { $0.disabledReason == reason })
    }

    @Test func openingAMissingCardSaysSoAndSendsNothing() async throws {
        let (m, s) = try await model()
        m.select(SuiteDocumentRef.fileID(forPath: cardsPath))
        await m.openSelection(now: now)
        #expect(m.message?.message == "Cards.design was moved or deleted.")
        #expect(try await sent(s).isEmpty)
    }

    @Test func openingAPresentCardSendsOneOpenWithTheInjectedID() async throws {
        let (m, s) = try await model(makeID: { "id-from-test" })
        m.select(logoID)
        await m.openSelection(now: now)
        let logo = try #require(m.state.cards.first { $0.item.ref.fileID == logoID }).item.ref
        #expect(try await sent(s) == [HandOff(id: "id-from-test", from: .launcher, to: .design, verb: .open,
                                              documents: [logo], createdAt: now)])
    }

    @Test func twoOpensSendTwoIDs() async throws {
        let (m, s) = try await model()
        m.select(logoID)
        await m.openSelection(now: now)
        await m.openSelection(now: now)
        let ids = try await sent(s).map(\.id)
        #expect(ids.count == 2 && Set(ids).count == 2)
    }

    @Test func removeThenUndoRestoresTheCard() async throws {
        let (m, s) = try await model()
        let before = try #require(m.state.cards.first { $0.item.ref.fileID == logoID })
        m.select(logoID)
        await m.removeSelection(now: now)
        let stored = try await s.recents.list().items.count
        #expect(m.state.cards.count == 7 && stored == 7)
        await m.undoRemove(now: now)
        #expect(m.state.cards.count == 8)
        let after = try #require(m.state.cards.first { $0.item.ref.fileID == logoID })
        #expect(after.item == before.item && after.item.thumbnail != nil)
    }

    @Test func locateRePointsTheMissingCard() async throws {
        let (m, s) = try await model()
        let old = SuiteDocumentRef.fileID(forPath: cardsPath)
        let thumbnail = m.state.cards.first { $0.item.ref.fileID == old }?.item.thumbnail
        await m.locate(old, newPath: "/tmp/Moved/Cards.design", now: now)
        let ids = try await s.recents.list().items.map(\.ref.fileID)
        #expect(!ids.contains(old))
        let card = try #require(m.state.cards.first { $0.item.ref.fileID == SuiteDocumentRef.fileID(forPath: "/tmp/Moved/Cards.design") })
        #expect(!card.isMissing && card.item.thumbnail == thumbnail)
        #expect(m.state.cards.count == 8 && m.state.cards.allSatisfy { !$0.isMissing })
    }

    @Test func thumbnailStepsClamp() async throws {
        let (m, _) = try await model()
        for _ in 0..<5 { m.larger() }
        #expect(m.thumbnailStep == 3)
        for _ in 0..<5 { m.smaller() }  // and stops at 0
        #expect(m.thumbnailStep == 0)
    }

    @Test func launchingWhileASendWaits() async throws {
        let gate = GateSending()
        let (m, _) = try await model { $0.sending = gate }
        m.select(logoID)
        let open = Task { await m.openSelection(now: now) }
        while !(await gate.isWaiting) { await Task.yield() }
        #expect(m.launching == .design)
        await gate.finish(.success(SwitchReceipt(app: .design, wasRunning: false, requestedAt: 1)))
        await open.value
        #expect(m.launching == nil && m.message == nil)
    }

    @Test func newSendsTheCreatingHandOffAndSetsLaunchingUntilAnError() async throws {
        let gate = GateSending()
        let (m, _) = try await model({ $0.sending = gate }, makeID: { "new-id" })
        let preset = try #require(SuiteCreating.presets[.halo]?.first)
        let new = Task { await m.newDocument(preset, now: now) }
        while !(await gate.isWaiting) { await Task.yield() }
        let sent = await gate.sent
        #expect(m.launching == .halo && sent == [SuiteCreating().handOff(for: preset, id: "new-id", at: now)])
        await gate.finish(.failure(.timedOut))
        await new.value
        #expect(m.launching == nil && m.message == .timedOut)
    }

    @Test func switchToARunningAppAndAMissingOne() async throws {
        let (m, _) = try await model { $0 = .fake(recents: (try? week()) ?? RecentsList(), running: [.flare], missing: [.halo]) }
        #expect(m.state.running == [.flare] && m.state.tiles.first { $0.app == .halo }?.disabledReason == SuiteError.appMissing(.halo).message)
        await m.switchTo(.halo)
        #expect(m.message == .appMissing(.halo) && m.launching == nil)
    }

    @Test func observeReloadsWhenRecentsChange() async throws {
        let (m, s) = try await model()
        let watch = Task { await m.observe(now: { [now] in now }) }
        while m.state.cards.count != 7 {
            try await s.recents.remove(fileID: logoID)
            await Task.yield()
        }
        watch.cancel()
    }
}
