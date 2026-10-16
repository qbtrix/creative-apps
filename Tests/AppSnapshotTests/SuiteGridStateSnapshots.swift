// SuiteGridStateSnapshots.swift: SuiteUI's ThumbnailGrid cell states from
// #779: a landscape photo, a dimmed reject (40% image and the "Rejected"
// badge), an unreadable file (warning triangle on the placeholder fill) and a
// portrait photo aspect-fit inside its landscape cell, never cropped. Writes
// suiteui-grid-states-{light,dark}.png. macOS only.
import SuiteUI
import SwiftUI
import Testing

@MainActor
@Suite struct SuiteGridStateSnapshots {
    @Test func cellStates() throws {
        let items = [
            ThumbnailItem(id: "1", image: swatch([.orange, .pink], 320, 240), caption: "IMG_5001.heic"),
            ThumbnailItem(
                id: "2", image: swatch([.teal, .blue], 320, 240), caption: "IMG_5002.heic",
                badges: ThumbnailBadges(rating: 1, dimmed: true)),
            ThumbnailItem(id: "3", caption: "IMG_5003.heic", help: "The file is missing.", isUnreadable: true),
            ThumbnailItem(id: "4", image: swatch([.yellow, .green], 240, 320), caption: "IMG_5004.heic"),
        ]
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                ThumbnailGrid(items, cellSize: CGSize(width: 200, height: 150), selection: [], onSelectionChange: { _ in })
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top),
                name: "suiteui-grid-states-\(scheme.name)", scheme: scheme)
        }
    }

    private func swatch(_ colors: [Color], _ width: CGFloat, _ height: CGFloat) -> Image? {
        let renderer = ImageRenderer(
            content: LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                .frame(width: width, height: height))
        return renderer.cgImage.map { Image(decorative: $0, scale: 1) }
    }
}
