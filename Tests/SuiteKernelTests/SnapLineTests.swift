// SnapLineTests.swift: the alignment-line engine (snapping SN-2). On A's
// candidates in `cards` (B, C, Title, Pair, Locked, Desktop and the page),
// `SnapLines.offset` finds the smallest offset within the 6 pt tolerance
// that puts a value on a candidate's min, centre or max, and `lines(on:)`
// names the lines a box sits on, spanning the box and the candidates on it.
import Foundation
import Testing
import SuiteKernel

@Suite struct SnapLineTests {
    /// A frame at (`x`, `y`), `w` × `h`.
    static func frame(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> Rect {
        Rect(minX: x, minY: y, maxX: x + w, maxY: y + h)
    }

    /// What a drag of A in `cards` can snap to.
    static let cards: [SnapCandidate] = [
        SnapCandidate(id: "b", frame: frame(300, 140, 200, 80)),
        SnapCandidate(id: "c", frame: frame(700, 100, 100, 120)),
        SnapCandidate(id: "title", frame: frame(100, 40, 200, 32)),
        SnapCandidate(id: "pair", frame: frame(900, 400, 300, 100)),
        SnapCandidate(id: "locked", frame: frame(400, 600, 100, 100)),
        SnapCandidate(id: "desktop", frame: frame(0, 0, 1440, 1024)),
        SnapCandidate(id: nil, frame: frame(0, 0, 1440, 1024)),
    ]

    /// The handle tolerance the checks snap with.
    static let tolerance = 6.0

    let engine = SnapLines(Self.cards)

    func offset(_ axis: SnapLine.Axis, _ values: [Double]) -> Double? {
        engine.offset(axis, for: values, tolerance: Self.tolerance)
    }

    // MARK: offset

    @Test func edgesSnapToTheNearestLine() throws {
        let d = try #require(offset(.x, [297.4, 347.4, 397.4]))
        #expect(abs(d - 2.6) < 1e-9)
    }

    @Test func toleranceIsInclusive() {
        #expect(offset(.x, [294]) == 6)
        #expect(offset(.x, [293.9]) == nil)
    }

    @Test func snapsUpOnY() throws {
        let d = try #require(offset(.y, [100.4, 140.4, 180.4]))
        #expect(abs(d + 0.4) < 1e-9)
    }

    @Test func equalDistancePicksTheNegative() {
        let two = SnapLines([SnapCandidate(id: "low", frame: Self.frame(100, 500, 0, 0)),
                             SnapCandidate(id: "high", frame: Self.frame(106, 500, 0, 0))])
        #expect(two.offset(.x, for: [103], tolerance: 6) == -3)
        #expect(two.offset(.x, for: [97, 103], tolerance: 6) == -3)
    }

    @Test func nearestLineWins() {
        #expect(offset(.x, [298, 403]) == 2)
    }

    @Test func lineAcrossABucketEdgeIsFound() {
        let edge = SnapLines([SnapCandidate(id: "edge", frame: Self.frame(129, 0, 871, 10))])
        #expect(edge.offset(.x, for: [127], tolerance: 6) == 2)
        #expect(edge.offset(.x, for: [131], tolerance: 6) == -2)
    }

    @Test func badInputsGiveNil() {
        #expect(offset(.x, [.nan, .infinity]) == nil)
        #expect(engine.offset(.x, for: [300], tolerance: -1) == nil)
        #expect(SnapLines([]).offset(.x, for: [300], tolerance: 6) == nil)
    }

    // MARK: lines(on:)

    @Test func linesOfABoxOnItsLines() {
        let found = engine.lines(on: Self.frame(300, 100, 100, 80))
        #expect(found == [
            SnapLine(axis: .x, at: 300, from: 40, to: 220),
            SnapLine(axis: .x, at: 400, from: 100, to: 700),
            SnapLine(axis: .y, at: 100, from: 300, to: 800),
            SnapLine(axis: .y, at: 140, from: 300, to: 500),
            SnapLine(axis: .y, at: 180, from: 300, to: 500),
        ])
    }

    @Test func boxAtAFractionHasNoLine() {
        #expect(engine.lines(on: Self.frame(300.5, 100.5, 100, 80)).isEmpty)
    }

    @Test func zeroSizeBoxGivesOneLinePerPosition() {
        let found = engine.lines(on: Self.frame(300, 140, 0, 0))
        #expect(found.map(\.at) == [300, 140])
    }
}
