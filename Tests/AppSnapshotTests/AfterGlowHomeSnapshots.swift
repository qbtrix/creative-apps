// AfterGlowHomeSnapshots.swift: the home (HM-2a) as goldens in Golden/afterglow/:
// afterglow-home-{week,empty,missing,loading,search,filter,removed}-{light,dark,light-ic,dark-ic};
// the "Preview data" pill only on the fakes; LauncherServices seeds a fixture,
// is no preview, and its tiles are disabled while `sending` is pending. The
// cards' captions and tooltips (#1758), the search line (#1765) and the
// missing notice's Locate… (#1759) are checked on HomeGrid's mapping; "removed"
// is SJ1 step 5's Remove of the missing Cards.design with its Undo notice (#1870,
// #1865); the empty state's sentence says why Open… waits (#1754). macOS only.
import AppKit
import SuiteModel
import SuiteUI
import SwiftUI
import Testing

@testable import AfterGlowApp

@MainActor
@Suite struct AfterGlowHomeSnapshots {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    var week: RecentsList { SuiteFixtures.store("weekOfWork", documents: "/fixture", now: now)?.recents ?? RecentsList() }

    /// A reloaded model whose files all exist but those named in `missing`.
    private func model(_ services: SuiteServices, missing: Set<String> = []) async -> HomeModel {
        let model = HomeModel(services: services,
                              fileExists: { !missing.contains(URL(fileURLWithPath: $0).lastPathComponent) },
                              makeID: { "h1" })
        await model.reload(now: now)
        return model
    }

    private func liveServices(_ extra: [String] = []) -> SuiteServices {
        let support = FileManager.default.temporaryDirectory.appendingPathComponent("AfterGlowHome-\(UUID().uuidString)")
        return LauncherServices.make(arguments: ["-SuiteSupportDir", support.path] + extra, now: now)
    }

    private func shoot(_ model: HomeModel, _ services: SuiteServices, thumbnails: Bool = true, name: String,
                       size: CGSize = CGSize(width: 800, height: 640)) {
        let flat = Image(nsImage: NSImage(size: NSSize(width: 4, height: 3), flipped: false) { rect in
            NSColor.systemTeal.setFill(); rect.fill(); return true
        })
        let images = thumbnails ? Dictionary(uniqueKeysWithValues: week.items.compactMap(\.thumbnail).map { ($0, flat) }) : [:]
        for appearance in SnapshotAppearance.allCases {
            assertGolden(HomeContent(model: model, services: services, images: images), size: size,
                         name: "afterglow-home-\(name)", area: "afterglow", appearance: appearance)
        }
    }

    @Test func homeStates() async {
        let services = SuiteServices.fake(recents: week)
        let full = await model(services)
        #expect(full.state.cards.count == 8)
        shoot(full, services, name: "week")
        shoot(full, services, name: "week-tall", size: CGSize(width: 1000, height: 960))
        shoot(full, services, thumbnails: false, name: "loading")

        let search = await model(services)
        search.search("logo", now: now)
        #expect(search.state.cards.map(\.item.ref.displayName) == ["Logo.design", "Logo animated.flare"])
        shoot(search, services, name: "search")

        // #1767: SJ1 step 2 (the Design chip after the search) and step 5 (Remove, then Undo).
        let filter = await model(services)
        filter.search("logo", now: now)
        filter.filter(.design, now: now)
        #expect(filter.state.cards.count == 1)
        shoot(filter, services, name: "filter")

        // #1870: as SJ1 step 5 runs it, Return on the missing Cards.design, its notice, then Remove.
        let own = SuiteServices.fake(recents: week)  // its own store: the remove doesn't reach the others
        let removed = await model(own, missing: ["Cards.design"])
        removed.select(removed.state.cards.first { $0.item.ref.displayName == "Cards.design" }?.item.ref.fileID)
        await removed.openSelection(now: now)
        #expect(removed.message == .fileMissing(name: "Cards.design"))
        await removed.removeSelection(now: now)
        #expect(removed.state.cards.count == 7)
        #expect(!removed.state.cards.contains { $0.item.ref.displayName == "Cards.design" })
        #expect(removed.state.cards.contains { $0.item.ref.displayName == "Logo.design" })
        // #1865: the notice names the removed file and offers Undo.
        #expect(removed.message == nil && removed.removedNotice == "Cards.design removed from Recents.")
        shoot(removed, own, name: "removed")
        await removed.undoRemove(now: now)
        #expect(removed.state.cards.count == 8 && removed.removedNotice == nil)

        let missing = await model(services, missing: ["Cards.design"])
        let cards = missing.state.cards.first { $0.item.ref.displayName == "Cards.design" }
        #expect(cards?.isMissing == true)
        missing.select(cards?.item.ref.fileID)
        await missing.openSelection(now: now)
        #expect(missing.message == .fileMissing(name: "Cards.design"))
        shoot(missing, services, name: "missing")
        shoot(missing, services, name: "missing-tall", size: CGSize(width: 1000, height: 960))

        let none = SuiteServices.fake()
        let empty = await model(none)
        #expect(empty.state.emptyMessage == "No recent work yet. Start something new above, or open a file.")
        // #1754: while Open… waits, the sentence drops "or open a file" and says why, in Open…'s own words.
        let open = HomeContent.open(none, identifier: "x")
        #expect(open.isEnabled == false)
        let shown = HomeGrid.emptyMessage(empty, open: open)
        #expect(!shown.contains("open a file"), "\(shown)")
        #expect(shown.contains(open.unavailableHelp ?? "-"), "\(shown)")
        #expect(open.unavailableHelp != SuiteIdentity.notConnected("recents-open-in"))
        shoot(empty, none, name: "empty")
    }

    @Test func cardsShowTheirAgeAndApp() async {
        let full = await model(SuiteServices.fake(recents: week))
        #expect(full.state.cards.count == 8)
        for card in full.state.cards {
            let item = HomeGrid.item(card, images: [:])
            #expect(item.caption.contains(card.age), "caption \(item.caption)")
            #expect((item.help ?? "").contains(card.item.ref.app.displayName), "help \(item.help ?? "nil")")
        }
    }

    @Test func searchShowsTheQueryAndMissingOffersLocate() async {
        let search = await model(SuiteServices.fake(recents: week))
        search.search("logo", now: now)
        #expect(HomeGrid.matching(query: search.query, count: search.state.cards.count) == "2 items matching \u{201C}logo\u{201D}")
        #expect(HomeGrid.matching(query: "logo", count: 1) == "1 item matching \u{201C}logo\u{201D}")
        #expect(HomeGrid.matching(query: "", count: 8) == nil)
        #expect(HomeGrid.noticeActions(.fileMissing(name: "Cards.design"), hasSelection: true)
                == ["afterglow.home.locate", "afterglow.home.remove"])
        #expect(HomeGrid.noticeActions(.fileMissing(name: "Cards.design"), hasSelection: false).isEmpty)
    }

    /// #1871: the notice is InlineNotice #780's placeholder in Library's shape, not a tinted slab.
    @Test func noticeIsNoTintedBand() throws {
        var root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while root.path != "/", !FileManager.default.fileExists(atPath: root.appendingPathComponent("Package.swift").path) {
            root = root.deletingLastPathComponent()
        }
        let grid = try String(contentsOf: root.appendingPathComponent("Sources/AfterGlowApp/HomeGrid.swift"), encoding: .utf8)
        #expect(!grid.contains("Tint, in:"))
        #expect(grid.contains("Label(text, systemImage: systemImage).font(SuiteFont.caption)"))
    }

    @Test func previewPillOnlyOnTheFakesAndAFixtureSeedsTheLiveStore() async throws {
        #expect(HomeContent.showsPreview(.fake()))
        #expect(!HomeContent.showsPreview(liveServices()))
        #expect(try await liveServices(["-SuiteFixture", "weekOfWork"]).recents.list().items.count == 8)
    }

    @Test func tilesAreDisabledWhileSendingIsPending() async {
        var services = SuiteServices.fake(recents: week)
        services.pending["sending"] = "Switching between apps isn't available yet."
        let fake = await model(services)
        #expect(fake.state.tiles.allSatisfy { $0.disabledReason == "Switching between apps isn't available yet." })
        let live = liveServices()
        #expect(live.pending["sending"] == SuiteServices.notConnected("sending"))
        let onLive = await model(live)
        #expect(onLive.state.tiles.allSatisfy { $0.disabledReason == live.pending["sending"] })
    }
}
