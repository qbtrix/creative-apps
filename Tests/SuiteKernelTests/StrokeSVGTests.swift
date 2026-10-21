// StrokeSVGTests.swift (stroke-style SS-1 written, SS-5 turns on): the SVG writer's stroke attributes, as FlareCore's
// SVG export writes them: colour as hex, opacity only below 1, width, join and cap.
// On since SS-5; the dash test since SS-7 (StrokeDashTrimTests has the dashed ones).
import Testing
import SuiteKernel

@Suite struct StrokeSVGTests {
    /// `stroke`'s attributes as a name-to-value table.
    static func table(_ stroke: VectorStroke) -> [String: String] {
        Dictionary(StrokeSVG.attributes(stroke).map { ($0.name, $0.value) }) { first, _ in first }
    }

    @Test func colorAndWidth() {
        let attributes = Self.table(VectorStroke(color: FillColor(r: 1, g: 0, b: 0), width: 2))
        #expect(attributes["stroke"] == "#ff0000" && attributes["stroke-width"] == "2")
        #expect(attributes["stroke-opacity"] == nil)
    }
    @Test func translucentColorHasOpacity() {
        #expect(Self.table(VectorStroke(color: FillColor(r: 0, g: 0, b: 0, a: 0.5)))["stroke-opacity"] == "0.5")
    }
    @Test func capAttribute() {
        let attributes = Self.table(VectorStroke(join: .round, cap: .square))
        #expect(attributes["stroke-linejoin"] == "round" && attributes["stroke-linecap"] == "square")
    }
    @Test func plainStrokeHasNoDash() {
        #expect(Self.table(VectorStroke())["stroke-dasharray"] == nil)
    }
}
