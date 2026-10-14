// SuiteGridSnapshots.swift: SuiteUI's ThumbnailGrid over sample data, a mix
// of placeholder cells (no image) and colored cells with badges, unselected
// and with three cells selected, in Light and Dark, plus a row of blue and teal
// photos with two selected (issue #101: the selection must read on them).
// Writes suiteui-grid-{light,dark}.png, suiteui-grid-selected-{light,dark}.png
// and suiteui-grid-selected-blue-{light,dark}.png. macOS only.
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
                GridSample(items: Self.blueItems(), selection: ["blue", "teal"]),
                name: "suiteui-grid-selected-blue-\(suffix)", scheme: scheme)
        }
    }

    /// Sky and sea: a selected blue and teal photo beside an unselected blue
    /// one, so a selection that blends into the image shows.
    private static func blueItems() -> [ThumbnailItem<String>] {
        [("blue", [Color.blue, .blue]), ("teal", [.teal, .teal]), ("sky", [.blue, .cyan])].map { id, colors in
            ThumbnailItem(id: id, image: swatch(colors), caption: "\(id).heic")
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
