// StrokeRulesTests.swift (stroke-style SS-1 written, SS-5 turns on): the width limits and the dash presets, scaled by
// the stroke's width with a 1 pt floor, and a plain stroke's painted path is the path itself.
// Disabled by name until SS-5 builds `StrokeRules`' width and preset bodies.
import Testing
import SuiteKernel

@Suite struct StrokeRulesTests {
    @Test(.disabled("waits on SS-5")) func widthsClamp() {
        #expect(StrokeRules.clampedWidth(-1) == 0)
        #expect(StrokeRules.clampedWidth(2000) == 1000)
        #expect(StrokeRules.clampedWidth(6) == 6)
    }
    @Test(.disabled("waits on SS-5")) func dashScalesWithWidth() {
        #expect(StrokeRules.pattern(.dashed, width: 4) == [16, 8])
        #expect(StrokeRules.pattern(.dashed, width: 1) == [4, 2])
    }
    @Test(.disabled("waits on SS-5")) func dottedAndSolid() {
        #expect(StrokeRules.pattern(.dotted, width: 4) == [0, 8])
        #expect(StrokeRules.pattern(.solid, width: 4).isEmpty)
    }
    @Test(.disabled("waits on SS-5")) func hairlineDashVisible() {
        #expect(StrokeRules.pattern(.dashed, width: 0.5) == [4, 2])
        #expect(StrokeRules.pattern(.dotted, width: 0) == [0, 2])
    }
    @Test(.disabled("waits on SS-5")) func solidPaintsThePath() throws {
        let path = try ShapeRules.path(ShapeSpec(kind: .rectangle), in: Rect(minX: 0, minY: 0, maxX: 100, maxY: 100))
        #expect(try StrokeRules.paintedPath(path, VectorStroke(width: 4)) == path)
        #expect(StrokeRules.preset(of: VectorStroke(width: 4)) == .solid)
        #expect(StrokeRules.trim(of: VectorStroke()) == nil)
    }
}
