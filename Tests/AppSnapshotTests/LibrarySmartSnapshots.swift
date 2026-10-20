// LibrarySmartSnapshots.swift: a smart collection selected, and its empty
// state (filters-collections FC-d). Written before its code (FC-11); FC-12
// enables them. Writes library-smart-{selected,empty}-{light,dark}.png.
import SwiftUI
import Testing

@testable import LibraryApp
@testable import LibraryModel

@MainActor
@Suite struct LibrarySmartSnapshots {
    /// The shoot by name with IMG_0001 at 5 stars, IMG_0002 at 4 and
    /// IMG_0003 at 2, and a smart collection for At Least 4 Stars, selected.
    private func smart() -> LibraryCatalog {
        var catalog = LibraryCatalog()
        catalog.load(LibraryFixtures.photos(named: "shoot"))
        catalog.setSort(.name)
        for (n, stars) in [(1, 5), (2, 4), (3, 2)] {
            catalog.select(["/fixture/shoot/IMG_" + LibraryFixtures.padded(n, to: 4) + ".jpg"])
            catalog.setRating(stars)
        }
        catalog.select([])
        catalog.setRatingRule(.atLeast(4))
        catalog.newSmartCollection()
        return catalog
    }

    @Test(.disabled("waits on FC-12")) func smartSelected() throws {
        try snapshots(smart(), name: "library-smart-selected")
    }

    @Test(.disabled("waits on FC-12")) func smartEmpty() throws {
        var catalog = smart()
        var none = LibraryFilter.all
        none.rating = .exactly(1)
        catalog.setFilter(none)
        #expect(catalog.order.isEmpty)
        try snapshots(catalog, name: "library-smart-empty")
    }

    private func snapshots(_ catalog: LibraryCatalog, name: String) throws {
        for scheme in [ColorScheme.light, .dark] {
            let suffix = scheme == .dark ? "dark" : "light"
            try snapshot(window(catalog), name: "\(name)-\(suffix)", scheme: scheme)
        }
    }

    /// The filter bar over the browser, the way LibraryWindow stacks them;
    /// every bar control acts, so it draws enabled.
    private func window(_ catalog: LibraryCatalog) -> some View {
        let menu = LibraryFiltersMenu(
            activeFilter: catalog.activeFilter,
            toggleFlag: { _ in }, setRating: { _ in }, toggleLabel: { _ in },
            toggleHideRejected: {}, clearFilter: {})
        return VStack(spacing: 0) {
            LibraryFilterBar(
                filter: catalog.activeFilter, value: catalog.filterValue, caption: catalog.filterCaption, menu: menu)
                .fixedSize(horizontal: false, vertical: true)
            LibraryBrowser(model: catalog, filters: menu)
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .top)
                .clipped()
        }
        .frame(width: 1440, height: 900)
    }
}
