// ShapeRulesTests.swift: the shape tools' spec and rules (shape-tools SH-1, SH-5).
// SH-1's checks run now: a spec round-trips through JSON, and Shapes/ imports
// only Foundation and FlareCore. The SH-5 rows wait, disabled, until SH-5.
import Foundation
import Testing
import SuiteKernel

@Suite struct ShapeRulesTests {
    @Test func specRoundTripsThroughJSON() throws {
        let spec = ShapeSpec(kind: .arrow, sides: 7, points: 9, innerRatio: 0.25, cornerRadius: 4, head: 20,
                             start: Point(x: 0.1, y: 0.2), end: Point(x: 0.9, y: 0.8))
        #expect(try JSONDecoder().decode(ShapeSpec.self, from: JSONEncoder().encode(spec)) == spec)
        let star = ShapeSpec.defaults(.star)
        #expect(star.sides == 5 && star.points == 5 && star.innerRatio == 0.5 && star.cornerRadius == 0 && star.head == 12)
        #expect(ShapeKind.allCases.map(\.rawValue) == ["rectangle", "ellipse", "polygon", "star", "line", "arrow"])
        #expect(ShapeRules.counts == 3...64 && ShapeRules.ratios == 0.1...1.0)
    }

    @Test func shapesImportOnlyFoundationAndFlareCore() throws {
        let root = KernelShapeTests.kernelSources
        let files = try KernelShapeTests.swiftFiles(under: root).filter { $0.hasPrefix("Shapes/") }
        #expect(files.count >= 3)
        let other = try Regex(#"^\s*(@testable\s+)?import\s+(?!(Foundation|FoundationEssentials|FlareCore)\b)"#)
        for file in files {
            let text = try String(contentsOf: root.appendingPathComponent(file), encoding: .utf8)
            for line in text.split(separator: "\n") where line.contains(other) { Issue.record("\(file): \(line)") }
        }
    }

    /// The points the spec's path in `box` visits: each move's and line's end.
    static func vertices(_ spec: ShapeSpec, in box: Rect = Rect(minX: 0, minY: 0, maxX: 100, maxY: 100)) throws -> [Point] {
        try ShapeRules.path(spec, in: box).elements.compactMap { if case .move(let p) = $0 { p } else if case .line(let p) = $0 { p } else { nil } }
    }

    // SH-5's rows, in the packet's order.
    @Test(.disabled("waits on SH-5")) func starHasTenVerticesFromTheTop() throws {
        let points = try Self.vertices(.defaults(.star))
        #expect(points.count == 10 && abs((points.first?.x ?? 0) - 50) < 1e-9 && abs(points.first?.y ?? 1) < 1e-9)
    }
    @Test(.disabled("waits on SH-5")) func hexagonLiesOnTheEllipse() throws {
        let points = try Self.vertices(ShapeSpec(kind: .polygon, sides: 6), in: Rect(minX: 0, minY: 0, maxX: 100, maxY: 60))
        #expect(points.count == 6 && points.allSatisfy { abs(pow(($0.x - 50) / 50, 2) + pow(($0.y - 30) / 30, 2) - 1) < 1e-9 })
    }
    @Test(.disabled("waits on SH-5")) func lineEndsAtTheBoxCorner() throws {
        let points = try Self.vertices(.defaults(.line), in: Rect(minX: 0, minY: 0, maxX: 100, maxY: 50))
        #expect(points.first == Point(x: 0, y: 0) && points.last == Point(x: 100, y: 50))
    }
    @Test(.disabled("waits on SH-5")) func headAtEnd() throws {
        let spec = ShapeSpec(kind: .arrow, start: Point(x: 0, y: 0.5), end: Point(x: 1, y: 0.5))
        let points = try Self.vertices(spec, in: Rect(minX: 0, minY: 0, maxX: 100, maxY: 40))
        #expect(points.contains(Point(x: 100, y: 20)) && points.allSatisfy { $0.x <= 100 + 1e-9 })
    }
    @Test(.disabled("waits on SH-5")) func shiftSquaresToLarger() {
        let drag = ShapeRules.dragged(.rectangle, from: Point(x: 10, y: 10), to: Point(x: 50, y: 40), modifiers: .shift)
        #expect(drag?.box == Rect(minX: 10, minY: 10, maxX: 50, maxY: 50))
        #expect(ShapeRules.dragged(.rectangle, from: Point(x: 5, y: 5), to: Point(x: 5, y: 5), modifiers: []) == nil)
    }
    @Test(.disabled("waits on SH-5")) func shiftLineSnapsTo45() throws {
        let to = Point(x: 100 * cos(40 * Double.pi / 180), y: 100 * sin(40 * Double.pi / 180))
        let drag = try #require(ShapeRules.dragged(.line, from: Point(x: 0, y: 0), to: to, modifiers: .shift))
        let (box, s) = (drag.box, drag.spec)
        #expect(abs(atan2((s.end.y - s.start.y) * box.height, (s.end.x - s.start.x) * box.width) - Double.pi / 4) < 1e-9)
    }
    @Test(.disabled("waits on SH-5")) func polygonNeedsThree() {
        #expect(ShapeRules.help(ShapeSpec(kind: .polygon, sides: 2)) == "A polygon needs 3 to 64 sides.")
        #expect(ShapeRules.help(ShapeSpec(kind: .star, innerRatio: 0.05)) != nil)
        #expect(ShapeRules.help(.defaults(.polygon)) == nil && ShapeRules.help(.defaults(.star)) == nil)
    }
    @Test(.disabled("waits on SH-5")) func optionFromCentre() {
        let drag = ShapeRules.dragged(.ellipse, from: Point(x: 50, y: 50), to: Point(x: 70, y: 60), modifiers: .option)
        #expect(drag?.box == Rect(minX: 30, minY: 40, maxX: 70, maxY: 60))
    }
}
