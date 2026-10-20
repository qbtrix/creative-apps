// ShapeRulesTests.swift: the shape tools' spec and rules (shape-tools SH-1, SH-5).
// SH-1's checks run now: a spec round-trips through JSON with every field, and
// Shapes/ imports only Foundation and FlareCore. The SH-5 acceptance rows are
// written here and wait, disabled by name, until SH-5 fills ShapeRules.
import Foundation
import Testing
import SuiteKernel

@Suite struct ShapeRulesTests {
    /// The module's folder: Tests/SuiteKernelTests/ -> Sources/SuiteKernel/Shapes/.
    static let shapeSources = KernelShapeTests.kernelSources.appendingPathComponent("Shapes")

    @Test func specRoundTripsThroughJSON() throws {
        var spec = ShapeSpec.defaults(.arrow)
        spec.sides = 7; spec.points = 9; spec.innerRatio = 0.25; spec.cornerRadius = 4; spec.head = 20
        spec.start = Point(x: 0.1, y: 0.2); spec.end = Point(x: 0.9, y: 0.8)
        let back = try JSONDecoder().decode(ShapeSpec.self, from: JSONEncoder().encode(spec))
        #expect(back == spec)
        let star = ShapeSpec.defaults(.star)
        #expect(star.kind == .star && star.sides == 5 && star.points == 5 && star.innerRatio == 0.5)
        #expect(star.cornerRadius == 0 && star.head == 12)
        #expect(ShapeKind.allCases.map(\.rawValue) == ["rectangle", "ellipse", "polygon", "star", "line", "arrow"])
        #expect(ShapeRules.counts == 3...64 && ShapeRules.ratios == 0.1...1.0)
    }

    @Test func shapesImportOnlyFoundationAndFlareCore() throws {
        let files = try FileManager.default.contentsOfDirectory(atPath: Self.shapeSources.path).filter { $0.hasSuffix(".swift") }
        #expect(Set(files).isSuperset(of: ["ShapeSpec.swift", "ShapeRules.swift", "ShapeCommands.swift"]))
        let anyImport = try Regex(#"^\s*(@testable\s+)?import\s+(\w+)"#)
        let allowed: Set<String> = ["Foundation", "FoundationEssentials", "FlareCore"]
        for file in files {
            let text = try String(contentsOf: Self.shapeSources.appendingPathComponent(file), encoding: .utf8)
            for line in text.split(separator: "\n") {
                guard let match = line.firstMatch(of: anyImport), let module = match.output[2].substring else { continue }
                if !allowed.contains(String(module)) { Issue.record("Shapes/\(file) imports \(module)") }
            }
        }
    }

    /// The points a path visits: each move's and line's end.
    static func vertices(_ path: Path) -> [Point] {
        path.elements.compactMap { element in
            switch element {
            case .move(let to), .line(let to): to
            default: nil
            }
        }
    }

    @Test(.disabled("waits on SH-5")) func starHasTenVerticesFromTheTop() throws {
        let path = try ShapeRules.path(.defaults(.star), in: Rect(minX: 0, minY: 0, maxX: 100, maxY: 100))
        let points = Self.vertices(path)
        #expect(points.count == 10)
        #expect(abs((points.first?.x ?? -1) - 50) < 1e-9 && abs(points.first?.y ?? -1) < 1e-9)
    }

    @Test(.disabled("waits on SH-5")) func hexagonLiesOnTheEllipse() throws {
        var spec = ShapeSpec.defaults(.polygon); spec.sides = 6
        let path = try ShapeRules.path(spec, in: Rect(minX: 0, minY: 0, maxX: 100, maxY: 60))
        let points = Self.vertices(path)
        #expect(points.count == 6)
        for p in points {
            let u = (p.x - 50) / 50, v = (p.y - 30) / 30
            #expect(abs(u * u + v * v - 1) < 1e-9)
        }
    }

    @Test(.disabled("waits on SH-5")) func lineEndsAtTheBoxCorner() throws {
        var spec = ShapeSpec.defaults(.line)
        spec.start = Point(x: 0, y: 0); spec.end = Point(x: 1, y: 1)
        let points = Self.vertices(try ShapeRules.path(spec, in: Rect(minX: 0, minY: 0, maxX: 100, maxY: 50)))
        #expect(points.first == Point(x: 0, y: 0) && points.last == Point(x: 100, y: 50))
    }

    @Test(.disabled("waits on SH-5")) func headAtEnd() throws {
        var spec = ShapeSpec.defaults(.arrow)
        spec.start = Point(x: 0, y: 0.5); spec.end = Point(x: 1, y: 0.5)
        let points = Self.vertices(try ShapeRules.path(spec, in: Rect(minX: 0, minY: 0, maxX: 100, maxY: 40)))
        // The head's tip is the line's end, and nothing reaches past it.
        #expect(points.contains(Point(x: 100, y: 20)))
        #expect(points.allSatisfy { $0.x <= 100 + 1e-9 })
    }

    @Test(.disabled("waits on SH-5")) func shiftSquaresToLarger() throws {
        let drag = ShapeRules.dragged(.rectangle, from: Point(x: 10, y: 10), to: Point(x: 50, y: 40), modifiers: .shift)
        #expect(drag?.box == Rect(minX: 10, minY: 10, maxX: 50, maxY: 50))
        #expect(ShapeRules.dragged(.rectangle, from: Point(x: 5, y: 5), to: Point(x: 5, y: 5), modifiers: []) == nil)
    }

    @Test(.disabled("waits on SH-5")) func shiftLineSnapsTo45() throws {
        let angle = 40.0 * Double.pi / 180
        let to = Point(x: 100 * cos(angle), y: 100 * sin(angle))
        let drag = try #require(ShapeRules.dragged(.line, from: Point(x: 0, y: 0), to: to, modifiers: .shift))
        let a = Point(x: drag.box.minX + drag.spec.start.x * drag.box.width, y: drag.box.minY + drag.spec.start.y * drag.box.height)
        let b = Point(x: drag.box.minX + drag.spec.end.x * drag.box.width, y: drag.box.minY + drag.spec.end.y * drag.box.height)
        #expect(abs(atan2(b.y - a.y, b.x - a.x) - Double.pi / 4) < 1e-9)
    }

    @Test(.disabled("waits on SH-5")) func polygonNeedsThree() {
        var polygon = ShapeSpec.defaults(.polygon); polygon.sides = 2
        #expect(ShapeRules.help(polygon) == "A polygon needs 3 to 64 sides.")
        var star = ShapeSpec.defaults(.star); star.innerRatio = 0.05
        #expect(ShapeRules.help(star) != nil)
        #expect(ShapeRules.help(.defaults(.polygon)) == nil && ShapeRules.help(.defaults(.star)) == nil)
    }

    @Test(.disabled("waits on SH-5")) func optionFromCentre() {
        let drag = ShapeRules.dragged(.ellipse, from: Point(x: 50, y: 50), to: Point(x: 70, y: 60), modifiers: .option)
        #expect(drag?.box == Rect(minX: 30, minY: 40, maxX: 70, maxY: 60))
    }
}
