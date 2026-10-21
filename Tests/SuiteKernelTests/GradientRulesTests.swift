// GradientRulesTests.swift (gradient-fill GF-5): the angle, stop and box rules. A 45° line on a square box runs
// corner to corner, a move clamps and the selection follows, two stops can't lose one, a conversion keeps the stops,
// a new stop takes the colour the gradient shows there. Its mutations: Tests/mutations/SuiteKernel.GradientRules.json.
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

    @Test func rotated45() throws {
        let (start, end) = try #require(Self.ends(GradientRules.rotated(Self.linear(), to: 45, in: Self.square)))
        #expect(Self.near(start, 0, 0) && Self.near(end, 100, 100))
    }
    @Test func rotated135() throws {
        let (start, end) = try #require(Self.ends(GradientRules.rotated(Self.linear(), to: 135, in: Self.square)))
        #expect(Self.near(start, 100, 0) && Self.near(end, 0, 100))
    }
    @Test func rotatedZeroOnWideBox() throws {
        let wide = Rect(minX: 0, minY: 0, maxX: 200, maxY: 100)
        let (start, end) = try #require(Self.ends(GradientRules.rotated(Self.linear(), to: 0, in: wide)))
        #expect(Self.near(start, 0, 50) && Self.near(end, 200, 50))
    }
    @Test func angleReadsBack() throws {
        let angle = try #require(GradientRules.angle(of: GradientRules.rotated(Self.linear(), to: 45, in: Self.square)))
        #expect(abs(angle - 45) < 1e-9)
        #expect(GradientRules.angle(of: .solid(Self.blue)) == nil)
    }
    @Test func moveResorts() {
        let moved = GradientRules.movingStop(Self.linear([0, 0.5, 0.9]), index: 0, to: 1.5)
        #expect(moved.fill.stops.map(\.offset) == [0.5, 0.9, 1])
        #expect(moved.index == 2 && moved.fill.stops.last?.color == Self.blue)
    }
    @Test func removeKeepsTwo() {
        #expect(GradientRules.removingStop(Self.linear(), index: 0) == nil)
        #expect(GradientRules.removingStop(Self.linear([0, 0.5, 1]), index: 1)?.stops.map(\.offset) == [0, 1])
    }
    @Test func colorAtHalf() {
        let fill = Fill.linear(stops: [GradientStop(offset: 0, color: .black), GradientStop(offset: 1, color: .white)],
                               start: Point(x: 0, y: 0), end: Point(x: 1, y: 0))
        #expect(GradientRules.color(of: fill, at: 0.5) == FillColor(r: 0.5, g: 0.5, b: 0.5))
    }
    @Test func mappedUnitToFrame() throws {
        let unit = Fill.linear(stops: Self.linear().stops, start: Point(x: 0, y: 0), end: Point(x: 1, y: 1))
        let frame = Rect(minX: 10, minY: 20, maxX: 110, maxY: 70)
        let mapped = GradientRules.mapped(unit, from: Rect(minX: 0, minY: 0, maxX: 1, maxY: 1), to: frame)
        let (start, end) = try #require(Self.ends(mapped))
        #expect(Self.near(start, 10, 20) && Self.near(end, 110, 70))
    }
    @Test func colorHardEdgeAndClamp() {
        let red = Self.red
        let fill = Fill.linear(stops: [GradientStop(offset: 0.2, color: Self.blue), GradientStop(offset: 0.5, color: Self.blue),
                                       GradientStop(offset: 0.5, color: red), GradientStop(offset: 0.8, color: red)],
                               start: Point(x: 0, y: 0), end: Point(x: 1, y: 0))
        #expect(GradientRules.color(of: fill, at: 0.5) == red)
        #expect(GradientRules.color(of: fill, at: 0) == Self.blue && GradientRules.color(of: fill, at: 1) == red)
        #expect(GradientRules.color(of: .solid(red), at: 0.3) == red)
    }
    @Test func addingStopTakesTheColorThere() throws {
        let fill = Fill.linear(stops: [GradientStop(offset: 0, color: .black), GradientStop(offset: 1, color: .white)],
                               start: Point(x: 0, y: 0), end: Point(x: 1, y: 0))
        let added = try #require(GradientRules.addingStop(fill, at: 0.5))
        #expect(added.index == 1 && added.fill.stops.map(\.offset) == [0, 0.5, 1])
        #expect(added.fill.stops[1].color == FillColor(r: 0.5, g: 0.5, b: 0.5))
        #expect(GradientRules.addingStop(.solid(Self.red), at: 0.5) == nil)
        let full = Self.linear((0..<GradientRules.maxStops).map { Double($0) / Double(GradientRules.maxStops - 1) })
        #expect(GradientRules.addingStop(full, at: 0.5) == nil)
    }
    @Test func moveKeepsTheIndexInPlace() {
        let moved = GradientRules.movingStop(Self.linear([0, 0.5, 1]), index: 1, to: -3)
        #expect(moved.index == 1 && moved.fill.stops.map(\.offset) == [0, 0, 1])
        #expect(GradientRules.movingStop(Self.linear(), index: 5, to: 0.5).fill == Self.linear())
    }
    @Test func recolorsAStop() {
        #expect(GradientRules.recoloring(Self.linear(), index: 1, to: Self.red).stops.map(\.color) == [Self.blue, Self.red])
        #expect(GradientRules.recoloring(.solid(Self.blue), index: 0, to: Self.red) == .solid(Self.red))
        #expect(GradientRules.recoloring(Self.linear(), index: 9, to: Self.red) == Self.linear())
    }
    @Test func convertsBetweenTypes() throws {
        let solidToLinear = GradientRules.converted(.solid(Self.red), to: .linear, in: Self.square)
        #expect(solidToLinear.stops == [GradientStop(offset: 0, color: Self.red), GradientStop(offset: 1, color: .white)])
        let (start, end) = try #require(Self.ends(solidToLinear))
        #expect(Self.near(start, 0, 50) && Self.near(end, 100, 50))
        let radial = GradientRules.converted(Self.linear(), to: .radial, in: Self.square)
        guard case .radial(let stops, let center, let radius) = radial else { Issue.record("not radial"); return }
        #expect(stops == Self.linear().stops && Self.near(center, 50, 50) && abs(radius - 50 * 2.0.squareRoot()) < 1e-9)
        #expect(GradientRules.converted(radial, to: .linear, in: Self.square).stops == Self.linear().stops)
        #expect(GradientRules.converted(Self.linear(), to: .solid, in: Self.square) == .solid(Self.blue))
    }
    @Test func rotatedLeavesNonFiniteAndRadial() {
        #expect(GradientRules.rotated(Self.linear(), to: .nan, in: Self.square) == Self.linear())
        let radial = Fill.radial(stops: Self.linear().stops, center: Point(x: 50, y: 50), radius: 10)
        #expect(GradientRules.rotated(radial, to: 45, in: Self.square) == radial)
        #expect(GradientRules.angle(of: Self.linear()) == 0)
        #expect(abs((GradientRules.angle(of: GradientRules.rotated(Self.linear(), to: 270, in: Self.square)) ?? 0) - 270) < 1e-9)
    }
    @Test func mappedScalesARadius() {
        let unit = Rect(minX: 0, minY: 0, maxX: 1, maxY: 1)
        let radial = Fill.radial(stops: Self.linear().stops, center: Point(x: 0.5, y: 0.5), radius: 0.5)
        let frame = Rect(minX: 0, minY: 0, maxX: 200, maxY: 50)
        #expect(GradientRules.mapped(radial, from: unit, to: frame) == .radial(stops: Self.linear().stops, center: Point(x: 100, y: 25), radius: 50))
        #expect(GradientRules.mapped(radial, from: Rect(minX: 0, minY: 0, maxX: 0, maxY: 0), to: frame) == radial)
    }
}
