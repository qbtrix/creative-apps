// FakesTier1Tests.swift: the tier-1 fakes behave as blueprint 5.5 states:
// switching refuses a missing app and reports a quit, recents keep a
// thumbnail, routing covers weekOfWork, hand-offs switch the target,
// thumbnails are named by fileKey, home's messages, a host's refusal, and
// `unavailable:` turns every throwing call into that sentence.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteModel
import Testing

@Suite struct FakesTier1Tests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let reason = "Not connected yet (suite-contracts)."

    func ref(_ name: String, _ app: SuiteApp = .design, _ type: SuiteTypeID = .designDocument) -> SuiteDocumentRef {
        let path = "/tmp/Documents/" + name
        return SuiteDocumentRef(path: path, fileID: SuiteDocumentRef.fileID(forPath: path), app: app, type: type, displayName: name)
    }

    func error(_ body: () async throws -> Void) async -> SuiteError? {
        do { try await body(); return nil } catch { return error as? SuiteError }
    }

    @Test func switchingRefusesAMissingAppAndReportsAQuit() async throws {
        let switching = FakeSwitching(running: [.flare], missing: [.halo])
        #expect(await error { _ = try await switching.switchTo(.halo, reason: .home) } == .appMissing(.halo))
        let warm = try await switching.switchTo(.flare, reason: .shortcut)
        #expect(warm.wasRunning)
        let cold = try await switching.switchTo(.design, reason: .menu)
        #expect(!cold.wasRunning)
        #expect(await switching.runState(of: .design) == .running(windows: 1))

        var changes = await switching.changes().makeAsyncIterator()
        await switching.terminate(.flare)
        #expect(await changes.next() != nil)
        #expect(await switching.runState(of: .flare) == .notRunning)
    }

    @Test func recentsKeepAThumbnailOnReNote() async throws {
        let recents = FakeRecents()
        let logo = ref("Logo.design")
        try await recents.note(logo, event: .opened, at: now - 60, thumbnail: "thumbnails/a.png")
        try await recents.note(logo, event: .saved, at: now, thumbnail: nil)
        let list = try await recents.list()
        #expect(list.items.count == 1)
        #expect(list.items.first?.thumbnail == "thumbnails/a.png")
        #expect(list.items.first?.lastUsed == now)
        #expect(list.revision == 2)
    }

    @Test func routingCoversWeekOfWorkAndRefusesText() throws {
        let routing = FakeRouting()
        let week: [(String, SuiteApp)] = [
            ("Logo.design", .design), ("Cards.design", .design), ("Bounce.flare", .flare), ("Intro.halo", .halo),
            ("beach.ora", .photo), ("Title.flare", .flare), ("Sunset.png", .photo), ("Logo animated.flare", .flare),
        ]
        for (name, app) in week { #expect(try routing.route(fileName: name) == app) }
        #expect(throws: SuiteError.unsupportedFile(name: "notes.txt")) { try routing.route(fileName: "notes.txt") }
        #expect(SuiteError.unsupportedFile(name: "notes.txt").message
                == "AfterGlow can't open \u{201C}notes.txt\u{201D}. It isn't a suite document or an image.")
    }

    @Test func handOffSendSwitchesTheTarget() async throws {
        let switching = FakeSwitching()
        let handOffs = FakeHandOffs(switching: switching)
        let h = HandOff(id: HandOff.newID(), from: .launcher, to: .flare, verb: .open, documents: [ref("Bounce.flare", .flare, .flareAnimation)], createdAt: now)
        let receipt = try await handOffs.send(h)
        #expect(receipt.app == .flare)
        #expect(!receipt.wasRunning)
        #expect(await switching.runState(of: .flare) == .running(windows: 1))
        #expect(await handOffs.sent == [h])
    }

    @Test func thumbnailsAreNamedByFileKey() async throws {
        let thumbnails = FakeThumbnails()
        let logo = ref("Logo.design")
        let path = try await thumbnails.publish(png: Data([1, 2, 3]), for: logo)
        #expect(path == "thumbnails/\(SuiteDocumentRef.fileKey(logo.fileID)).png")
        #expect(!path.dropFirst("thumbnails/".count).contains("/"))
        #expect(await thumbnails.written[path] == Data([1, 2, 3]))
    }

    @Test func homeShowsTheEmptyAndNoMatchMessages() {
        let home = FakeHome()
        let empty = home.home(recents: RecentsList(), running: [.launcher], query: "", filter: nil,
                              order: SuiteApp.apps, missingApps: [], missingFiles: [], now: now)
        #expect(empty.emptyMessage == "No recent work yet. Start something new above, or open a file.")
        #expect(empty.running.isEmpty)
        #expect(empty.tiles.map(\.app) == SuiteApp.apps)

        let list = RecentsList(revision: 1, items: [RecentItem(ref: ref("Logo.design"), lastUsed: now)])
        let none = home.home(recents: list, running: [], query: "zebra", filter: nil,
                             order: SuiteApp.apps, missingApps: [], missingFiles: [], now: now)
        #expect(none.cards.isEmpty)
        #expect(none.emptyMessage == "Nothing matches \u{201C}zebra\u{201D}.")

        let some = home.home(recents: list, running: [], query: "", filter: nil,
                             order: SuiteApp.apps, missingApps: [], missingFiles: [], now: now)
        #expect(some.emptyMessage == nil)
        #expect(some.cards.first?.age == "Today")
    }

    @Test func documentHostRefusesAnUnknownVerb() async throws {
        let host = FakeDocumentHost(app: .photo, verbs: [.open])
        let place = HandOff(id: HandOff.newID(), from: .design, to: .photo, verb: .place, createdAt: now)
        #expect(await host.refusal(for: place) == .notAvailable("Photo can't do that yet."))
        #expect(await error { _ = try await host.accept(place) } == .notAvailable("Photo can't do that yet."))
        let open = HandOff(id: HandOff.newID(), from: .launcher, to: .photo, verb: .open, createdAt: now)
        #expect(try await host.accept(open) == .returned)
        #expect(await host.accepted == [open])
    }

    @Test func unavailableThrowsThatSentence() async {
        let expected = SuiteError.notAvailable(reason)
        let h = HandOff(id: HandOff.newID(), from: .launcher, to: .flare, verb: .open, createdAt: now)
        let switching = FakeSwitching(unavailable: reason)
        #expect(await error { _ = try await switching.switchTo(.flare, reason: .home) } == expected)
        let recents = FakeRecents(unavailable: reason)
        #expect(await error { _ = try await recents.list() } == expected)
        #expect(await error { try await recents.note(ref("Logo.design"), event: .opened, at: now, thumbnail: nil) } == expected)
        #expect(await error { try await recents.remove(fileID: "x") } == expected)
        #expect(await error { try await recents.clear(app: .flare) } == expected)
        let handOffs = FakeHandOffs(unavailable: reason)
        #expect(await error { _ = try await handOffs.send(h) } == expected)
        #expect(await error { _ = try await handOffs.receive(Data(), now: now) } == expected)
        #expect(await error { try await handOffs.settle(id: h.id, as: .accepted) } == expected)
        let thumbnails = FakeThumbnails(unavailable: reason)
        #expect(await error { _ = try await thumbnails.publish(png: Data(), for: ref("Logo.design")) } == expected)
        let host = FakeDocumentHost(app: .flare, verbs: [.open], unavailable: reason)
        #expect(await error { _ = try await host.accept(h) } == expected)
        #expect(FakeCreating(unavailable: reason).tiles(missing: []).allSatisfy { $0.disabledReason == reason })
        #expect(FakeCreating().tiles(missing: [.halo]).first { $0.app == .halo }?.disabledReason == SuiteError.appMissing(.halo).message)
    }
}
