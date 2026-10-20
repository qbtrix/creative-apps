// LibraryCollectionsBudgetTests.swift: collections' budget (slice FC-c). On
// `large` with 10 collections of 1,000 ids and 10 smart ones, a cull of one
// photo takes 10 ms debug (1 ms release); under a filter, the rebuild budget
// of 50 ms. Written before its code (FC-8); FC-9 removes the `.disabled`.
@testable import LibraryModel
import Testing

#if DEBUG
private let scale = 1.0
#else
private let scale = 0.1
#endif

/// `large` under the name sort with 10 collections of 1,000 ids and 10 smart ones.
private func largeWithCollections() -> LibraryCatalog {
    var catalog = LibraryCatalog()
    catalog.load(LibraryFixtures.photos(named: "large"))
    catalog.setSort(.name)
    let ids = catalog.order
    let made = (1...10).map { n in
        UserCollection(id: "user-\(n)", name: "Set \(n)",
                       contents: .photos(Set(ids.dropFirst((n - 1) * 1_000).prefix(1_000))))
    }
    let smart = (1...10).map { n in
        UserCollection(id: "smart-\(n)", name: "Rated \(n % 5)",
                       contents: .rules(LibraryFilter(rating: .atLeast(n % 5), hidesRejected: n.isMultiple(of: 2))))
    }
    catalog.userCollections = made + smart
    catalog.recount()
    return catalog
}

@Suite struct LibraryCollectionsBudgetTests {
    @Test func cullWithCollectionsWithinBudget() throws {
        var catalog = largeWithCollections()
        let id = try #require(catalog.order.dropFirst(5_000).first)
        catalog.select([id])
        var stars = 0
        let cost = Budget.measure("collections cull-one-of-10000-20-collections") {
            stars = stars % 5 + 1
            catalog.cull(.rating(stars))
        }
        #expect(catalog.items.first { $0.id == id }?.rating == stars)
        #expect(catalog.collections.first { $0.id == "user-6" }?.count == 1_000)
        #expect(cost.median <= 10 * scale)
    }

    @Test func cullUnderFilterWithinBudget() throws {
        var catalog = largeWithCollections()
        catalog.filter = LibraryFilter(hidesRejected: true)
        catalog.refreshShown()
        let id = try #require(catalog.order.dropFirst(2_500).first)
        catalog.select([id])
        var stars = 0
        let cost = Budget.measure("collections cull-one-of-10000-filtered") {
            stars = stars % 5 + 1
            catalog.cull(.rating(stars))
        }
        #expect(catalog.items.first { $0.id == id }?.rating == stars)
        #expect(catalog.order.contains(id))
        #expect(cost.median <= 50 * scale)
    }
}
