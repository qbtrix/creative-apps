// AnchorBudgetTests.swift (pen-paths PN-1 written, PN-6 turns on): the anchor index's budgets on AnchorStressFixture.
import Testing
import SuiteKernel
@Suite(.serialized) struct AnchorBudgetTests {
    /// The best of `runs` runs of `body`, in milliseconds. The absolute budgets take 25, so a busy machine can't fail them.
    static func ms(runs: Int = 5, _ body: () -> Void) -> Double {
        (0..<runs).map { _ in let d = ContinuousClock().measure(body); return Double(d.components.seconds) * 1e3 + Double(d.components.attoseconds) / 1e15 }.min() ?? .infinity
    }
    /// The best times of `big` and `small`, run alternately for `pairs` pairs, so a busy spell slows both alike.
    static func pair(_ pairs: Int = 15, big: () -> Void, small: () -> Void) -> (big: Double, small: Double) {
        (0..<pairs).reduce((Double.infinity, Double.infinity)) { best, _ in (min(best.0, ms(runs: 1, big)), min(best.1, ms(runs: 1, small))) }
    }
    /// The budgets are for a release build (`swift test -c release`); the debug gate runs unoptimized code, so it allows 5 times as long.
    #if DEBUG
    static let slack = 5.0
    #else
    static let slack = 1.0
    #endif
    static let page = Rect(minX: 0, minY: 0, maxX: 1100, maxY: 800), tall = Rect(minX: 0, minY: 0, maxX: 1100, maxY: 1600)
    static func index(_ stars: Int = 500) -> AnchorIndex { AnchorIndex(AnchorStressFixture.path(stars: stars), toDocument: .identity) }
    @Test func marqueeMoveAndHoverInBudget() {
        let (index, all) = (Self.index(), Set(Self.index().inside(Self.page)))
        #expect(all.count == 5_000 && Self.ms(runs: 25) { _ = index.inside(Self.page) } <= 4 * Self.slack)
        #expect(Self.ms(runs: 25) { _ = AnchorIndex(AnchorEdit.moved(AnchorStressFixture.stress, all, dx: 1, dy: 0), toDocument: .identity) } <= 4 * Self.slack)
        // On a segment, beside the stars (no segment in reach) and far off the page.
        for q in [Point(x: 500, y: 300), Point(x: 528, y: 302), Point(x: 5_000, y: 5_000)] {
            #expect(Self.ms(runs: 25) { _ = index.hit(q, reach: 4, selected: Selection()) } <= 0.1 * Self.slack, "hover at \(q)")
        }
    }
    @Test func marqueeScales() {
        let (small, big) = (Self.index(), Self.index(1_000))
        let t = Self.pair(big: { _ = big.inside(Self.tall) }, small: { _ = small.inside(Self.page) })
        #expect(t.big < 3 * t.small)
    }
    @Test func selectionIsLinear() {
        let refs = Self.index().inside(Self.page)
        /// `replace` of the first `n`, then `contains` of each: linear doubles from 2,500 to 5,000, a list scan quadruples.
        func select(_ n: Int) { var s = Selection<AnchorRef>(); s.replace(Array(refs.prefix(n))); _ = refs.prefix(n).map(s.contains) }
        let t = Self.pair(big: { select(5_000) }, small: { select(2_500) })
        #expect(refs.count == 5_000 && t.big < 3 * t.small)
    }
}
