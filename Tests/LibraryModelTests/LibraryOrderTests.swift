// LibraryOrderTests.swift: the cached display order (SP-8) always equals the
// shown photos sorted fresh, after every change that can reorder or hide one,
// and rebuilding it for 10,000 photos stays within its budget.
import Testing
@testable import LibraryModel

/// The order computed from scratch, as `sortedItems` did before the cache.
private func expectedOrder(_ catalog: LibraryCatalog) -> [String] {
    catalog.shownItems.sorted { catalog.sort.orders($0, before: $1) }.map(\.id)
}

private func expectFresh(_ catalog: LibraryCatalog, sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(catalog.order == expectedOrder(catalog), sourceLocation: sourceLocation)
    #expect(catalog.sortedItems.map(\.id) == catalog.order, sourceLocation: sourceLocation)
}

@Test func orderIsFreshAfterLoad() {
    var catalog = LibraryCatalog()
    expectFresh(catalog)
    catalog.loadSamples()
    #expect(catalog.order.count == LibrarySample.items().count)
    expectFresh(catalog)
}

@Test func orderIsFreshAfterEverySortAndCollection() {
    var catalog = LibraryCatalog()
    catalog.loadSamples()
    for collection in catalog.collections.map(\.id) {
        catalog.selectCollection(collection)
        for sort in LibrarySort.allCases {
            catalog.setSort(sort)
            expectFresh(catalog)
        }
    }
}

@Test func orderFollowsARatingChangeUnderRatingSort() {
    var catalog = LibraryCatalog()
    catalog.loadSamples()
    catalog.setSort(.rating)
    let last = catalog.order.last ?? ""
    catalog.select([last])
    catalog.setRating(5)
    expectFresh(catalog)
    let rated = catalog.order.firstIndex(of: last) ?? catalog.order.count
    let firstLower = catalog.sortedItems.firstIndex { $0.rating < 5 } ?? catalog.order.count
    #expect(rated < firstLower)
}

@Test func orderFollowsAFlagChangeInFavorites() {
    var catalog = LibraryCatalog()
    catalog.loadSamples()
    catalog.selectCollection("favorites")
    let first = catalog.order.first ?? ""
    catalog.select([first])
    catalog.setFlag(.none)
    expectFresh(catalog)
    #expect(!catalog.order.contains(first))
}

@Test func orderFollowsARatingChangeInFavorites() {
    var catalog = LibraryCatalog()
    catalog.loadSamples()
    catalog.selectCollection("favorites")
    catalog.setSort(.rating)
    catalog.select(Set(catalog.order.suffix(1)))
    catalog.setRating(5)
    expectFresh(catalog)
}

@Test func orderRebuildWithinBudget() {
    var catalog = LibraryCatalog()
    catalog.load(LibraryFixtures.photos(named: "large"))
    #expect(catalog.order.count == 10_000)
    let cost = Budget.measure("spine order-rebuild-10000") { catalog.rebuildOrder() }
    #expect(cost.median <= 50)
    expectFresh(catalog)
}
