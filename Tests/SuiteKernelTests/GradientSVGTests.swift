// GradientSVGTests.swift (gradient-fill GF-1 written, GF-7 turns on): the SVG writer keeps the line's points in
// user space, writes `stop-opacity` only below 1, and gives a radial its centre and radius.
// Disabled by name until GF-7 builds `GradientSVG.definition`.
import Testing
import SuiteKernel

@Suite struct GradientSVGTests {
    static func stops(alpha: Double = 1) -> [GradientStop] {
        [GradientStop(offset: 0, color: FillColor(r: 0, g: 0, b: 1, a: alpha)), GradientStop(offset: 1, color: .white)]
    }

    @Test(.disabled("waits on GF-7")) func linearPoints() {
        let fill = Fill.linear(stops: Self.stops(), start: Point(x: 0, y: 0), end: Point(x: 100, y: 100))
        let svg = GradientSVG.definition(fill, id: "g1")
        #expect(svg.contains(#"x1="0" y1="0" x2="100" y2="100""#) && svg.contains(#"id="g1""#))
        #expect(svg.contains(#"gradientUnits="userSpaceOnUse""#))
    }
    @Test(.disabled("waits on GF-7")) func opaqueStopHasNoOpacity() {
        let line = (start: Point(x: 0, y: 0), end: Point(x: 1, y: 0))
        #expect(!GradientSVG.definition(.linear(stops: Self.stops(), start: line.start, end: line.end), id: "g").contains("stop-opacity"))
        #expect(GradientSVG.definition(.linear(stops: Self.stops(alpha: 0.5), start: line.start, end: line.end), id: "g")
            .contains(#"stop-opacity="0.5""#))
    }
    @Test(.disabled("waits on GF-7")) func radialCentreAndRadius() {
        let svg = GradientSVG.definition(.radial(stops: Self.stops(), center: Point(x: 50, y: 40), radius: 70), id: "r")
        #expect(svg.contains("<radialGradient") && svg.contains(#"cx="50""#) && svg.contains(#"cy="40""#) && svg.contains(#"r="70""#))
    }
}
