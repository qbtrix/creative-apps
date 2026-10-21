// PlaceVectorTests.swift (placed-images PL-1 written, PL-6 turns on): an SVG flattened into paint. Two groups
// stay two items in their colours and paint order, a ring keeps its hole, a gradient keeps its stops, the size
// comes from the viewBox, a filter is reported skipped, and damaged bytes throw. The SVGs are in Fixtures/place/.
import Foundation
import Testing
import SuiteKernel

@Suite struct PlaceVectorTests {
    static let fixtures = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .appendingPathComponent("Fixtures").appendingPathComponent("place")
    static func fixture(_ name: String) throws -> PlacedVector {
        try PlaceRules.vector(try Data(contentsOf: fixtures.appendingPathComponent(name)), name: name)
    }
    static let red = FillColor(r: 1, g: 0, b: 0), blue = FillColor(r: 0, g: 0, b: 1)

    @Test func keepsColours() throws {
        let vector = try Self.fixture("two-groups.svg")
        #expect(vector.items.map { $0.fill } == [Fill.solid(Self.red), Fill.solid(Self.blue)])
        #expect(vector.items.first?.contours.first?.contains(Point(x: 100, y: 80)) == true)
        // The viewBox (240 × 80), not width and height (480 × 160).
        #expect(vector.size == Size(width: 240, height: 80))
        #expect(vector.skipped.isEmpty)
    }
    @Test func ringKeepsHole() throws {
        let ring = try Self.fixture("ring.svg")
        #expect(ring.items.count == 1)
        let contours = ring.items.first?.contours ?? []
        #expect(contours.count == 2)
        let inner = contours.dropFirst().first ?? []
        #expect(!inner.isEmpty && inner.allSatisfy { (20...60).contains($0.x) && (20...60).contains($0.y) })
    }
    @Test func gradientKeepsStops() throws {
        let fill = try Self.fixture("gradient.svg").items.first?.fill
        guard case .linear(let kept, let start, let end)? = fill else { Issue.record("not linear: \(String(describing: fill))"); return }
        #expect(kept.map { $0.color } == [Self.red, Self.blue])
        #expect(kept.map { $0.offset } == [0, 1])
        #expect(start == Point(x: 0, y: 0) && end == Point(x: 240, y: 0))
    }
    @Test func reportsSkipped() throws {
        let filtered = Data(#"<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10"><filter id="f"/><rect width="10" height="10" filter="url(#f)"/></svg>"#.utf8)
        let skipped = try PlaceRules.vector(filtered, name: "filter.svg").skipped
        #expect(skipped.contains { $0.hasPrefix("filter") })
    }
    @Test func throwsOnDamage() {
        #expect(throws: (any Error).self) { try PlaceRules.vector(Data("<svg><g".utf8), name: "damaged.svg") }
        #expect(throws: (any Error).self) { try PlaceRules.vector(Data("not an svg".utf8), name: "text.svg") }
    }
}
