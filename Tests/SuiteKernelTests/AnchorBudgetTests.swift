// AnchorBudgetTests.swift (pen-paths PN-1 written, PN-6 turns on): the anchor index's budgets on AnchorStressFixture.
import Testing
import SuiteKernel
@Suite(.serialized) struct AnchorBudgetTests {
    /// The best of `runs` runs of `body`, in milliseconds. The absolute budgets take 25, so a busy machine can't fail them.
    static func ms(runs: Int = 5, _ body: () -> Void) -> Double {
        (0..<runs).map { _ in let d = ContinuousClock().measure(body); return Double(d.components.seconds) * 1e3 + Double(d.components.attoseconds) / 1e15 }.min() ?? .infinity
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
        #expect(Self.ms(runs: 25) { _ = index.hit(Point(x: 500, y: 300), reach: 4, selected: Selection()) } <= 0.1 * Self.slack)
    }
    @Test func marqueeScales() {
        let (small, big) = (Self.index(), Self.index(1_000))
        #expect(Self.ms { _ = big.inside(Self.tall) } < 3 * Self.ms { _ = small.inside(Self.page) })
    }
    @Test func selectionIsLinear() {
        let refs = Self.index().inside(Self.page)
        /// `replace` of the first `n`, then `contains` of each: linear doubles from 2,500 to 5,000, a list scan quadruples.
        func select(_ n: Int) -> Double {
            Self.ms { var s = Selection<AnchorRef>(); s.replace(Array(refs.prefix(n))); _ = refs.prefix(n).map(s.contains) }
        }
        #expect(refs.count == 5_000 && select(5_000) < 3 * select(2_500))
    }
}
