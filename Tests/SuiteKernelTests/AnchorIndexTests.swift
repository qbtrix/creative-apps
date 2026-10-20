// AnchorIndexTests.swift (pen-paths PN-1 written, PN-6 turns on): hits and marquees on the anchor grid.
import Testing
import SuiteKernel
@Suite struct AnchorIndexTests {
    static func p(_ x: Double, _ y: Double) -> Point { Point(x: x, y: y) }
    static func r(_ i: Int) -> AnchorRef { AnchorRef(contour: 0, index: i) }
    /// Anchors at each point, the first with an out handle 2 pt right of it.
    static func index(_ points: [Point]) -> AnchorIndex {
        let anchors = points.enumerated().map { i, pt in VectorAnchor(point: pt, handleOut: i == 0 ? p(pt.x + 2, pt.y) : nil) }
        return AnchorIndex(VectorPath(contours: [VectorContour(anchors: anchors, closed: false)]), toDocument: .identity)
    }
    static let pair = index([p(10, 10), p(300, 10)])
    @Test func handleBeatsAnchorUnderIt() {
        #expect(Self.pair.hit(Self.p(11, 10), reach: 4, selected: Selection([Self.r(0)])) == .handle(Self.r(0), .handleOut))
    }
    @Test func unselectedHandlesDontHit() {
        #expect(Self.pair.hit(Self.p(11, 10), reach: 4, selected: Selection()) == .anchor(Self.r(0)))
    }
    @Test func insideIsExactAcrossCellEdges() {
        let index = Self.index([Self.p(63.9, 10), Self.p(64, 10), Self.p(64.1, 10), Self.p(130, 10)])
        #expect(index.inside(Rect(minX: 63.95, minY: 0, maxX: 128, maxY: 20)) == [Self.r(1), Self.r(2)] && index.count == 4)
    }
    @Test func negativeCells() {
        // Cells floor toward minus infinity: -1 lands in cell -1, never in cell 0 beside 1.
        #expect(AnchorIndex.slot(-1) == -1 && AnchorIndex.slot(-70) == -2 && AnchorIndex.slot(1) == 0)
        let index = Self.index([Self.p(-70, -70), Self.p(-1, -1), Self.p(1, 1)])
        #expect(index.inside(Rect(minX: -80, minY: -80, maxX: -0.5, maxY: -0.5)) == [Self.r(0), Self.r(1)])
    }
    @Test func edgeAnchorFound() {
        let index = Self.index([Self.p(128, 128)])
        #expect(index.hit(Self.p(127.5, 127.5), reach: 2, selected: Selection()) == .anchor(Self.r(0)))
        #expect(index.inside(Rect(minX: 128, minY: 128, maxX: 128, maxY: 128)) == [Self.r(0)])
    }
}
