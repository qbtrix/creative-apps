// GradientRulesTests.swift (gradient-fill GF-1 written, GF-5 turns on): the angle, stop and box rules. A 45° line
// on a square box runs corner to corner, a move clamps and the selection follows, two stops can't lose one.
// Disabled by name until GF-5 builds `GradientRules`' bodies.
import Testing
import SuiteKernel

@Suite struct GradientRulesTests {
    static let square = Rect(minX: 0, minY: 0, maxX: 100, maxY: 100)
    static let blue = FillColor(r: 0, g: 0, b: 1), red = FillColor(r: 1, g: 0, b: 0)
    /// A linear fill through stops at `offsets`, blue to white, left to right on the square.
    static func linear(_ offsets: [Double] = [0, 1]) -> Fill {
        .linear(stops: offsets.enumerated().map { GradientStop(offset: $1, color: $0 == 0 ? blue : .white) },
                start: Point(x: 0, y: 50), end: Point(x: 100, y: 50))
    }
    /// The line's two ends, nil for a solid or radial fill.
    static func ends(_ fill: Fill) -> (Point, Point)? { if case .linear(_, let start, let end) = fill { (start, end) } else { nil } }
    static func near(_ p: Point, _ x: Double, _ y: Double) -> Bool { abs(p.x - x) < 1e-9 && abs(p.y - y) < 1e-9 }

    @Test(.disabled("waits on GF-5")) func rotated45() throws {
        let (start, end) = try #require(Self.ends(GradientRules.rotated(Self.linear(), to: 45, in: Self.square)))
        #expect(Self.near(start, 0, 0) && Self.near(end, 100, 100))
    }
    @Test(.disabled("waits on GF-5")) func rotated135() throws {
        let (start, end) = try #require(Self.ends(GradientRules.rotated(Self.linear(), to: 135, in: Self.square)))
        #expect(Self.near(start, 100, 0) && Self.near(end, 0, 100))
    }
    @Test(.disabled("waits on GF-5")) func rotatedZeroOnWideBox() throws {
        let wide = Rect(minX: 0, minY: 0, maxX: 200, maxY: 100)
        let (start, end) = try #require(Self.ends(GradientRules.rotated(Self.linear(), to: 0, in: wide)))
        #expect(Self.near(start, 0, 50) && Self.near(end, 200, 50))
    }
    @Test(.disabled("waits on GF-5")) func angleReadsBack() throws {
        let angle = try #require(GradientRules.angle(of: GradientRules.rotated(Self.linear(), to: 45, in: Self.square)))
        #expect(abs(angle - 45) < 1e-9)
        #expect(GradientRules.angle(of: .solid(Self.blue)) == nil)
    }
    @Test(.disabled("waits on GF-5")) func moveResorts() {
        let moved = GradientRules.movingStop(Self.linear([0, 0.5, 0.9]), index: 0, to: 1.5)
        #expect(moved.fill.stops.map(\.offset) == [0.5, 0.9, 1])
        #expect(moved.index == 2 && moved.fill.stops.last?.color == Self.blue)
    }
    @Test(.disabled("waits on GF-5")) func removeKeepsTwo() {
        #expect(GradientRules.removingStop(Self.linear(), index: 0) == nil)
        #expect(GradientRules.removingStop(Self.linear([0, 0.5, 1]), index: 1)?.stops.map(\.offset) == [0, 1])
    }
    @Test(.disabled("waits on GF-5")) func colorAtHalf() {
        let fill = Fill.linear(stops: [GradientStop(offset: 0, color: .black), GradientStop(offset: 1, color: .white)],
                               start: Point(x: 0, y: 0), end: Point(x: 1, y: 0))
        #expect(GradientRules.color(of: fill, at: 0.5) == FillColor(r: 0.5, g: 0.5, b: 0.5))
    }
    @Test(.disabled("waits on GF-5")) func mappedUnitToFrame() throws {
        let unit = Fill.linear(stops: Self.linear().stops, start: Point(x: 0, y: 0), end: Point(x: 1, y: 1))
        let frame = Rect(minX: 10, minY: 20, maxX: 110, maxY: 70)
        let mapped = GradientRules.mapped(unit, from: Rect(minX: 0, minY: 0, maxX: 1, maxY: 1), to: frame)
        let (start, end) = try #require(Self.ends(mapped))
        #expect(Self.near(start, 10, 20) && Self.near(end, 110, 70))
    }
}
