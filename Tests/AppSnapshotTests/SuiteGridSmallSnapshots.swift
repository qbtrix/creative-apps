// SuiteGridSmallSnapshots.swift: SuiteUI's ThumbnailGrid at Library's
// smallest cell size (80 pt wide, 4:3) with full badge capsules (five stars,
// a flag and a color label), so the badges must stay inside each cell (issue
// #102). Writes suiteui-grid-small-{light,dark}.png. macOS only.
import SuiteUI
import SwiftUI
import Testing

@MainActor
@Suite struct SuiteGridSmallSnapshots {
    @Test func smallCellsWithManyBadges() throws {
        let items = (1...6).map { index in
            ThumbnailItem(
                id: "\(index)", caption: "IMG_\(4900 + index).heic",
                badges: ThumbnailBadges(
                    rating: 5, isFlagged: true,
                    colorLabel: index % 2 == 0 ? nil : (name: "Red", color: .red)))
        }
        for scheme in [ColorScheme.light, .dark] {
            let suffix = scheme == .dark ? "dark" : "light"
            try snapshot(SmallGridSample(items: items), name: "suiteui-grid-small-\(suffix)", scheme: scheme)
        }
    }
}

private struct SmallGridSample: View {
    let items: [ThumbnailItem<String>]

    var body: some View {
        ThumbnailGrid(items, cellSize: CGSize(width: 80, height: 60), selection: ["2"], onSelectionChange: { _ in })
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
