// LibraryAutoAdvanceSnapshots.swift: the cull area's two outcomes (cull
// CU-5), in Light and Dark: the loupe on the next photo after a 3-star rating
// with Auto Advance on (under the name sort, IMG_0001 rated, the loupe on
// IMG_0002, beside IMG_0001's MetadataInspector showing its 3 stars and the
// loupe's value; that inspector is read from a copy back on the grid), and
// the refused-change notice (the fakes in fail mode) with its close button
// over the grid. Built only through the
// catalog's public methods. Writes library-auto-advance-{light,dark}.png and
// library-cull-refused-{light,dark}.png. macOS only.
import LibraryModel
import SuiteUI
import SwiftUI
import Testing

@testable import LibraryApp

@MainActor
@Suite struct LibraryAutoAdvanceSnapshots {
    @Test func loupeMovesOnAfterARating() throws {
        var catalog = LibraryCatalog()
        catalog.loadSamples()
        catalog.setSort(.name)
        let order = catalog.sortedItems.map(\.id)
        try #require(order.count >= 2)
        #expect(order[0] == "IMG_0001" && order[1] == "IMG_0002", "the name sort starts \(order.prefix(2))")
        catalog.open(order[0])
        #expect(catalog.autoAdvance)
        catalog.cull(.rating(3))
        #expect(catalog.items.first { $0.id == order[0] }?.rating == 3)
        #expect(catalog.focusedItemID == order[1], "Auto Advance left the loupe on \(catalog.focusedItemID ?? "nothing")")
        // In the loupe `selectedMetadata` shows the loupe's photo (#1661), so
        // the rated photo's inspector is read back on the grid.
        var rated = catalog
        rated.showGrid()
        rated.select([order[0]])
        let ratedMetadata = try #require(rated.selectedMetadata)
        #expect(ratedMetadata.title.contains("IMG_0001"), "the inspector shows \(ratedMetadata.title)")
        #expect(ratedMetadata.rating == .value(3))
        #expect(catalog.loupeItem?.name == "IMG_0002")
        #expect(catalog.loupePosition?.hasPrefix("2 of ") == true, "the loupe sits at \(catalog.loupePosition ?? "nothing")")
        let value = try #require(catalog.loupeValue)
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                page(catalog, value: value, previous: ratedMetadata),
                name: "library-auto-advance-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }

    /// The loupe on the left; the rated photo's inspector and the loupe's value on the right.
    private func page(_ model: LibraryCatalog, value: String, previous: PhotoMetadata) -> some View {
        HStack(alignment: .top, spacing: 0) {
            LibraryBrowser(model: model)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            VStack(alignment: .leading, spacing: SuiteSpacing.m) {
                MetadataInspector(metadata: previous)
                    .frame(width: SuiteSize.inspectorWidth.ideal, height: 360, alignment: .topLeading)
                    .background(SuiteColor.panel)
                Text(value)
                    .font(SuiteFont.caption)
                    .foregroundStyle(SuiteColor.textSecondary)
                    .frame(width: SuiteSize.inspectorWidth.ideal, alignment: .leading)
            }
            .padding(SuiteSpacing.l)
        }
    }

    @Test func refusedChangeShowsADismissibleNotice() throws {
        var catalog = LibraryCatalog(services: .fake(mode: .fail))
        catalog.loadSamples()
        let order = catalog.sortedItems.map(\.id)
        try #require(!order.isEmpty)
        catalog.select([order[0]])
        catalog.cull(.rating(3))
        #expect(catalog.cullError == "Couldn't set the rating: this window shows built-in sample data, not photos on disk. Import a folder to rate your own photos.")
        let notice = try #require(catalog.notice)
        #expect(notice.source == .cull && notice.isError)
        #expect(notice.action == .importFolder)
        let row = LibraryNoticeRow(notice: notice, onClose: {})
        #expect(row.onClose != nil)
        var dismissed = catalog
        dismissed.dismissCullError()
        #expect(dismissed.notice == nil)
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                LibraryBrowser(model: catalog, menu: Self.cullMenu)
                    .frame(width: 1440, height: 900, alignment: .top),
                name: "library-cull-refused-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }

    /// The window's cull actions: the notice's close and Import Folder… enabled.
    private static let cullMenu = LibraryMenu(
        file: LibraryMenu.File(importFolder: {}), cull: LibraryMenu.Cull(dismissCullError: {}))
}
