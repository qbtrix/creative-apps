// AnchorBudgetTests.swift (pen-paths PN-1 written, PN-6 turns on): the anchor index's budgets on AnchorStressFixture.
import Testing
import SuiteKernel
@Suite(.serialized) struct AnchorBudgetTests {
    /// The best of `runs` runs of `body`, in milliseconds.
    static func ms(runs: Int = 25, _ body: () -> Void) -> Double {
        (0..<runs).map { _ in let d = ContinuousClock().measure(body); return Double(d.components.seconds) * 1e3 + Double(d.components.attoseconds) / 1e15 }.min() ?? .infinity
    }
    /// True when `body` keeps to `budget` ms. Budgets are for a release build (`swift test -c release`, perf-nightly);
    /// the debug gate runs unoptimized code beside every other test, so there it runs `body` once and checks no time.
    static func within(_ budget: Double, _ body: () -> Void) -> Bool {
        #if DEBUG
        body(); return true
        #else
        return ms(body) <= budget
        #endif
    }
    /// How many times longer `big` takes than `small`, best against best over alternate runs, so a busy spell slows
    /// both alike. With 16 times the work, linear code reads about 16 and quadratic about 256; failing above 64 holds
    /// under load in any build.
    static func ratio(big: () -> Void, small: () -> Void) -> Double {
        let best = (0..<15).reduce((Double.infinity, Double.infinity)) { b, _ in (min(b.0, ms(runs: 1, big)), min(b.1, ms(runs: 1, small))) }
        return best.0 / max(best.1, 1e-6)
    }
    static let page = Rect(minX: 0, minY: 0, maxX: 1100, maxY: 800)
    static func index(_ stars: Int = 500) -> AnchorIndex { AnchorIndex(AnchorStressFixture.path(stars: stars), toDocument: .identity) }
    @Test func marqueeMoveAndHoverInBudget() {
        let index = Self.index(), all = Set(index.inside(Self.page))
        #expect(all.count == 5_000 && Self.within(4) { _ = index.inside(Self.page) })
        #expect(Self.within(4) { _ = AnchorIndex(AnchorEdit.moved(AnchorStressFixture.stress, all, dx: 1, dy: 0), toDocument: .identity) })
        // On a segment, beside the stars (no segment in reach) and far off the page.
        for q in [Point(x: 500, y: 300), Point(x: 528, y: 302), Point(x: 5_000, y: 5_000)] {
            #expect(Self.within(0.1) { _ = index.hit(q, reach: 4, selected: Selection()) }, "hover at \(q)")
        }
    }
    @Test func marqueeScales() {
        // 5 rows of stars against 80, each marquee taking every row.
        let (small, big) = (Self.index(125), Self.index(2_000))
        let rows = { (n: Double) in Rect(minX: 0, minY: 0, maxX: 1100, maxY: 40 * n) }
        #expect(small.inside(rows(5)).count == 1_250 && big.inside(rows(80)).count == 20_000)
        #expect(Self.ratio(big: { _ = big.inside(rows(80)) }, small: { _ = small.inside(rows(5)) }) < 64)
    }
    @Test func selectionIsLinear() {
        /// `replace` of the first `n`, then `contains` of each: a set lookup stays linear, a list scan turns quadratic.
        let refs = (0..<16_000).map { AnchorRef(contour: $0 / 10, index: $0 % 10) }
        func select(_ n: Int) -> Bool { var s = Selection<AnchorRef>(); s.replace(Array(refs.prefix(n))); return refs.prefix(n).allSatisfy(s.contains) }
        #expect(select(16_000) && Self.ratio(big: { _ = select(16_000) }, small: { _ = select(1_000) }) < 64)
    }
}
