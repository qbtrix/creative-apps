// PlaceVectorTests.swift (placed-images PL-1 written, PL-6 turns on): an SVG flattened into paint. Two groups
// stay two items in their colours and paint order, a ring keeps its hole, a gradient keeps its stops, the size
// comes from the viewBox, a filter is reported skipped, and damaged bytes throw.
import Foundation
import Testing
import SuiteKernel

@Suite struct PlaceVectorTests {
    static func svg(_ body: String) -> Data {
        Data((#"<svg xmlns="http://www.w3.org/2000/svg" width="240" height="80" viewBox="0 0 240 80">"# + body + "</svg>").utf8)
    }
    static let red = FillColor(r: 1, g: 0, b: 0), blue = FillColor(r: 0, g: 0, b: 1)
    static let twoGroups = svg(##"<g><rect width="100" height="80" fill="#ff0000"/></g><g><rect x="140" width="100" height="80" fill="#0000ff"/></g>"##)

    @Test(.disabled("waits on PL-6")) func keepsColoursAndSize() throws {
        let vector = try PlaceRules.vector(Self.twoGroups, name: "two-groups.svg")
        #expect(vector.items.map { $0.fill } == [Fill.solid(Self.red), Fill.solid(Self.blue)])
        #expect(vector.size == Size(width: 240, height: 80))
    }
    @Test(.disabled("waits on PL-6")) func ringKeepsHoleAndGradientItsStops() throws {
        let ring = try PlaceRules.vector(Self.svg(##"<path fill-rule="evenodd" d="M0 0H80V80H0Z M20 20V60H60V20Z"/>"##), name: "ring.svg")
        #expect(ring.items.count == 1 && ring.items.first?.contours.count == 2)
        let stops = ##"<linearGradient id="g"><stop offset="0" stop-color="#ff0000"/><stop offset="1" stop-color="#0000ff"/></linearGradient>"##
        let fill = try PlaceRules.vector(Self.svg(stops + ##"<rect width="240" height="80" fill="url(#g)"/>"##), name: "g.svg").items.first?.fill
        guard case .linear(let kept, _, _)? = fill else { Issue.record("not linear: \(String(describing: fill))"); return }
        #expect(kept.map { $0.color } == [Self.red, Self.blue])
    }
    @Test(.disabled("waits on PL-6")) func reportsSkippedAndThrowsOnDamage() throws {
        let filtered = Self.svg(#"<filter id="f"/><rect width="10" height="10" filter="url(#f)"/>"#)
        #expect(try !PlaceRules.vector(filtered, name: "filter.svg").skipped.isEmpty)
        #expect(throws: (any Error).self) { try PlaceRules.vector(Data("<svg><g".utf8), name: "damaged.svg") }
    }
}
