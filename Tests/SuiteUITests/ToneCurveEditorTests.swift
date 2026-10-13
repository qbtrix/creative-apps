// ToneCurveEditorTests.swift: ToneCurveEditor's static point math: add, move
// (x between neighbours, ends at 0 and 1), remove (never an end), arrow nudges
// (0.01, Shift 0.1, y in 0...1), hit test, out-of-well test, the square plot
// and the histogram outline. No rendering here. macOS only.
import CoreGraphics
import SuiteUI
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
    // Out of the well is past its bounds, not past the plot.
    let size = CGSize(width: 236, height: 180)
    #expect(!ToneCurveEditor.isOutOfWell(CGPoint(x: 230, y: 175), size: size))
    #expect(ToneCurveEditor.isOutOfWell(CGPoint(x: 118, y: 196), size: size))
    #expect(ToneCurveEditor.isOutOfWell(CGPoint(x: -4, y: 90), size: size))
}

@Test func histogramIsNormalisedToItsTallestBin() {
    let bins = ToneCurveEditor.histogramPoints([2, 8, -1, .nan])
    #expect(bins == [CGPoint(x: 0.125, y: 0.25), CGPoint(x: 0.375, y: 1), CGPoint(x: 0.625, y: 0), CGPoint(x: 0.875, y: 0)])
    #expect(ToneCurveEditor.histogramPoints([]).isEmpty)
    #expect(ToneCurveEditor.histogramPoints([0, 0, .infinity]).isEmpty)
}
