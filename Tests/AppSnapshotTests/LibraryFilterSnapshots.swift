// LibraryFilterSnapshots.swift: the filter bar above Library's grid, off,
// on (Hide Rejected, At Least 3 Stars) and empty (No Matching Photos), Light
// and Dark, on the shoot with J13's culls. FC-6 writes it; FC-7 enables it.
import LibraryModel
import SuiteUI
import SwiftUI
import Testing

@testable import LibraryApp

@MainActor
@Suite struct LibraryFilterSnapshots {
    @Test func filterStates() throws {
        var catalog = LibraryCatalog()
        catalog.load(LibraryFixtures.photos(named: "shoot"))
        catalog.setSort(.name)
        let order = catalog.order
        try #require(order.count == 24)
        for (index, stars) in [(0, 5), (1, 3), (4, 3)] {
            catalog.select([order[index]])
            catalog.setRating(stars)
        }
        for (index, flag) in [(2, PhotoFlag.pick), (3, .reject), (5, .pick)] {
            catalog.select([order[index]])
            catalog.setFlag(flag)
        }
        catalog.select([])
        #expect(catalog.filterValue == "All photos; 24 of 24")
        try shoot(catalog, name: "library-filter-off")

        catalog.toggleHideRejected()
        catalog.setRatingRule(.atLeast(3))
        #expect(catalog.filterValue == "At least 3 stars, Rejects hidden; 3 of 24")
        #expect(catalog.order == [order[0], order[1], order[4]])
        try shoot(catalog, name: "library-filter-on")

        catalog.setRatingRule(.exactly(4))
        #expect(catalog.isHiddenByFilter)
        #expect(catalog.filterEmptyMessage == "No photos in All Photos match Exactly 4 stars, Rejects hidden.")
        #expect(LibraryBrowser(model: catalog, filters: Self.filters(catalog)).clearFilterAction.unavailableHelp == nil)
        try shoot(catalog, name: "library-filter-empty")
    }

    /// Light and Dark of the bar above the browser, pinned to the top.
    private func shoot(_ model: LibraryCatalog, name: String) throws {
        let filters = Self.filters(model)
        for scheme in [ColorScheme.light, .dark] {
            let page = VStack(spacing: 0) {
                LibraryFilterBar(
                    filter: model.activeFilter, value: model.filterValue, caption: model.filterCaption, menu: filters)
                    .fixedSize(horizontal: false, vertical: true)
                LibraryBrowser(model: model, filters: filters)
            }
            try snapshot(
                page.frame(width: 1440, height: 900, alignment: .top),
                name: "\(name)-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }

    /// The bar's actions, each present only while its help is nil; nothing is clicked.
    private static func filters(_ model: LibraryCatalog) -> LibraryFiltersMenu {
        var menu = LibraryFiltersMenu()
        menu.activeFilter = model.activeFilter
        menu.filterHelp = model.libraryFilterHelp
        menu.clearFilterHelp = model.clearFilterHelp
        if model.libraryFilterHelp == nil {
            menu.toggleFlag = { (_: PhotoFlag) in }
            menu.setRating = { (_: RatingRule) in }
            menu.toggleLabel = { (_: PhotoLabel) in }
            menu.toggleHideRejected = {}
        }
        if model.clearFilterHelp == nil { menu.clearFilter = {} }
        return menu
    }
}
