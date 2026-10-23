// GradientSVGTests.swift (gradient-fill GF-7): the SVG writer keeps the line's points in user space, writes
// `stop-opacity` only below 1, gives a radial its centre and radius, writes each stop's offset and colour, and writes
// nothing for a solid. Mutations: Tests/mutations/SuiteKernel.GradientSVG.json.
import Testing
import SuiteKernel

@Suite struct GradientSVGTests {
    static func stops(alpha: Double = 1) -> [GradientStop] {
        [GradientStop(offset: 0, color: FillColor(r: 0, g: 0, b: 1, a: alpha)), GradientStop(offset: 1, color: .white)]
    }

    @Test func linearPoints() {
        let fill = Fill.linear(stops: Self.stops(), start: Point(x: 0, y: 0), end: Point(x: 100, y: 100))
        let svg = GradientSVG.definition(fill, id: "g1")
        #expect(svg.contains(#"x1="0" y1="0" x2="100" y2="100""#) && svg.contains(#"id="g1""#))
        #expect(svg.contains(#"gradientUnits="userSpaceOnUse""#))
    }
    @Test func opaqueStopHasNoOpacity() {
        let line = (start: Point(x: 0, y: 0), end: Point(x: 1, y: 0))
        #expect(!GradientSVG.definition(.linear(stops: Self.stops(), start: line.start, end: line.end), id: "g").contains("stop-opacity"))
        #expect(GradientSVG.definition(.linear(stops: Self.stops(alpha: 0.5), start: line.start, end: line.end), id: "g")
            .contains(#"stop-opacity="0.5""#))
    }
    @Test func radialCentreAndRadius() {
        let svg = GradientSVG.definition(.radial(stops: Self.stops(), center: Point(x: 50, y: 40), radius: 70), id: "r")
        #expect(svg.contains("<radialGradient") && svg.contains(#"cx="50""#) && svg.contains(#"cy="40""#) && svg.contains(#"r="70""#))
    }
    @Test func stopsAndSolid() {
        let fill = Fill.linear(stops: [GradientStop(offset: 0, color: FillColor(r: 1, g: 0, b: 0)), GradientStop(offset: 0.25, color: .white)],
                               start: Point(x: 0, y: 0), end: Point(x: 10, y: 0))
        let svg = GradientSVG.definition(fill, id: "s")
        #expect(svg.contains(##"<stop offset="0" stop-color="#ff0000"/><stop offset="0.25" stop-color="#ffffff"/>"##))
        #expect(svg.hasPrefix("<linearGradient") && svg.hasSuffix("</linearGradient>"))
        #expect(GradientSVG.definition(.solid(.white), id: "s").isEmpty)
    }
    @Test func rotatedFillWritesTheRulesPoints() {
        let square = Rect(minX: 0, minY: 0, maxX: 100, maxY: 100)
        let flat = Fill.linear(stops: Self.stops(), start: Point(x: 0, y: 50), end: Point(x: 100, y: 50))
        #expect(GradientSVG.definition(GradientRules.rotated(flat, to: 45, in: square), id: "g").contains(#"x1="0" y1="0" x2="100" y2="100""#))
    }
}
