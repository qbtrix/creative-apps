// CanvasHitMapTests.swift: the hit map (CH-6) names the mark under a point.
// A 1 pt path hits with the 4 pt slop and misses one point further out,
// overlapping marks give the topmost, the nearest mark wins when the point is
// inside none, and an empty map gives nil. macOS only.
import CoreGraphics
import SuiteUI
import Testing

@Suite struct CanvasHitMapTests {
    /// A 1 pt horizontal line at y = 10 from x = 0 to x = 100: its edges sit at y = 9.5 and 10.5.
    private func lineMap() -> CanvasHitMap {
        var map = CanvasHitMap()
        map.addPath(id: "line", points: [CGPoint(x: 0, y: 10), CGPoint(x: 100, y: 10)], width: 1)
        return map
    }

    @Test func pathHitsAtTheSlopAndMissesOnePointBeyond() {
        let map = lineMap()
        #expect(map.slop == 4)
        #expect(map.hit(CGPoint(x: 50, y: 10)) == "line")
        #expect(map.hit(CGPoint(x: 50, y: 14.5)) == "line")
        #expect(map.hit(CGPoint(x: 50, y: 5.5)) == "line")
        #expect(map.hit(CGPoint(x: 50, y: 15.5)) == nil)
        #expect(map.hit(CGPoint(x: 50, y: 4.5)) == nil)
    }

    @Test func pathEndsHitWithinTheSlopOnly() {
        let map = lineMap()
        #expect(map.hit(CGPoint(x: 104.5, y: 10)) == "line")
        #expect(map.hit(CGPoint(x: 105.5, y: 10)) == nil)
    }

    @Test func rectHitsInsideAndAtTheSlop() {
        var map = CanvasHitMap()
        map.addRect(id: "box", CGRect(x: 10, y: 10, width: 20, height: 20))
        #expect(map.hit(CGPoint(x: 20, y: 20)) == "box")
        #expect(map.hit(CGPoint(x: 34, y: 20)) == "box")
        #expect(map.hit(CGPoint(x: 35, y: 20)) == nil)
        #expect(map.hit(CGPoint(x: 20, y: 6)) == "box")
        #expect(map.hit(CGPoint(x: 20, y: 5)) == nil)
    }

    @Test func overlappingMarksGiveTheTopmost() {
        var map = CanvasHitMap()
        map.addRect(id: "bottom", CGRect(x: 0, y: 0, width: 100, height: 100))
        map.addRect(id: "top", CGRect(x: 40, y: 40, width: 20, height: 20))
        #expect(map.hit(CGPoint(x: 50, y: 50)) == "top")
        #expect(map.hit(CGPoint(x: 10, y: 10)) == "bottom")
        #expect(map.marks.map(\.id) == ["bottom", "top"])
    }

    @Test func theNearestMarkWinsWhenThePointIsInsideNone() {
        var map = CanvasHitMap()
        map.addRect(id: "near", CGRect(x: 0, y: 0, width: 10, height: 10))
        map.addRect(id: "far", CGRect(x: 16, y: 0, width: 10, height: 10))
        #expect(map.hit(CGPoint(x: 12, y: 5)) == "near")
        #expect(map.hit(CGPoint(x: 14, y: 5)) == "far")
    }

    @Test func anEmptyMapGivesNil() {
        let map = CanvasHitMap()
        #expect(map.marks.isEmpty)
        #expect(map.hit(CGPoint(x: 0, y: 0)) == nil)
    }

    @Test func anEmptyPathNeverHits() {
        var map = CanvasHitMap()
        map.addPath(id: "empty", points: [], width: 1)
        #expect(map.hit(CGPoint(x: 0, y: 0)) == nil)
    }

    @Test func aClosedPathHitsAlongItsClosingEdge() {
        var map = CanvasHitMap()
        let corners = [CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 0), CGPoint(x: 100, y: 100)]
        map.addPath(id: "open", points: corners, width: 1)
        #expect(map.hit(CGPoint(x: 50, y: 50)) == nil)
        var closed = CanvasHitMap()
        closed.addPath(id: "closed", points: corners, width: 1, closed: true)
        #expect(closed.hit(CGPoint(x: 50, y: 50)) == "closed")
    }

    @Test func aWiderSlopReachesFurther() {
        var map = CanvasHitMap(slop: 8)
        map.addPath(id: "line", points: [CGPoint(x: 0, y: 10), CGPoint(x: 100, y: 10)], width: 1)
        #expect(map.hit(CGPoint(x: 50, y: 18.5)) == "line")
        #expect(map.hit(CGPoint(x: 50, y: 19.5)) == nil)
    }

    @Test func removingAllMarksEmptiesTheMap() {
        var map = lineMap()
        map.removeAll()
        #expect(map == CanvasHitMap())
        #expect(map.hit(CGPoint(x: 50, y: 10)) == nil)
    }
}
