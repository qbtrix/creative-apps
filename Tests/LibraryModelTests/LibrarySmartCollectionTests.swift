// LibrarySmartCollectionTests.swift: smart collections (filters-collections
// FC-d), written before their code (contract rule 13, FC-11); FC-12 enables
// them. Runs on Linux and macOS.
import Testing
@testable import LibraryModel

@Suite struct LibrarySmartCollectionTests {
    /// The shoot's `IMG_<n>` id.
    private func id(_ n: Int) -> String { "/fixture/shoot/IMG_" + LibraryFixtures.padded(n, to: 4) + ".jpg" }

    private func rules(_ rating: RatingRule) -> LibraryFilter {
        var filter = LibraryFilter.all
        filter.rating = rating
        return filter
    }

    /// J15 step 1: IMG_0001 at 5 stars, IMG_0002 at 4, IMG_0003 at 2; Rating at At Least 4 Stars.
    private func rated() throws -> LibraryCatalog {
        var catalog = LibraryCatalog()
        catalog.load(LibraryFixtures.photos(named: "shoot"))
        catalog.setSort(.name)
        for (n, stars) in [(1, 5), (2, 4), (3, 2)] {
            catalog.select([id(n)])
            catalog.setRating(stars)
        }
        catalog.select([])
        catalog.setRatingRule(.atLeast(4))
        try #require(catalog.filter == rules(.atLeast(4)))
        try #require(catalog.order == [id(1), id(2)])
        return catalog
    }

    /// `catalog` with a smart collection made from its filter, selected.
    private func withSmart() throws -> LibraryCatalog {
        var catalog = try rated()
        try #require(catalog.newSmartCollection() == "smart-1")
        return catalog
    }

    @Test func newSmartCollectionKeepsTheFilterUnderItsSummary() throws {
        var catalog = try rated()
        let steps = catalog.history.undo.count
        #expect(catalog.newSmartCollectionHelp == nil)
        let made = catalog.newSmartCollection()
        #expect(made == "smart-1")
        #expect(catalog.userCollections == [
            UserCollection(id: "smart-1", name: "At least 4 stars", contents: .rules(rules(.atLeast(4))))
        ])
        #expect(catalog.selectedCollectionID == "smart-1")
        #expect(catalog.collections.last == LibraryCollection(id: "smart-1", name: "At least 4 stars", count: 2))
        #expect(catalog.order == [id(1), id(2)])
        #expect(catalog.filterCaption == "Rules of At least 4 stars")
        #expect(catalog.filterValue == "At least 4 stars; 2 of 24")
        #expect(catalog.filter == rules(.atLeast(4)), "making a smart collection changed the view filter")
        #expect(catalog.history.undo.count == steps + 1)
        #expect(catalog.undoTitle == "Undo New Smart Collection")

        catalog.undo()
        #expect(catalog.userCollections.isEmpty)
        #expect(catalog.selectedCollectionID == "all")
        #expect(catalog.filterCaption == nil)
    }

    @Test func withNoFilterOnASmartCollectionIsRefused() {
        var catalog = LibraryCatalog()
        catalog.load(LibraryFixtures.photos(named: "shoot"))
        #expect(catalog.filter == .all)
        #expect(catalog.newSmartCollectionHelp == "Set a filter first: a smart collection keeps the filter's rules.")
        #expect(catalog.newSmartCollection() == nil)
        #expect(catalog.userCollections.isEmpty)
        #expect(catalog.selectedCollectionID == "all")
        #expect(catalog.undoTitle == nil)
        #expect(catalog.collectionsRevision == 0)
    }

    @Test func whileASmartCollectionIsSelectedAnotherIsRefused() throws {
        var catalog = try withSmart()
        let steps = catalog.history.undo.count
        #expect(catalog.newSmartCollectionHelp != nil)
        #expect(catalog.newSmartCollection() == nil)
        #expect(catalog.userCollections.map(\.id) == ["smart-1"])
        #expect(catalog.history.undo.count == steps)
        catalog.selectCollection("all")
        #expect(catalog.newSmartCollectionHelp == nil, "All Photos under a filter can make one")
    }

    @Test func ratingAPhotoChangesTheCount() throws {
        var catalog = try withSmart()
        catalog.selectCollection("all")
        catalog.clearFilter()
        #expect(catalog.filter == .all)
        #expect(catalog.order.count == 24)
        catalog.select([id(3)])
        catalog.setRating(5)
        #expect(catalog.collections.last == LibraryCollection(id: "smart-1", name: "At least 4 stars", count: 3))
        catalog.select([id(1)])
        catalog.setRating(1)
        #expect(catalog.collections.last?.count == 2)
        catalog.selectCollection("smart-1")
        #expect(catalog.order == [id(2), id(3)])
    }

    @Test func theBarEditsTheSelectedRulesAsOneStep() throws {
        var catalog = try withSmart()
        catalog.selectCollection("all")
        catalog.clearFilter()
        catalog.select([id(3)])
        catalog.setRating(5)
        catalog.selectCollection("smart-1")
        #expect(catalog.activeFilter == rules(.atLeast(4)), "a smart collection's rules are the bar's filter")
        #expect(catalog.order == [id(1), id(2), id(3)])
        let steps = catalog.history.undo.count
        let revision = catalog.collectionsRevision

        catalog.setFilter(rules(.exactly(5)))
        #expect(catalog.activeFilter == rules(.exactly(5)))
        #expect(catalog.userCollections.first?.contents == .rules(rules(.exactly(5))))
        #expect(catalog.filter == .all, "editing a smart collection's rules changed the view filter")
        #expect(catalog.order == [id(1), id(3)])
        #expect(catalog.collections.last == LibraryCollection(id: "smart-1", name: "At least 4 stars", count: 2))
        #expect(catalog.filterCaption == "Rules of At least 4 stars")
        #expect(catalog.filterValue == "Exactly 5 stars; 2 of 24")
        #expect(catalog.history.undo.count == steps + 1)
        #expect(catalog.undoTitle == "Undo Edit Rules")
        #expect(catalog.collectionsRevision > revision)

        catalog.undo()
        #expect(catalog.activeFilter == rules(.atLeast(4)))
        #expect(catalog.order == [id(1), id(2), id(3)])
        #expect(catalog.filter == .all)
        #expect(catalog.selectedCollectionID == "smart-1")
    }

    @Test func rulesThatMatchNothingShowTheSmartEmptyState() throws {
        var catalog = try withSmart()
        catalog.setFilter(rules(.exactly(1)))
        #expect(catalog.order.isEmpty)
        #expect(!catalog.isHiddenByFilter, "a smart collection's empty state isn't No Matching Photos")
        #expect(catalog.selectedCollection?.name == "At least 4 stars")
        #expect(catalog.selectedCollection?.emptyMessage
            == "Photos that match this collection's rules appear here. Change the rules in the filter bar.")
        #expect(catalog.selectedCollection?.emptyActionTitle == "Show All Photos")
        #expect(catalog.filter == rules(.atLeast(4)))
    }
}
