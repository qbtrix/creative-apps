// AfterGlowHomeSnapshots.swift: the home (HM-2a) as goldens in Golden/afterglow/:
// afterglow-home-{week,empty,missing,loading,search}-{light,dark,light-ic,dark-ic};
// the "Preview data" pill only on the fakes; LauncherServices seeds a fixture,
// is no preview, and its tiles are disabled while `sending` is pending. macOS only.
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

    private func shoot(_ model: HomeModel, _ services: SuiteServices, thumbnails: Bool = true, name: String) {
        let flat = Image(nsImage: NSImage(size: NSSize(width: 4, height: 3), flipped: false) { rect in
            NSColor.systemTeal.setFill(); rect.fill(); return true
        })
        let images = thumbnails ? Dictionary(uniqueKeysWithValues: week.items.compactMap(\.thumbnail).map { ($0, flat) }) : [:]
        for appearance in SnapshotAppearance.allCases {
            assertGolden(HomeContent(model: model, services: services, images: images), size: CGSize(width: 800, height: 640),
                         name: "afterglow-home-\(name)", area: "afterglow", appearance: appearance)
        }
    }

    @Test func homeStates() async {
        let services = SuiteServices.fake(recents: week)
        let full = await model(services)
        #expect(full.state.cards.count == 8)
        shoot(full, services, name: "week")
        shoot(full, services, thumbnails: false, name: "loading")

        let search = await model(services)
        search.search("logo", now: now)
        #expect(search.state.cards.map(\.item.ref.displayName) == ["Logo.design", "Logo animated.flare"])
        shoot(search, services, name: "search")

        let missing = await model(services, missing: ["Cards.design"])
        let cards = missing.state.cards.first { $0.item.ref.displayName == "Cards.design" }
        #expect(cards?.isMissing == true)
        missing.select(cards?.item.ref.fileID)
        await missing.openSelection(now: now)
        #expect(missing.message == .fileMissing(name: "Cards.design"))
        shoot(missing, services, name: "missing")

        let none = SuiteServices.fake()
        let empty = await model(none)
        #expect(empty.state.emptyMessage == "No recent work yet. Start something new above, or open a file.")
        #expect(HomeContent.open(none, identifier: "x").isEnabled == false)
        shoot(empty, none, name: "empty")
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
