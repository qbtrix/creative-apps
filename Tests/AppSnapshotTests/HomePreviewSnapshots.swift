// HomePreviewSnapshots.swift: Golden/afterglow/home-recents-previews-{light,dark} (shared-thumbnails
// ST-4): three Recent cards with FakeThumbnails' previews, the fourth with its app's mark. `.task`
// doesn't run in a snapshot, so the previews are loaded first. macOS only.
#if canImport(AppKit)
import AppKit
import SuiteModel
import SwiftUI
import Testing

@testable import AfterGlowApp

@MainActor
@Suite struct HomePreviewSnapshots {
    @Test func recentsWithPreviews() async {
        let refs = HomePreviewFixture.refs(4)
        let thumbnails = FakeThumbnails(seeded: Array(refs.prefix(3)))
        let (model, services) = await HomePreviewFixture.model(refs, thumbnails: thumbnails)
        let previews = HomeGrid.previews()
        await previews.load(refs, from: thumbnails)
        #expect(model.state.cards.map { previews.kind(for: $0.item.ref) } == [.preview, .preview, .preview, .mark])
        for appearance in [SnapshotAppearance.light, .dark] {
            assertGolden(HomePreviewFixture.grid(model, services, previews: previews), size: CGSize(width: 800, height: 460),
                         name: "home-recents-previews", area: "afterglow", appearance: appearance)
        }
    }
}
#endif
