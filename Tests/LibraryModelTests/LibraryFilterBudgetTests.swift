// LibraryFilterBudgetTests.swift: QB-LIB-3's model half under a filter
// (filters-collections): `rebuildOrder` on `large` (10,000 photos) under a
// flag, rating and label filter, median within 50 ms debug, 5 ms release.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
@testable import LibraryModel
import Testing

#if DEBUG
/// Release limits are a tenth of the debug ones (packet Quality tests).
private let scale = 1.0
#else
private let scale = 0.1
#endif

@Suite struct LibraryFilterBudgetTests {
    /// `large` with every rating, flag and some labels in use, so each rule cuts.
    private static func largeCatalog() -> LibraryCatalog {
        let flags: [PhotoFlag] = [.none, .pick, .reject]
        let labels: [PhotoLabel?] = [nil, .red, .blue, .green]
        let photos = LibraryFixtures.photos(named: "large").enumerated().map { index, sample in
            PhotoItem(
                id: sample.id, name: sample.name, captureDate: sample.captureDate, color: sample.color,
                rating: index % 6, label: labels[index % labels.count], flag: flags[index % flags.count])
        }
        var catalog = LibraryCatalog()
        catalog.load(photos)
        catalog.setSort(.name)
        return catalog
    }

    @Test func rebuildWithFilterWithinBudget() {
        var catalog = Self.largeCatalog()
        let filter = LibraryFilter(flags: [.pick, .none], rating: .atLeast(2), labels: [.red, .blue])
        catalog.setFilter(filter)
        #expect(catalog.activeFilter == filter)
        let expected = catalog.items.filter(filter.matches).count
        #expect(expected > 0 && catalog.order.count == expected)
        let cost = Budget.measure("filter rebuild-10000") { catalog.rebuildOrder() }
        #expect(catalog.order.count == expected)
        #expect(cost.median <= 50 * scale)
    }
}
