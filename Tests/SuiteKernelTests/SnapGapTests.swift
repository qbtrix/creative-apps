// SnapGapTests.swift: the gap and even-spacing engine (snapping SN-3). On the
// `cards` frames, `SnapGaps.gaps(around:)` names the gap to the nearest
// neighbour on each side and the spacing hints where gaps are equal, and
// `spacingOffset` finds the smallest offset within the tolerance that makes
// a box's gap equal its neighbour's or centres it between two.
import Foundation
import Testing
import SuiteKernel

@Suite struct SnapGapTests {
    /// A frame at (`x`, `y`), `w` × `h`.
    static func frame(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> Rect {
        Rect(minX: x, minY: y, maxX: x + w, maxY: y + h)
    }

    static let a = frame(100, 100, 100, 80), b = frame(300, 140, 200, 80), c = frame(700, 100, 100, 120)
    static let title = frame(100, 40, 200, 32), pair = frame(900, 400, 300, 100)
    static let locked = frame(400, 600, 100, 100), page = frame(0, 0, 1440, 1024)

    /// The `cards` frames, leaving out `moving`.
    static func cards(without moving: String) -> [SnapCandidate] {
        let all: [(String?, Rect)] = [("a", a), ("b", b), ("c", c), ("title", title), ("pair", pair),
                                      ("locked", locked), ("desktop", page), (nil, page)]
        return all.filter { $0.0 != moving }.map { SnapCandidate(id: $0.0, frame: $0.1) }
    }

    static let tolerance = 4.0

    func words(_ gaps: [SnapGap]) -> String { SnapGuides(gaps: gaps).summary }

    func near(_ value: Double?, _ expected: Double) -> Bool {
        guard let value else { return false }
        return abs(value - expected) < 1e-9
    }

    // MARK: gaps(around:)

    @Test func aAtHomeHasAGapToBAndToTitleOnly() {
        let gaps = SnapGaps(Self.cards(without: "a")).gaps(around: Self.a)
        #expect(gaps == [SnapGap(axis: .x, from: 200, to: 300, across: 160, isSpacing: false),
                         SnapGap(axis: .y, from: 72, to: 100, across: 150, isSpacing: false)])
        #expect(words(gaps) == "gap x 100, gap y 28")
    }

    @Test func anEqualGapNamesBothGapsAsSpacing() {
        let gaps = SnapGaps(Self.cards(without: "c")).gaps(around: Self.frame(600, 100, 100, 120))
        #expect(gaps == [SnapGap(axis: .x, from: 500, to: 600, across: 180, isSpacing: true),
                         SnapGap(axis: .x, from: 200, to: 300, across: 160, isSpacing: true)])
        #expect(words(gaps) == "spacing x 100, spacing x 100")
    }

    @Test func aCentredBoxHasTwoSpacingGaps() {
        let engine = SnapGaps(Self.cards(without: "b"))
        // 150 each side between A and C; Locked sits 380 below.
        #expect(words(engine.gaps(around: Self.frame(350, 140, 200, 80))) == "spacing x 150, spacing x 150, gap y 380")
        // Half a point apart is still equal; a point apart is not.
        #expect(words(engine.gaps(around: Self.frame(350.25, 140, 200, 80))) == "spacing x 150, spacing x 150, gap y 380")
        #expect(words(engine.gaps(around: Self.frame(351, 140, 200, 80))) == "gap x 151, gap x 149, gap y 380")
    }

    @Test func aContainingOrOverlappingFrameIsNoNeighbour() {
        let inside = [SnapCandidate(id: "desktop", frame: Self.page), SnapCandidate(id: "b", frame: Self.b)]
        #expect(SnapGaps(inside).gaps(around: Self.frame(450, 150, 100, 50)).isEmpty)
        #expect(SnapGaps(inside).spacingOffset(.x, for: Self.frame(450, 150, 100, 50), tolerance: 100) == nil)
    }

    @Test func aFrameBesideButNotAcrossIsNoNeighbour() {
        // Locked sits below and to the right of A, never across from it on either axis.
        let gaps = SnapGaps([SnapCandidate(id: "locked", frame: Self.locked)]).gaps(around: Self.a)
        #expect(gaps.isEmpty)
        // One in the same grid cells, right of A and below it: no neighbour either.
        let corner = [SnapCandidate(id: "corner", frame: Self.frame(250, 200, 30, 30))]
        #expect(SnapGaps(corner).gaps(around: Self.a).isEmpty)
    }

    @Test func aTouchingFrameIsNoNeighbour() {
        let touching = [SnapCandidate(id: "t", frame: Self.frame(200, 100, 50, 80))]
        #expect(SnapGaps(touching).gaps(around: Self.a).isEmpty)
    }

    @Test func aNeighbourPast2048IsNone() {
        let far = [SnapCandidate(id: "far", frame: Self.frame(2249, 100, 50, 80))]
        #expect(SnapGaps(far).gaps(around: Self.a).isEmpty)
        let edge = [SnapCandidate(id: "edge", frame: Self.frame(2248, 100, 50, 80))]
        #expect(words(SnapGaps(edge).gaps(around: Self.a)) == "gap x 2048")
    }

    @Test func aHugeFrameStillCounts() {
        let huge = [SnapCandidate(id: "wall", frame: Rect(minX: 300, minY: -1e9, maxX: 1e9, maxY: 1e9))]
        #expect(words(SnapGaps(huge).gaps(around: Self.a)) == "gap x 100")
    }

    @Test func badFramesNeverTrap() {
        let bad = [SnapCandidate(id: "nan", frame: Rect(minX: .nan, minY: 0, maxX: 10, maxY: 10)),
                   SnapCandidate(id: "inf", frame: Rect(minX: 0, minY: 0, maxX: .infinity, maxY: 10))]
        #expect(SnapGaps(bad).gaps(around: Self.a).isEmpty)
        #expect(SnapGaps(bad).spacingOffset(.x, for: Rect(minX: .nan, minY: 0, maxX: 1, maxY: 1), tolerance: 4) == nil)
    }

    // MARK: spacingOffset

    @Test func cAt603MovesLeft3ToMatchBsGapToA() {
        let gaps = SnapGaps(Self.cards(without: "c"))
        #expect(near(gaps.spacingOffset(.x, for: Self.frame(603, 100, 100, 120), tolerance: Self.tolerance), -3))
        #expect(near(gaps.spacingOffset(.x, for: Self.frame(596, 100, 100, 120), tolerance: Self.tolerance), 4))
        #expect(gaps.spacingOffset(.x, for: Self.frame(605, 100, 100, 120), tolerance: Self.tolerance) == nil)
    }

    @Test func aBoxBeforeAPairMatchesTheirGap() {
        // A box left of B and C: its gap to B matches B's gap to C (200).
        let row = [SnapCandidate(id: "b", frame: Self.b), SnapCandidate(id: "c", frame: Self.c)]
        let box = Self.frame(2, 150, 100, 50)
        #expect(near(SnapGaps(row).spacingOffset(.x, for: box, tolerance: Self.tolerance), -2))
    }

    @Test func bAt348_6CentresBetweenAAndC() {
        let gaps = SnapGaps(Self.cards(without: "b"))
        #expect(near(gaps.spacingOffset(.x, for: Self.frame(348.6, 140, 200, 80), tolerance: Self.tolerance), 1.4))
    }

    @Test func theSmallestOffsetWins() {
        // Left: l1's gap to l2 is 100, the box's 101 (-1); right: 98 to r1, r1's 100 to r2 (-2); centre -1.5.
        let row = [SnapCandidate(id: "l2", frame: Self.frame(0, 0, 100, 10)),
                   SnapCandidate(id: "l1", frame: Self.frame(200, 0, 100, 10)),
                   SnapCandidate(id: "r1", frame: Self.frame(500, 0, 100, 10)),
                   SnapCandidate(id: "r2", frame: Self.frame(700, 0, 100, 10))]
        #expect(near(SnapGaps(row).spacingOffset(.x, for: Self.frame(401, 0, 1, 10), tolerance: 4), -1))
    }

    @Test func aTieGivesTheNegative() {
        // Left: l2's gap to l1 is 49, the box's 50 (-1); centre between l1 (50) and r (52) is +1.
        let row = [SnapCandidate(id: "l2", frame: Self.frame(-149, 0, 100, 10)),
                   SnapCandidate(id: "l1", frame: Self.frame(0, 0, 100, 10)),
                   SnapCandidate(id: "r", frame: Self.frame(302, 0, 100, 10))]
        #expect(near(SnapGaps(row).spacingOffset(.x, for: Self.frame(150, 0, 100, 10), tolerance: 4), -1))
    }

    @Test func theYAxisSpacesToo() {
        let column = [SnapCandidate(id: "top", frame: Self.frame(0, 0, 100, 50)),
                      SnapCandidate(id: "mid", frame: Self.frame(0, 100, 100, 50))]
        let box = Self.frame(0, 201, 100, 50)
        #expect(near(SnapGaps(column).spacingOffset(.y, for: box, tolerance: Self.tolerance), -1))
        #expect(SnapGaps(column).spacingOffset(.x, for: box, tolerance: Self.tolerance) == nil)
        #expect(words(SnapGaps(column).gaps(around: Self.frame(0, 200, 100, 50))) == "spacing y 50, spacing y 50")
    }
}
