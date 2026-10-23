// LibraryKeywordBudgetTests.swift: QB-LIB-M1 and QB-LIB-M2 (metadata-more) on the `large` fixture, each
// within 20 ms debug (2 ms release). Written before its code (rule 13, MD-9). MD-10 built the code; they are
// timing tests, so they stay off here until Tests/perf-suites.txt lists them and perf-nightly runs them.
@testable import LibraryModel
import Testing

#if DEBUG
private let scale = 1.0
#else
private let scale = 0.1
#endif

@Test func addToThousandWithinBudget() {
    var catalog = LibraryCatalog()
    catalog.load(LibraryFixtures.photos(named: "large"))
    catalog.select(Set(catalog.order.prefix(1_000)))
    var run = 0
    let cost = Budget.measure("keywords add-to-1000-of-10000") {
        run += 1
        catalog.addKeywords("Keyword \(run)")
    }
    #expect(catalog.items.filter { $0.keywords.contains("Keyword \(run)") }.count == 1_000)
    #expect(catalog.history.undo.count == run)
    #expect(cost.median <= 20 * scale)
}

@Test func suggestWithinBudget() {
    let pool = (0..<500).map { $0.isMultiple(of: 2) ? "Subject \($0)" : "Place \($0)" }
    var photos = LibraryFixtures.photos(named: "large")
    for index in photos.indices {
        photos[index].keywords = (0..<3).map { pool[(index * 7 + $0 * 131) % pool.count] }.sorted()
    }
    var catalog = LibraryCatalog()
    catalog.load(photos)
    catalog.select([photos[5_000].id])
    var suggestions: [String] = []
    let cost = Budget.measure("keywords suggest-s-over-10000") {
        suggestions = catalog.keywordSuggestions(prefix: "s")
    }
    #expect(suggestions.count == 8 && suggestions.allSatisfy { $0.hasPrefix("Subject") })
    #expect(cost.median <= 20 * scale)
}
