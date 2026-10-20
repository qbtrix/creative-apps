// AnchorIndexTests.swift (pen-paths PN-1 written, PN-6 turns on): hits and marquees on the anchor grid.
import Testing
@testable import SuiteKernel
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
    @Test func handleTiesGoToHandleIn() {
        // handleOut sits left of handleIn, in the cell read first, and both are 2 pt from the anchor on the cell edge.
        let anchor = VectorAnchor(point: Self.p(64, 10), handleIn: Self.p(66, 10), handleOut: Self.p(62, 10))
        let contour = VectorContour(anchors: [VectorAnchor(point: Self.p(200, 10)), anchor], closed: true)
        let index = AnchorIndex(VectorPath(contours: [contour]), toDocument: .identity)
        for reach in [4.0, 300] {
            #expect(index.hit(Self.p(64, 10), reach: reach, selected: Selection([Self.r(1)])) == .handle(Self.r(1), .handleIn))
        }
    }
    /// The hit a search of every anchor and the whole path gives, with nothing selected.
    static func bruteHit(_ path: VectorPath, _ m: Matrix, _ q: Point, reach: Double) -> PathHit? {
        var best: (AnchorRef, Double)?
        for (c, contour) in path.contours.enumerated() {
            for (i, a) in contour.anchors.enumerated() {
                let d = Self.distance(m.apply(a.point), q)
                if d <= reach, d < best?.1 ?? .infinity { best = (AnchorRef(contour: c, index: i), d) }
            }
        }
        if let best { return .anchor(best.0) }
        guard let l = try? path.transformed(by: m).nearest(to: q, tolerance: reach / 8), l.distance <= reach else { return nil }
        return .segment(l)
    }
    static func distance(_ a: Point, _ b: Point) -> Double { ((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y)).squareRoot() }
    @Test func segmentHitsMatchAWholePathSearch() {
        let curves = VectorPath(contours: [
            VectorContour(anchors: [VectorAnchor(point: Self.p(10, 10), handleOut: Self.p(80, -40)),
                                    VectorAnchor(point: Self.p(150, 60), handleIn: Self.p(120, 140), handleOut: Self.p(200, 20)),
                                    VectorAnchor(point: Self.p(40, 120), handleIn: Self.p(90, 130), handleOut: Self.p(0, 90))], closed: true),
            VectorContour(anchors: [VectorAnchor(point: Self.p(-3000, 0)), VectorAnchor(point: Self.p(3000, 2000))], closed: false),
        ])
        // A quad, a line, a close, then a line over 64 cells but well under the old cap of 1,024.
        let path = VectorPath(elements: curves.elements + [.move(to: Self.p(200, 200)), .quad(control: Self.p(260, 120), to: Self.p(320, 220)),
                                                            .line(to: Self.p(250, 300)), .close, .move(to: Self.p(-20, 300)), .line(to: Self.p(340, -50))])
        let m = Matrix(a: 1.5, b: 0, c: 0, d: 1.5, tx: 7, ty: -3)
        let index = AnchorIndex(path, toDocument: m)
        #expect(index.wide.count == 2, "the two long lines")
        var points = [Self.p(528, 302), Self.p(5000, 5000)]
        for x in stride(from: -40.0, through: 520, by: 9) { for y in stride(from: -80.0, through: 460, by: 11) { points.append(Self.p(x, y)) } }
        for k in 1..<20 {  // beside the long line, which spans too many cells to file
            let at = m.apply(Self.p(-3000 + 300 * Double(k), 100 * Double(k)))
            points.append(Self.p(at.x + 1, at.y - 3))
        }
        var segments = 0
        for q in points {
            let hit = index.hit(q, reach: 6, selected: Selection())
            if case .segment = hit { segments += 1 }
            #expect(hit == Self.bruteHit(path, m, q, reach: 6), "at \(q)")
        }
        #expect(segments > 20)
        let stress = AnchorIndex(AnchorStressFixture.stress, toDocument: .identity)
        for q in [Self.p(528, 302), Self.p(5000, 5000), Self.p(36, 22), Self.p(29, 25)] {
            #expect(stress.hit(q, reach: 4, selected: Selection()) == Self.bruteHit(AnchorStressFixture.stress, .identity, q, reach: 4))
        }
    }
}
