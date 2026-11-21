// HomePreviewSnapshots.swift: Golden/afterglow/home-recents-previews-{light,dark} (shared-thumbnails
// ST-4): three Recent cards with FakeThumbnails' previews, the fourth with its app's mark. `.task`
// doesn't run in a snapshot, so the previews are loaded first. The frame fits both rows with their
// captions: its last pixel row is plain background, never a clipped card. macOS only.
#if canImport(AppKit)
import AppKit
import SuiteModel
import SwiftUI
import Testing

@testable import AfterGlowApp

@MainActor
@Suite struct HomePreviewSnapshots {
    static let size = CGSize(width: 800, height: 520)

    @Test func recentsWithPreviews() async {
        let refs = HomePreviewFixture.refs(4)
        let thumbnails = FakeThumbnails(seeded: Array(refs.prefix(3)))
        let (model, services) = await HomePreviewFixture.model(refs, thumbnails: thumbnails)
        let previews = HomeGrid.previews()
        await previews.load(refs, from: thumbnails)
        #expect(model.state.cards.map { previews.kind(for: $0.item.ref) } == [.preview, .preview, .preview, .mark])
        for appearance in [SnapshotAppearance.light, .dark] {
            assertGolden(HomePreviewFixture.grid(model, services, previews: previews), size: Self.size,
                         name: "home-recents-previews", area: "afterglow", appearance: appearance)
        }
    }

    /// A clipped second row leaves its card's border on the frame's last row; a fitting frame leaves background.
    @Test func frameFitsTheSecondRow() async throws {
        let refs = HomePreviewFixture.refs(4)
        let thumbnails = FakeThumbnails(seeded: Array(refs.prefix(3)))
        let (model, services) = await HomePreviewFixture.model(refs, thumbnails: thumbnails)
        let previews = HomeGrid.previews()
        await previews.load(refs, from: thumbnails)
        for appearance in [SnapshotAppearance.light, .dark] {
            let image = try #require(SnapshotHost(appearance: appearance).image(
                HomePreviewFixture.grid(model, services, previews: previews), size: Self.size))
            let row = image.width * 4
            let last = Array(image.bytes[(image.height - 1) * row ..< image.height * row])
            let differing = stride(from: 0, to: row, by: 4).filter { last[$0 ..< $0 + 4] != last[0 ..< 4] }.count
            #expect(differing == 0, "\(appearance.rawValue): \(differing) px of the last row aren't background")
        }
    }
}
#endif
