// DesignRectTests.swift: DesignRect's geometry: the rect a drag covers, edge
// hits, handle points and handle resizing (#200). Runs on Linux and macOS.
import DesignModel
import Testing

private let base = rc(40, 40, 160, 120)

@Test func aDragCoversTheSameRectInEveryDirection() {
    for (a, b) in [(pt(40, 40), pt(200, 160)), (pt(200, 160), pt(40, 40)), (pt(200, 40), pt(40, 160)), (pt(40, 160), pt(200, 40))] {
        #expect(DesignRect(from: a, to: b) == base)
    }
}

@Test func aSquareDragGrowsAwayFromItsStartPoint() {
    #expect(DesignRect(from: pt(40, 40), to: pt(200, 160), square: true) == rc(40, 40, 160, 160))
    #expect(DesignRect(from: pt(200, 160), to: pt(40, 40), square: true) == rc(40, 0, 160, 160))
    #expect(DesignRect(from: pt(40, 40), to: pt(100, 200), square: true) == rc(40, 40, 160, 160))
    #expect(DesignRect(from: pt(40, 40), to: pt(40, 40), square: true) == rc(40, 40, 0, 0))
}

@Test func containsIncludesTheEdges() {
    #expect(base.contains(pt(40, 40)) && base.contains(pt(200, 160)) && base.contains(pt(120, 100)))
    #expect(!base.contains(pt(39.9, 100)) && !base.contains(pt(200.1, 100)))
    #expect(!base.contains(pt(100, 39.9)) && !base.contains(pt(100, 160.1)))
    #expect((base.maxX, base.maxY) == (200, 160))
}

@Test func eachHandleSitsOnItsEdgeOrCorner() {
    let points: [DesignHandle: DesignPoint] = [
        .topLeft: pt(40, 40), .top: pt(120, 40), .topRight: pt(200, 40), .right: pt(200, 100),
        .bottomRight: pt(200, 160), .bottom: pt(120, 160), .bottomLeft: pt(40, 160), .left: pt(40, 100),
    ]
    #expect(DesignHandle.allCases.count == 8)
    for handle in DesignHandle.allCases { #expect(base.point(of: handle) == points[handle]) }
}

@Test func theWorkedResizeExamples() {
    let delta = pt(20, 10)
    #expect(base.resized(.bottomRight, by: delta, keepAspect: false, fromCenter: false) == rc(40, 40, 180, 130))
    #expect(base.resized(.topLeft, by: delta, keepAspect: false, fromCenter: false) == rc(60, 50, 140, 110))
    #expect(base.resized(.bottomRight, by: delta, keepAspect: false, fromCenter: true) == rc(20, 30, 200, 140))
}

@Test func aSideHandleMovesOneEdgeAndIgnoresKeepAspect() {
    #expect(base.resized(.right, by: pt(20, 99), keepAspect: false, fromCenter: false) == rc(40, 40, 180, 120))
    #expect(base.resized(.bottom, by: pt(99, 10), keepAspect: true, fromCenter: false) == rc(40, 40, 160, 130))
    #expect(base.resized(.left, by: pt(20, 99), keepAspect: false, fromCenter: false) == rc(60, 40, 140, 120))
    #expect(base.resized(.top, by: pt(99, 10), keepAspect: false, fromCenter: false) == rc(40, 50, 160, 110))
    #expect(base.resized(.right, by: pt(20, 0), keepAspect: false, fromCenter: true) == rc(20, 40, 200, 120))
}

@Test func keepAspectFollowsTheAxisThatChangedMore() {
    #expect(base.resized(.bottomRight, by: pt(20, 10), keepAspect: true, fromCenter: false) == rc(40, 40, 180, 135))
    // Width grows 10%, height 2.5%: the width leads and the top-left corner stays anchored opposite.
    #expect(base.resized(.topLeft, by: pt(-16, -3), keepAspect: true, fromCenter: false) == rc(24, 28, 176, 132))
    #expect(base.resized(.bottomRight, by: pt(20, 10), keepAspect: true, fromCenter: true) == rc(20, 25, 200, 150))
}

@Test func aResizeStopsAtOneAndNeverFlips() {
    #expect(base.resized(.bottomRight, by: pt(-500, -500), keepAspect: false, fromCenter: false) == rc(40, 40, 1, 1))
    #expect(base.resized(.topLeft, by: pt(500, 500), keepAspect: false, fromCenter: false) == rc(199, 159, 1, 1))
    #expect(base.resized(.bottomRight, by: pt(-500, 0), keepAspect: false, fromCenter: true) == rc(119.5, 40, 1, 120))
    let squeezed = base.resized(.bottomRight, by: pt(-500, -500), keepAspect: true, fromCenter: false)
    #expect(squeezed.width >= 1 && squeezed.height >= 1 && squeezed.x == 40 && squeezed.y == 40)
}

@Test func aNonFiniteDeltaChangesNothing() {
    for bad in [pt(.nan, 1), pt(1, .infinity), pt(-.infinity, .nan)] {
        #expect(base.resized(.bottomRight, by: bad, keepAspect: true, fromCenter: true) == base)
    }
    #expect(base.resized(.top, by: pt(0, 0), keepAspect: false, fromCenter: false) == base)
}
