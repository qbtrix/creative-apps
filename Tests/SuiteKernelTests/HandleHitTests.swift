// HandleHitTests.swift (editor-kernel EK-19, slice EK-box, KJ6): which box
// handle is under the pointer. Written against the EK-3 stubs and disabled
// until EK-20 gives HandleHit its body. Document y grows downwards.
import Foundation
import Testing
import SuiteKernel

@Suite struct HandleHitTests {
    let box = Rect(minX: 0, minY: 0, maxX: 100, maxY: 50)

    @Test(.disabled("waits on EK-20")) func picksEachHandle() {
        let expected: [(Point, EditorHandle)] = [
            (Point(x: 1, y: -1), .topLeft),
            (Point(x: 50, y: 2), .top),
            (Point(x: 102, y: 1), .topRight),
            (Point(x: 98, y: 25), .right),
            (Point(x: 99, y: 52), .bottomRight),
            (Point(x: 51, y: 49), .bottom),
            (Point(x: -2, y: 48), .bottomLeft),
            (Point(x: 1, y: 26), .left),
        ]
        for (p, handle) in expected {
            #expect(HandleHit.handle(at: p, in: box, tolerance: 4) == handle, "\(p)")
        }
    }

    @Test(.disabled("waits on EK-20")) func insideOrNone() {
        #expect(HandleHit.handle(at: Point(x: 30, y: 30), in: box, tolerance: 4) == .inside)
        #expect(HandleHit.handle(at: Point(x: 25, y: 1), in: box, tolerance: 4) == .inside)
        #expect(HandleHit.handle(at: Point(x: 200, y: 200), in: box, tolerance: 4) == nil)
        #expect(HandleHit.handle(at: Point(x: -10, y: 25), in: box, tolerance: 4) == nil)
        #expect(HandleHit.handle(at: Point(x: 50, y: -6), in: box, tolerance: 4) == nil)
    }

    @Test(.disabled("waits on EK-20")) func chebyshev() {
        // 3 along each axis is 3 in Chebyshev distance but 4.24 in Euclidean.
        #expect(HandleHit.handle(at: Point(x: 3, y: 3), in: box, tolerance: 4) == .topLeft)
        #expect(HandleHit.handle(at: Point(x: -3.5, y: -3.5), in: box, tolerance: 4) == .topLeft)
        #expect(HandleHit.handle(at: Point(x: 103.5, y: 53.5), in: box, tolerance: 4) == .bottomRight)
        #expect(HandleHit.handle(at: Point(x: -4.5, y: -1), in: box, tolerance: 4) == nil)
    }

    @Test(.disabled("waits on EK-20")) func cornersWinTies() {
        let small = Rect(minX: 0, minY: 0, maxX: 6, maxY: 6)
        // Each point is 1.5 from a corner and 1.5 from an edge's middle.
        #expect(HandleHit.handle(at: Point(x: 1.5, y: 0), in: small, tolerance: 4) == .topLeft)
        #expect(HandleHit.handle(at: Point(x: 4.5, y: 6), in: small, tolerance: 4) == .bottomRight)
        #expect(HandleHit.handle(at: Point(x: 6, y: 1.5), in: small, tolerance: 4) == .topRight)
        #expect(HandleHit.handle(at: Point(x: 0, y: 4.5), in: small, tolerance: 4) == .bottomLeft)
    }

    @Test(.disabled("waits on EK-20")) func toleranceDividesByZoom() {
        #expect(HandleHit.tolerance(screen: 8, zoom: 2) == 4)
        #expect(HandleHit.tolerance(screen: 8, zoom: 0.5) == 16)
        #expect(HandleHit.tolerance(screen: 8, zoom: 1) == 8)
        // At 4x zoom an 8-point screen tolerance reaches 2 document points.
        let t = HandleHit.tolerance(screen: 8, zoom: 4)
        #expect(HandleHit.handle(at: Point(x: -1.5, y: -1.5), in: box, tolerance: t) == .topLeft)
        #expect(HandleHit.handle(at: Point(x: -3, y: -3), in: box, tolerance: t) == nil)
    }
}
