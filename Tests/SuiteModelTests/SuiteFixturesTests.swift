// SuiteFixturesTests.swift: SuiteFixtures holds blueprint 4.1's seven
// fixtures: every name builds, weekOfWork's eight files newest first with
// thumbnails named by fileKey (packet correction 1), crowd's 200 recents and
// the assets fixture's colours, vectors, image and animation.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteModel
import Testing

@Suite struct SuiteFixturesTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let documents = "/tmp/Fixtures/suite"

    @Test func everyNameBuildsAndAnUnknownOneIsNil() throws {
        #expect(SuiteFixtures.names == ["empty", "firstLaunch", "weekOfWork", "missing", "roundTrip", "assets", "crowd"])
        for name in SuiteFixtures.names {
            #expect(SuiteFixtures.store(name, documents: documents, now: now) != nil, "\(name)")
        }
        #expect(SuiteFixtures.store("unknown", documents: documents, now: now) == nil)
        let first = try #require(SuiteFixtures.store("firstLaunch", documents: documents, now: now))
        #expect(first.preferences.onboardingDoneVersion == nil)
        for name in ["empty", "roundTrip"] {
            let store = try #require(SuiteFixtures.store(name, documents: documents, now: now))
            #expect(store.recents.items.isEmpty && store.assets.assets.isEmpty)
            #expect(store.preferences.onboardingDoneVersion == 1)
        }
    }

    @Test func weekOfWorkHasEightItemsNewestFirstWithThumbnailsByFileKey() throws {
        #expect(SuiteFixtures.weekOfWorkFiles.map(\.0) == ["Logo.design", "Cards.design", "Bounce.flare", "Intro.halo",
                                                           "beach.ora", "Title.flare", "Sunset.png", "Logo animated.flare"])
        #expect(SuiteFixtures.weekOfWorkFiles.map(\.1) == [.design, .design, .flare, .halo, .photo, .flare, .photo, .flare])
        #expect(SuiteFixtures.weekOfWorkFiles.map(\.2) == [.designDocument, .designDocument, .flareAnimation, .haloProject,
                                                           .photoOpenRaster, .flareAnimation, .png, .flareAnimation])
        let week = try #require(SuiteFixtures.store("weekOfWork", documents: documents, now: now))
        let items = week.recents.items
        #expect(items.count == 8)
        #expect(week.recents.revision == 1)
        #expect(items.first?.lastUsed == now)
        #expect(items.map(\.lastUsed) == items.map(\.lastUsed).sorted(by: >))
        #expect(items.last?.lastUsed == now - 7 * 75_600)
        for (item, file) in zip(items, SuiteFixtures.weekOfWorkFiles) {
            #expect(item.ref.path == documents + "/" + file.0)
            #expect(item.ref.displayName == file.0 && item.ref.app == file.1 && item.ref.type == file.2)
            #expect(item.ref.fileID == SuiteDocumentRef.fileID(forPath: item.ref.path))
            #expect(item.thumbnail == "thumbnails/\(SuiteDocumentRef.fileKey(item.ref.fileID)).png")
        }
        #expect(SuiteFixtures.store("missing", documents: documents, now: now) == week)
    }

    @Test func crowdHasTwoHundredRecents() throws {
        let crowd = try #require(SuiteFixtures.store("crowd", documents: documents, now: now))
        #expect(crowd.recents.items.count == 200)
        #expect(Set(crowd.recents.items.map(\.ref.fileID)).count == 200)
        #expect(crowd.recents.items.allSatisfy { $0.ref.app == .flare && $0.ref.type == .flareAnimation })
        #expect(crowd.recents.items.first?.ref.displayName == "Doc 0.flare")
    }

    @Test func assetsHoldColoursVectorsAnImageAndAnAnimation() throws {
        let store = try #require(SuiteFixtures.store("assets", documents: documents, now: now))
        let assets = store.assets.assets
        #expect(store.assets.revision == 1)
        let colors = assets.filter { $0.kind == .color }
        #expect(colors.map(\.name) == ["Brand blue", "Ink", "Paper", "Coral", "Vivid green", "Vivid red"])
        #expect(colors.filter { $0.color?.space == .displayP3 }.count == 2)
        #expect(colors.allSatisfy { $0.color != nil && $0.payload == nil })
        let vectors = assets.filter { $0.kind == .vector }
        #expect(vectors.map(\.name) == ["Card", "Badge"])
        #expect(vectors.allSatisfy { $0.source?.displayName == "Cards.design" })
        #expect(vectors.first?.source?.fileID == SuiteDocumentRef.fileID(forPath: documents + "/Cards.design"))
        #expect(assets.filter { $0.kind == .image }.map(\.payload) == ["assets/i0/1.png"])
        #expect(assets.filter { $0.kind == .animation }.map(\.payload) == ["assets/a0/1.flare"])
        #expect(assets.count == 10)
        #expect(store.recents.items.isEmpty)
    }
}
