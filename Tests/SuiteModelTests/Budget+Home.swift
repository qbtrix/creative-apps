// Budget+Home.swift: QB-SM2, HomeBuilding.home over 200 recents with a query
// (blueprint 7.1): ≤ 2 ms on device, ≤ 20 ms in debug (the gate). The crowd
// fixture's 200 recents, spread half a day apart over 100 days, so the ages
// take every path: Today, Yesterday, the weekday and the medium date.
import Foundation
import SuiteModel
import Testing

@Suite struct HomeBudgetTests {
    @Test func homeOver200() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let store = try #require(SuiteFixtures.store("crowd", documents: "/tmp/Documents", now: now))
        let items = store.recents.items.enumerated().map { i, item in RecentItem(ref: item.ref, lastUsed: now - Double(i) * 43_200) }
        let recents = RecentsList(revision: 1, items: items)
        #expect(recents.items.count == 200)
        let builder = HomeBuilder(creating: FakeCreating(), locale: Locale(identifier: "en_US"), calendar: Calendar(identifier: .gregorian))
        let budget = suiteBudget(device: 2)
        let clock = ContinuousClock()
        var costs: [Duration] = []
        var shown = 0
        for _ in 0..<30 {
            let start = clock.now
            let home = builder.home(recents: recents, running: [.flare], query: "doc 1", filter: nil, order: SuiteApp.apps,
                                    missingApps: [], missingFiles: [], now: now)
            costs.append(clock.now - start)
            shown = home.cards.count
        }
        print("SuiteBudget QB-SM2 home p50 \(suiteMedian(costs)) max \(costs.max() ?? .zero) budget \(budget)")
        #expect(shown == 111)                       // "Doc 1", "Doc 10"…"Doc 19", "Doc 100"…"Doc 199"
        #expect(suiteMedian(costs) <= budget)
    }
}
