// LayerStyleSVGTests.swift (layer-styles LS-1 written disabled, LS-7 turns it on and adds the
// substitution, region and gradient cases): one `<filter>` per styled shape from W3C Filter Effects primitives.
import Testing
import SuiteImaging
import SuiteKernel

@Suite(.disabled("waits on LS-7")) struct LayerStyleSVGTests {
    static let box = Rect(minX: 0, minY: 0, maxX: 100, maxY: 100)
    /// 135° and 8 px with y down: blur σ = size / 3 = 4, offset (5.66, 5.66), down and to the right.
    @Test func shadowGoesDown() {
        let (svg, warnings) = LayerStyleSVG.filter(shadowStyle(), id: "s1", box: Self.box)
        #expect(svg.hasPrefix("<filter id=\"s1\"") && warnings.isEmpty && svg.contains("stdDeviation=\"4\""))
        #expect(svg.contains("dx=\"5.66\"") && svg.contains("dy=\"5.66\"") && svg.contains("mode=\"multiply\""))
    }
}
