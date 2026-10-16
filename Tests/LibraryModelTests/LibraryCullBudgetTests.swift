// LibraryCullBudgetTests.swift: cull's budgets (cull CU-3, packet Quality
// tests QB-LIB-4 and QB-LIB-5, model half) on the `large` fixture (10,000
// photos): one cull under the name sort, and one with Auto Advance in the
// loupe, each within 10 ms debug (1 ms release). Under the name sort a cull
// never rebuilds `order` (the same buffer before and after); under the rating
// sort it does, and the photo moves. Each prints a `LIBRARY-BUDGET cull …`
// line. A recorded edit finds one photo by a plain scan and moves the counts
// by the changed photo alone (#1587), so the gate is a plain #expect. Runs on
// Linux and macOS.
@testable import LibraryModel
import Testing

#if DEBUG
/// Release limits are a tenth of the debug ones (packet Quality tests).
private let scale = 1.0
#else
private let scale = 0.1
#endif

/// The 10,000-photo catalog under `sort`, built fresh so each copy owns its storage.
private func largeCatalog(sort: LibrarySort) -> LibraryCatalog {
    var catalog = LibraryCatalog()
    catalog.load(LibraryFixtures.photos(named: "large"))
    catalog.setSort(sort)
    return catalog
}

/// True when `order` is still the very array `earlier` holds: never rebuilt.
private func sameBuffer(_ order: [String], _ earlier: [String]) -> Bool {
    order.withUnsafeBufferPointer { now in earlier.withUnsafeBufferPointer { now.baseAddress == $0.baseAddress } }
}

@Test func cullOneWithinBudget() throws {
    var catalog = largeCatalog(sort: .name)
    let id = try #require(catalog.order.dropFirst(5_000).first)
    catalog.select([id])
    let order = catalog.order
    var stars = 0
    let cost = Budget.measure("cull one-of-10000-name-sort") {
        stars = stars % 5 + 1
        catalog.cull(.rating(stars))
    }
    #expect(catalog.items.first { $0.id == id }?.rating == stars)
    #expect(catalog.history.undo.count == 20)
    #expect(sameBuffer(catalog.order, order))
    #expect(catalog.selection == [id])
    #expect(cost.median <= 10 * scale)
}

@Test func orderFollowsARatingUnderRatingSort() throws {
    var catalog = largeCatalog(sort: .rating)
    let id = try #require(catalog.order.last)
    catalog.select([id])
    let order = catalog.order
    catalog.cull(.rating(5))
    #expect(!sameBuffer(catalog.order, order))
    #expect(catalog.order.first == id)
    #expect(catalog.order.count == 10_000)
    catalog.cull(.rating(0))
    #expect(catalog.order.first != id)
}

@Test func advanceWithinBudget() throws {
    var catalog = largeCatalog(sort: .name)
    let start = try #require(catalog.order.first)
    catalog.open(start)
    let order = catalog.order
    var stars = 0
    let cost = Budget.measure("cull advance-in-10000") {
        stars = stars % 5 + 1
        catalog.cull(.rating(stars))
    }
    #expect(catalog.mode == .loupe)
    #expect(catalog.focusedItemID == catalog.order.dropFirst(20).first)
    #expect(catalog.items.first { $0.id == start }?.rating == 1)
    #expect(sameBuffer(catalog.order, order))
    #expect(cost.median <= 10 * scale)
}
