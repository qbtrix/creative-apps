// SuiteFixtures.swift: the journeys' fixtures as store files (blueprint
// 4.1). The launcher writes them into `-SuiteSupportDir` with `FileStore`
// (FixtureSeeder, SC-4c), then every process runs on `.live`, so what one app
// writes the others read. Document files come from `UITests/Fixtures/suite/`
// (each app line's fixture export, A-x-0). Thumbnails are
// `thumbnails/<SuiteDocumentRef.fileKey(fileID)>.png` (packet correction 1).
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public enum SuiteFixtures {
    public static let names = ["empty", "firstLaunch", "weekOfWork", "missing", "roundTrip", "assets", "crowd"]

    /// The three store files one fixture writes.
    public struct Store: Equatable, Sendable {
        public var recents: RecentsList
        public var assets: AssetIndex
        public var preferences: SuitePreferences
        public init(recents: RecentsList, assets: AssetIndex, preferences: SuitePreferences) {
            self.recents = recents; self.assets = assets; self.preferences = preferences
        }
    }

    /// weekOfWork's files, newest first: (file name, app, type).
    public static let weekOfWorkFiles: [(String, SuiteApp, SuiteTypeID)] = [
        ("Logo.design", .design, .designDocument), ("Cards.design", .design, .designDocument),
        ("Bounce.flare", .flare, .flareAnimation), ("Intro.halo", .halo, .haloProject),
        ("beach.ora", .photo, .photoOpenRaster), ("Title.flare", .flare, .flareAnimation),
        ("Sunset.png", .photo, .png), ("Logo animated.flare", .flare, .flareAnimation),
    ]

    /// nil for an unknown name. `documents` is the folder holding the fixture documents.
    public static func store(_ name: String, documents: String, now: Date) -> Store? {
        func ref(_ f: (String, SuiteApp, SuiteTypeID)) -> SuiteDocumentRef {
            let path = documents + "/" + f.0
            return SuiteDocumentRef(path: path, fileID: SuiteDocumentRef.fileID(forPath: path), app: f.1, type: f.2, displayName: f.0)
        }
        let done = SuitePreferences(onboardingDoneVersion: 1)
        switch name {
        case "empty", "roundTrip":
            return Store(recents: RecentsList(), assets: AssetIndex(), preferences: done)
        case "firstLaunch":
            return Store(recents: RecentsList(), assets: AssetIndex(), preferences: SuitePreferences())
        case "weekOfWork", "missing":
            let items = weekOfWorkFiles.enumerated().map { i, f in
                let r = ref(f)
                return RecentItem(ref: r, lastUsed: now - Double(i) * 75_600,
                                  thumbnail: "thumbnails/\(SuiteDocumentRef.fileKey(r.fileID)).png")
            }
            return Store(recents: RecentsList(revision: 1, items: items), assets: AssetIndex(), preferences: done)
        case "assets":
            return Store(recents: RecentsList(), assets: AssetIndex(revision: 1, assets: assets(ref, now: now)), preferences: done)
        case "crowd":
            let items = (0..<200).map { i in
                ref(("Doc \(i).flare", .flare, .flareAnimation))
            }.enumerated().map { i, r in RecentItem(ref: r, lastUsed: now - Double(i)) }
            return Store(recents: RecentsList(revision: 1, items: items), assets: AssetIndex(), preferences: done)
        default:
            return nil
        }
    }

    /// The assets fixture: six colours (two Display P3), two vectors from Cards.design, an image and an animation.
    static func assets(_ ref: ((String, SuiteApp, SuiteTypeID)) -> SuiteDocumentRef, now: Date) -> [SuiteAsset] {
        let colors = [("Brand blue", SuiteColorSpace.sRGB, 0.094, 0.467, 0.949), ("Ink", .sRGB, 0.1, 0.1, 0.12),
                      ("Paper", .sRGB, 0.98, 0.97, 0.94), ("Coral", .sRGB, 1, 0.42, 0.36),
                      ("Vivid green", .displayP3, 0.2, 0.9, 0.3), ("Vivid red", .displayP3, 1, 0.1, 0.1)]
        var assets = colors.enumerated().map { i, c in
            SuiteAsset(id: "c\(i)", kind: .color, name: c.0, color: SuiteColorValue(space: c.1, red: c.2, green: c.3, blue: c.4),
                       modifiedAt: now - Double(i))
        }
        let cards = ref(("Cards.design", .design, .designDocument))
        assets.append(SuiteAsset(id: "v0", kind: .vector, name: "Card", payload: "assets/v0/1.svg", source: cards, modifiedAt: now - 10))
        assets.append(SuiteAsset(id: "v1", kind: .vector, name: "Badge", payload: "assets/v1/1.svg", source: cards, modifiedAt: now - 11))
        assets.append(SuiteAsset(id: "i0", kind: .image, name: "Sunset", payload: "assets/i0/1.png", modifiedAt: now - 12))
        assets.append(SuiteAsset(id: "a0", kind: .animation, name: "Bounce", payload: "assets/a0/1.flare", modifiedAt: now - 13))
        return assets
    }
}
