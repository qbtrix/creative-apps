// SuiteGridSmallSnapshots.swift: SuiteUI's ThumbnailGrid at Library's
// smallest cell size (80 pt wide, 4:3) with full badge capsules (five stars,
// a flag and a color label), so the badges must stay inside each cell (issue
// #102). Writes suiteui-grid-small-{light,dark}.png and checks the small grid
// golden (Golden/lists/grid-small-*.png, four appearances); cells are
// registered as `suite.grid.<id>`. macOS only.
import SuiteUI
import SwiftUI
import Testing

@MainActor
@Suite struct SuiteGridSmallSnapshots {
    @Test func smallCellsWithManyBadges() throws {
        let items = Self.items()
        for scheme in [ColorScheme.light, .dark] {
            let suffix = scheme == .dark ? "dark" : "light"
            try snapshot(SmallGridSample(items: items), name: "suiteui-grid-small-\(suffix)", scheme: scheme)
        }
    }

    @Test func smallGridGolden() {
        for appearance in SnapshotAppearance.allCases {
            assertGolden(
                SmallGridSample(items: Self.items()), size: CGSize(width: 600, height: 140), name: "grid-small",
                area: "lists", appearance: appearance)
        }
    }

    private static func items() -> [ThumbnailItem<String>] {
        (1...6).map { index in
            ThumbnailItem(
                id: "\(index)", caption: "IMG_\(4900 + index).heic",
                badges: ThumbnailBadges(
                    rating: 5, isFlagged: true,
                    colorLabel: index % 2 == 0 ? nil : (name: "Red", color: .red)))
        }
    }
}

private struct SmallGridSample: View {
    let items: [ThumbnailItem<String>]

    var body: some View {
        ThumbnailGrid(
            items, cellSize: CGSize(width: 80, height: 60), selection: ["2"], onSelectionChange: { _ in },
            cellIdentifierPrefix: "suite.grid.")
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
