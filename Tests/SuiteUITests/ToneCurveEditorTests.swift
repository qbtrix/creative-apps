// ToneCurveEditorTests.swift: ToneCurveEditor's static point math: add, move
// (x between neighbours, ends at 0 and 1), remove (never an end), arrow nudges
// (0.01, Shift 0.1, y in 0...1), hit test, out-of-well test past the margin,
// the square plot and the histogram outline; ToneCurveGesture, one end per
// gesture through EditRun (IC-9); SuiteCurvePointEditing, the UC15
// conformance; the point ids and the `curve-drag` series. No rendering here.
// Mutating calls go into a local first: #expect can't call a mutating member.
// macOS only.
import CoreGraphics
@testable import SuiteUI
import Testing

private let s = [CGPoint(x: 0, y: 0), CGPoint(x: 0.25, y: 0.2), CGPoint(x: 0.75, y: 0.8), CGPoint(x: 1, y: 1)]

@Test func addingAtHalfInsertsBetweenTheRightNeighbours() throws {
    let added = try #require(ToneCurveEditor.added(CGPoint(x: 0.5, y: 0.6), to: s))
    #expect(added.index == 2)
    #expect(added.points == [s[0], s[1], CGPoint(x: 0.5, y: 0.6), s[2], s[3]])
    // y is held to 0...1; a point on top of a neighbour, past an end or not finite is refused.
    #expect(ToneCurveEditor.added(CGPoint(x: 0.5, y: 1.4), to: s)?.points[2] == CGPoint(x: 0.5, y: 1))
    #expect(ToneCurveEditor.added(CGPoint(x: 0.255, y: 0.3), to: s) == nil)
    #expect(ToneCurveEditor.added(CGPoint(x: 0.005, y: 0.3), to: s) == nil)
    #expect(ToneCurveEditor.added(CGPoint(x: 1.2, y: 0.3), to: s) == nil)
    #expect(ToneCurveEditor.added(CGPoint(x: CGFloat.nan, y: 0.3), to: s) == nil)
}

@Test func aDraggedPointStaysBetweenItsNeighbours() {
    let gap = ToneCurveEditor.minimumGap
    #expect(ToneCurveEditor.moved(1, to: CGPoint(x: 0.9, y: 0.5), in: s)[1] == CGPoint(x: 0.75 - gap, y: 0.5))
    #expect(ToneCurveEditor.moved(1, to: CGPoint(x: -0.3, y: -0.2), in: s)[1] == CGPoint(x: gap, y: 0))
    #expect(ToneCurveEditor.moved(2, to: CGPoint(x: 0.6, y: 0.7), in: s) == [s[0], s[1], CGPoint(x: 0.6, y: 0.7), s[3]])
    // An index that isn't there changes nothing.
    #expect(ToneCurveEditor.moved(9, to: CGPoint(x: 0.5, y: 0.5), in: s) == s)
}

@Test func theEndsKeepTheirXAndRefuseRemoval() {
    #expect(ToneCurveEditor.moved(0, to: CGPoint(x: 0.3, y: 0.4), in: s)[0] == CGPoint(x: 0, y: 0.4))
    #expect(ToneCurveEditor.moved(3, to: CGPoint(x: 0.6, y: 1.3), in: s)[3] == CGPoint(x: 1, y: 1))
    #expect(ToneCurveEditor.removed(0, from: s) == nil)
    #expect(ToneCurveEditor.removed(3, from: s) == nil)
    #expect(ToneCurveEditor.removed(7, from: s) == nil)
}

@Test func deleteRemovesTheFocusedMiddlePoint() {
    #expect(ToneCurveEditor.removed(1, from: s) == [s[0], s[2], s[3]])
    #expect(ToneCurveEditor.removed(2, from: s) == [s[0], s[1], s[3]])
}

@Test func arrowNudgesStepAndClamp() {
    // Up is 0.01, Shift-Up 0.1; y stays in 0...1.
    #expect(ToneCurveEditor.nudged(1, dx: 0, dy: 1, coarse: false, in: s)[1] == CGPoint(x: 0.25, y: 0.21))
    #expect(ToneCurveEditor.nudged(1, dx: 0, dy: 1, coarse: true, in: s)[1] == CGPoint(x: 0.25, y: 0.3))
    let high = [s[0], CGPoint(x: 0.5, y: 0.95), s[3]]
    #expect(ToneCurveEditor.nudged(1, dx: 0, dy: 1, coarse: true, in: high)[1] == CGPoint(x: 0.5, y: 1))
    #expect(ToneCurveEditor.nudged(0, dx: 0, dy: -1, coarse: false, in: s)[0] == CGPoint(x: 0, y: 0))
    // Left and right move x, but never past a neighbour or off an end.
    #expect(ToneCurveEditor.nudged(1, dx: 1, dy: 0, coarse: false, in: s)[1] == CGPoint(x: 0.26, y: 0.2))
    #expect(ToneCurveEditor.nudged(2, dx: -1, dy: 0, coarse: true, in: [s[0], s[1], CGPoint(x: 0.3, y: 0.5), s[3]])[2].x == 0.25 + ToneCurveEditor.minimumGap)
    #expect(ToneCurveEditor.nudged(3, dx: -1, dy: 0, coarse: true, in: s)[3] == s[3])
}

@Test func hitTestPicksTheNearestPointInReach() {
    let plot = ToneCurveEditor.plot(in: CGSize(width: 236, height: 180))
    // A square plot, centred in the well, inside its inset.
    #expect(plot.width == plot.height && plot.height == 180 - 24 && plot.midX == 118 && plot.midY == 90)
    let at = { (p: CGPoint) in CurveEditor.viewPoint(p, in: plot, range: 0...1) }
    #expect(ToneCurveEditor.hitIndex(at: at(s[1]), of: s, in: plot) == 1)
    #expect(ToneCurveEditor.hitIndex(at: at(s[2]).applying(.init(translationX: 6, y: -6)), of: s, in: plot) == 2)
    #expect(ToneCurveEditor.hitIndex(at: at(CGPoint(x: 0.5, y: 0.5)), of: s, in: plot) == nil)
    // Out of the well is past its bounds by more than the margin, not past the plot.
    let size = CGSize(width: 236, height: 180)
    let m = ToneCurveEditor.outOfWellMargin
    #expect(m == 8)
    #expect(!ToneCurveEditor.isOutOfWell(CGPoint(x: 230, y: 175), size: size))
    #expect(!ToneCurveEditor.isOutOfWell(CGPoint(x: -4, y: 90), size: size))
    #expect(!ToneCurveEditor.isOutOfWell(CGPoint(x: 236 + m, y: 180 + m), size: size))
    #expect(ToneCurveEditor.isOutOfWell(CGPoint(x: 118, y: 196), size: size))
    #expect(ToneCurveEditor.isOutOfWell(CGPoint(x: -m - 1, y: 90), size: size))
    #expect(ToneCurveEditor.isOutOfWell(CGPoint(x: 118, y: -m - 0.5), size: size))
    #expect(ToneCurveEditor.isOutOfWell(CGPoint(x: 236 + m + 0.5, y: 90), size: size))
}

private let well = CGSize(width: 236, height: 180)
private let plot = ToneCurveEditor.plot(in: well)
private func view(_ p: CGPoint) -> CGPoint { CurveEditor.viewPoint(p, in: plot, range: 0...1) }

@Test func aClickAddsAPointInOrderAndEndsOnce() throws {
    var gesture = ToneCurveGesture()
    let added = try #require(gesture.pressed(at: view(CGPoint(x: 0.5, y: 0.6)), points: s, in: plot))
    #expect(added.count == 5 && added.map(\.x) == added.map(\.x).sorted())
    #expect(abs(added[2].x - 0.5) < 1e-9 && abs(added[2].y - 0.6) < 1e-9)
    #expect(gesture.drag?.index == 2)
    let still = gesture.dragged(to: view(CGPoint(x: 0.5, y: 0.6)), by: .zero, in: plot, well: well)
    #expect(still == nil)
    let first = gesture.released()
    let second = gesture.released()
    #expect(first && !second)
    #expect(gesture.run.ends == 1 && gesture.drag == nil)
}

@Test func aDragMovesFromThePressAndEndsOnce() throws {
    var gesture = ToneCurveGesture()
    let picked = gesture.pressed(at: view(s[1]), points: s, in: plot)
    #expect(picked == nil && gesture.drag?.index == 1)
    var sent: [[CGPoint]] = []
    for dy in [-10.0, -20.0, -30.0] {
        let at = CGPoint(x: view(s[1]).x, y: view(s[1]).y + dy)
        sent += [try #require(gesture.dragged(to: at, by: CGSize(width: 0, height: dy), in: plot, well: well))]
    }
    #expect(sent.count == 3 && sent.allSatisfy { $0.count == 4 })
    // Each sample moves from where the press began: 30 pt up is 30 / side of the unit square.
    let last = try #require(sent.last)
    #expect(abs(last[1].y - (0.2 + 30 / plot.height)) < 1e-9 && last[1].x == 0.25)
    let ended = gesture.released()
    #expect(ended && gesture.run.ends == 1)
}

@Test func aDragPastTheMarginRemovesAMiddlePointButNeverAnEnd() throws {
    var gesture = ToneCurveGesture()
    _ = gesture.pressed(at: view(s[2]), points: s, in: plot)
    let inMargin = CGPoint(x: well.width + ToneCurveEditor.outOfWellMargin - 1, y: 40)
    let kept = try #require(gesture.dragged(to: inMargin, by: CGSize(width: 40, height: 0), in: plot, well: well))
    #expect(kept.count == 4)
    let past = CGPoint(x: well.width + ToneCurveEditor.outOfWellMargin + 4, y: 40)
    let removed = try #require(gesture.dragged(to: past, by: CGSize(width: 60, height: 0), in: plot, well: well))
    #expect(removed == [s[0], s[1], s[3]])
    let ended = gesture.released()
    #expect(ended && gesture.run.ends == 1)

    // An end point dragged out moves (x held at its end) and stays.
    var end = ToneCurveGesture()
    _ = end.pressed(at: view(s[3]), points: s, in: plot)
    let out = CGPoint(x: well.width + 40, y: -40)
    let ends = try #require(end.dragged(to: out, by: CGSize(width: 40, height: -40), in: plot, well: well))
    #expect(ends.count == 4 && ends[3] == CGPoint(x: 1, y: 1) && ends[0] == s[0])
}

@Test func aPressThatChangesNothingEndsNothing() {
    // On a point without moving, and on a spot too close to a neighbour to add one.
    var gesture = ToneCurveGesture()
    _ = gesture.pressed(at: view(s[1]), points: s, in: plot)
    let onPoint = gesture.released()
    let near = gesture.pressed(at: view(CGPoint(x: 0.255, y: 0.9)), points: s, in: plot)
    let moved = gesture.dragged(to: .zero, by: CGSize(width: 5, height: 5), in: plot, well: well)
    let nearEnd = gesture.released()
    #expect(!onPoint && near == nil && moved == nil && !nearEnd && gesture.run.ends == 0)
}

@Test func eachNudgeAndDeleteEndsOnceAndWaitsForADrag() {
    var gesture = ToneCurveGesture()
    let up = gesture.keyed(), down = gesture.keyed()
    #expect(up && down && gesture.run.ends == 2 && !gesture.run.isOpen)
    // ↑ on the focused point is 0.01.
    let up1 = ToneCurveEditor.nudged(2, dx: 0, dy: 1, coarse: false, in: s)[2]
    #expect(abs(up1.y - 0.81) < 1e-9 && up1.x == 0.75)
    _ = gesture.pressed(at: view(s[1]), points: s, in: plot)
    let during = gesture.keyed()
    _ = gesture.released()
    #expect(!during && gesture.run.ends == 2)
}

@Test func theConformanceKeepsTheLiveRules() throws {
    let c = SuiteCurvePointEditing()
    let p = s.map { PlanePoint(x: Double($0.x), y: Double($0.y)) }
    let added = try #require(c.added(PlanePoint(x: 0.5, y: 0.6), to: p))
    #expect(added.index == 2 && added.points.map(\.x) == added.points.map(\.x).sorted())
    #expect(c.removed(0, from: p) == nil && c.removed(3, from: p) == nil && c.removed(1, from: p)?.count == 3)
    #expect(c.moved(0, to: PlanePoint(x: 0.4, y: 0.3), in: p)[0] == PlanePoint(x: 0, y: 0.3))
    let nudged = c.nudged(1, dx: 0, dy: 1, coarse: false, in: p)[1]
    #expect(abs(nudged.y - 0.21) < 1e-9 && nudged.x == 0.25)
    // The live rule has a margin; the Fake has none.
    let extent = PlaneExtent(width: 180, height: 180)
    #expect(!c.isOutOfWell(PlanePoint(x: -1, y: 5), extent: extent))
    #expect(FakeCurvePointEditing().isOutOfWell(PlanePoint(x: -1, y: 5), extent: extent))
    #expect(c.isOutOfWell(PlanePoint(x: -9, y: 5), extent: extent))
}

@Test func pointsAreNamedAndDragsReportCurveDrag() {
    #expect(ToneCurveEditor.pointID("photo.curves", 0) == "photo.curves.point1")
    #expect(ToneCurveEditor.pointID("suite.toneCurve", 2) == "suite.toneCurve.point3")
    #expect(ToneCurveEditor.sample(eventTime: 1, shownAt: 1.02) == ProbeSample(series: "curve-drag", eventTime: 1, shownAt: 1.02))
}

@Test func histogramIsNormalisedToItsTallestBin() {
    let bins = ToneCurveEditor.histogramPoints([2, 8, -1, .nan])
    #expect(bins == [CGPoint(x: 0.125, y: 0.25), CGPoint(x: 0.375, y: 1), CGPoint(x: 0.625, y: 0), CGPoint(x: 0.875, y: 0)])
    #expect(ToneCurveEditor.histogramPoints([]).isEmpty)
    #expect(ToneCurveEditor.histogramPoints([0, 0, .infinity]).isEmpty)
}
