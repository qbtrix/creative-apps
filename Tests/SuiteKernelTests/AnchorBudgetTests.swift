// AnchorBudgetTests.swift (pen-paths PN-1 written, PN-6 turns on): the anchor index's budgets on AnchorStressFixture.
import Testing
import SuiteKernel
@Suite(.serialized) struct AnchorBudgetTests {
    /// The best of five runs of `body`, in milliseconds.
    static func ms(_ body: () -> Void) -> Double {
        (0..<5).map { _ in let d = ContinuousClock().measure(body); return Double(d.components.seconds) * 1e3 + Double(d.components.attoseconds) / 1e15 }.min() ?? .infinity
    }
    static let page = Rect(minX: 0, minY: 0, maxX: 1100, maxY: 800), tall = Rect(minX: 0, minY: 0, maxX: 1100, maxY: 1600)
    static func index(_ stars: Int = 500) -> AnchorIndex { AnchorIndex(AnchorStressFixture.path(stars: stars), toDocument: .identity) }
    @Test(.disabled("waits on PN-6")) func marqueeMoveAndHoverInBudget() {
        let (index, all) = (Self.index(), Set(Self.index().inside(Self.page)))
        #expect(all.count == 5_000 && Self.ms { _ = index.inside(Self.page) } <= 4)
        #expect(Self.ms { _ = AnchorIndex(AnchorEdit.moved(AnchorStressFixture.stress, all, dx: 1, dy: 0), toDocument: .identity) } <= 4)
        #expect(Self.ms { _ = index.hit(Point(x: 500, y: 300), reach: 4, selected: Selection()) } <= 0.1)
    }
    @Test(.disabled("waits on PN-6")) func marqueeScales() {
        let (small, big) = (Self.index(), Self.index(1_000))
        #expect(Self.ms { _ = big.inside(Self.tall) } < 3 * Self.ms { _ = small.inside(Self.page) })
    }
    @Test(.disabled("waits on PN-6")) func selectionIsLinear() {
        let refs = Self.index(1_000).inside(Self.tall)
        func select(_ n: Int) -> Double { Self.ms { var s = Selection<AnchorRef>(); s.replace(Array(refs.prefix(n))); _ = refs.map(s.contains) } }
        #expect(select(10_000) < 3 * select(5_000))
    }
}
