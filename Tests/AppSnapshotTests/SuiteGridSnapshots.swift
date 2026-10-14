// SuiteGridSnapshots.swift: SuiteUI's ThumbnailGrid over sample data, a mix
// of placeholder cells (no image) and colored cells with badges, unselected
// and with three cells selected, in Light and Dark, plus flat blue and teal
// cells selected beside unselected ones (issue #101: selection must read on
// thumbnails of the accent's own hue). Writes suiteui-grid-{light,dark}.png,
// suiteui-grid-selected-{light,dark}.png and
// suiteui-grid-selected-cool-{light,dark}.png. macOS only.
import SuiteUI
import SwiftUI
import Testing

@MainActor
@Suite struct SuiteGridSnapshots {
    @Test func grid() throws {
        let items = Self.sampleItems()
        for scheme in [ColorScheme.light, .dark] {
            let suffix = scheme == .dark ? "dark" : "light"
            try snapshot(GridSample(items: items, selection: []), name: "suiteui-grid-\(suffix)", scheme: scheme)
            try snapshot(
                GridSample(items: items, selection: ["2", "3", "8"]), name: "suiteui-grid-selected-\(suffix)", scheme: scheme)
            try snapshot(
                GridSample(items: Self.coolItems(), selection: ["blue", "teal"]),
                name: "suiteui-grid-selected-cool-\(suffix)", scheme: scheme)
        }
    }

    /// Flat blue and teal cells, each selected and unselected, so the plate
    /// is judged where an accent ring on the image would vanish.
    private static func coolItems() -> [ThumbnailItem<String>] {
        [("blue", Color.blue), ("teal", .teal), ("blue-off", .blue), ("teal-off", .teal)].map { id, color in
            ThumbnailItem(id: id, image: swatch([color, color]), caption: "\(id).heic")
        }
    }

    /// Twelve cells: every third has no image, the rest are gradients.
    private static func sampleItems() -> [ThumbnailItem<String>] {
        var palette = [[Color.orange, .pink], [.teal, .blue], [.yellow, .green], [.indigo, .purple],
                       [.red, .orange], [.mint, .cyan], [.brown, .yellow], [.blue, .indigo]].makeIterator()
        return (1...12).map { index in
            let image = index % 3 == 0 ? nil : palette.next().flatMap(swatch)
            let badges = ThumbnailBadges(
                rating: index % 6, isFlagged: index % 4 == 1,
                colorLabel: index % 5 == 2 ? (name: "Red", color: .red) : nil)
            return ThumbnailItem(id: "\(index)", image: image, caption: "IMG_\(4800 + index).heic", badges: badges)
        }
    }

    private static func swatch(_ colors: [Color]) -> Image? {
        let renderer = ImageRenderer(
            content: LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                .frame(width: 320, height: 240))
        return renderer.cgImage.map { Image(decorative: $0, scale: 1) }
    }
}

private struct GridSample: View {
    let items: [ThumbnailItem<String>]
    let selection: Set<String>

    var body: some View {
        ThumbnailGrid(items, cellSize: CGSize(width: 200, height: 150), selection: selection, onSelectionChange: { _ in })
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
