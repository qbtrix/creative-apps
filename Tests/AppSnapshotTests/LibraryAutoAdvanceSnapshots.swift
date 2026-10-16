// LibraryAutoAdvanceSnapshots.swift: the cull area's two outcomes (cull
// CU-5), in Light and Dark: the loupe on the next photo after a 3-star rating
// with Auto Advance on, and the refused-change notice (the fakes in fail
// mode) with its close button over the grid. Built only through the
// catalog's public methods. Writes library-auto-advance-{light,dark}.png and
// library-cull-refused-{light,dark}.png. macOS only.
import LibraryModel
import SwiftUI
import Testing

@testable import LibraryApp

@MainActor
@Suite struct LibraryAutoAdvanceSnapshots {
    @Test func loupeMovesOnAfterARating() throws {
        var catalog = LibraryCatalog()
        catalog.loadSamples()
        let order = catalog.sortedItems.map(\.id)
        try #require(order.count >= 2)
        catalog.open(order[0])
        #expect(catalog.autoAdvance)
        catalog.cull(.rating(3))
        #expect(catalog.items.first { $0.id == order[0] }?.rating == 3)
        #expect(catalog.focusedItemID == order[1], "Auto Advance left the loupe on \(catalog.focusedItemID ?? "nothing")")
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                LibraryBrowser(model: catalog),
                name: "library-auto-advance-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }

    @Test func refusedChangeShowsADismissibleNotice() throws {
        var catalog = LibraryCatalog(services: .fake(mode: .fail))
        catalog.loadSamples()
        let order = catalog.sortedItems.map(\.id)
        try #require(!order.isEmpty)
        catalog.select([order[0]])
        catalog.cull(.rating(3))
        #expect(catalog.cullError == "Rating is unavailable in this preview.")
        let notice = try #require(catalog.notice)
        #expect(notice.source == .cull && notice.isError)
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

    /// The window's cull actions: the notice's close enabled.
    private static let cullMenu = LibraryMenu(cull: LibraryMenu.Cull(dismissCullError: {}))
}
