// StrokeDashTrimTests.swift (stroke-style SS-7): dash and trim on the bumped core. `stroke.dash` saves a preset's
// pattern scaled by the width (dotted also rounds the cap) and `stroke.trim` saves fractions, each one undo step, a
// trim scrub one step; the painted path is trimmed, then dashed; the SVG writes the dash; old strokes read solid.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import Testing
import SuiteKernel

@Suite struct StrokeDashTrimTests {
    static let catalog = StrokeCommandsTests.catalog
    /// A 100 pt square: one closed contour 400 pt long.
    static func square() throws -> VectorPath {
        try ShapeRules.path(ShapeSpec(kind: .rectangle), in: Rect(minX: 0, minY: 0, maxX: 100, maxY: 100))
    }
    static func trim(_ start: Double, _ end: Double) -> JSONValue {
        .object(["start": .number(start), "end": .number(end)])
    }

    @Test func notBuiltStaysForAppsNotYetOnTheCommands() {
        guard case .notBuilt(let id, _) = StrokeRules.notBuilt else { Issue.record("not a notBuilt refusal"); return }
        #expect(id == "stroke")
    }

    @Test func dashedSavesTheScaledPatternInOneStep() throws {
        let catalog = try #require(Self.catalog)
        var doc = StrokeDoc(stroke: VectorStroke(width: 4))
        let outcome = try catalog.run("stroke.dash", params: .object(["preset": .string("dashed")]), on: &doc)
        #expect(doc.stroke?.dash == [16, 8] && doc.stroke?.cap == .butt)
        #expect(outcome.undoStep == "Stroke Dash" && doc.history.steps == ["Stroke Dash"])
        #expect(doc.stroke.map(StrokeRules.preset(of:)) == .dashed)
    }
    @Test func dottedRoundsTheCapInTheSameStep() throws {
        let catalog = try #require(Self.catalog)
        var doc = StrokeDoc(stroke: VectorStroke(width: 4))
        _ = try catalog.run("stroke.dash", params: .object(["preset": .string("dotted")]), on: &doc)
        #expect(doc.stroke?.dash == [0, 8] && doc.stroke?.cap == .round)
        #expect(doc.history.steps == ["Stroke Dash"])
        #expect(doc.undo() && doc.stroke?.cap == .butt && doc.stroke?.dash == [])
    }
    @Test func customPatternAndPhase() throws {
        let catalog = try #require(Self.catalog)
        var doc = StrokeDoc(stroke: VectorStroke(width: 4))
        let params: JSONValue = .object(["pattern": .array([.number(10), .number(4)]), "phase": .number(3)])
        _ = try catalog.run("stroke.dash", params: params, on: &doc)
        let stroke = try #require(doc.stroke)
        #expect(StrokeRules.dash(of: stroke) == ([10, 4], 3) && StrokeRules.preset(of: stroke) == .custom)
        #expect(throws: CatalogError.self) {
            try catalog.run("stroke.dash", params: .object(["pattern": .array([.number(0), .number(0)])]), on: &doc)
        }
        _ = try catalog.run("stroke.dash", params: .object(["preset": .string("solid")]), on: &doc)
        #expect(doc.stroke.map { StrokeRules.dash(of: $0) == ([], 0) } == true)
        #expect(doc.history.steps.count == 2)
    }
    @Test func trimSavesFractionsAndHalvesThePaintedLength() throws {
        let catalog = try #require(Self.catalog)
        var doc = StrokeDoc(stroke: VectorStroke(width: 4))
        let outcome = try catalog.run("stroke.trim", params: Self.trim(0, 0.5), on: &doc)
        let stroke = try #require(doc.stroke)
        #expect(outcome.undoStep == "Trim Path")
        #expect(StrokeRules.trim(of: stroke).map { [$0.start, $0.end, $0.offset] } == [0, 0.5, 0])
        let painted = try StrokeRules.paintedPath(try Self.square(), stroke)
        #expect(abs(try painted.length(tolerance: 0.25) - 200) < 0.01)
    }
    @Test func trimScrubIsOneStep() throws {
        let catalog = try #require(Self.catalog)
        var doc = StrokeDoc(stroke: VectorStroke(width: 4))
        for sample in 0...60 {
            let params: JSONValue = .object(["start": .number(0), "end": .number(1 - Double(sample) / 120),
                                             "offset": .number(0.25), "drag": .string("t1")])
            _ = try catalog.run("stroke.trim", params: params, on: &doc)
        }
        #expect(doc.history.steps == ["Trim Path"])
        #expect(doc.stroke.flatMap(StrokeRules.trim(of:)).map { [$0.end, $0.offset] } == [0.5, 0.25])
        #expect(doc.undo() && doc.stroke?.trim == nil)
    }
    @Test func startEqualToEndPaintsNothing() throws {
        let catalog = try #require(Self.catalog)
        var doc = StrokeDoc(stroke: VectorStroke(width: 4))
        _ = try catalog.run("stroke.trim", params: Self.trim(0.3, 0.3), on: &doc)
        let painted = try StrokeRules.paintedPath(try Self.square(), try #require(doc.stroke))
        #expect(painted.elements.isEmpty)
    }
    @Test func trimThenDash() throws {
        let catalog = try #require(Self.catalog)
        var doc = StrokeDoc(stroke: VectorStroke(width: 4))
        _ = try catalog.run("stroke.trim", params: Self.trim(0, 0.45), on: &doc)
        _ = try catalog.run("stroke.dash", params: .object(["pattern": .array([.number(30), .number(70)])]), on: &doc)
        // 180 pt trimmed, then dashed 30 on 70: two dashes, 60 pt. Dashing first would keep 54 pt.
        let painted = try StrokeRules.paintedPath(try Self.square(), try #require(doc.stroke))
        #expect(abs(try painted.length(tolerance: 0.25) - 60) < 0.01)
        let whole = try StrokeRules.paintedPath(try Self.square(), VectorStroke(width: 4))
        #expect(whole == (try Self.square()))
    }
    @Test func svgWritesTheDash() {
        let attributes = StrokeSVGTests.table(VectorStroke(width: 4, dash: [16, 8], dashPhase: 2.5))
        #expect(attributes["stroke-dasharray"] == "16 8" && attributes["stroke-dashoffset"] == "2.5")
        #expect(StrokeSVG.attributes(VectorStroke(width: 4, dash: [16, 8])).last?.name == "stroke-dashoffset")
        #expect(StrokeSVGTests.table(VectorStroke(width: 4))["stroke-dashoffset"] == nil)
    }
    @Test func oldStrokesDecodeWithNoDash() throws {
        let json = #"{"color":{"r":0,"g":0,"b":0,"a":1},"width":2,"join":"miter","cap":"butt"}"#
        let stroke = try JSONDecoder().decode(VectorStroke.self, from: Data(json.utf8))
        #expect(StrokeRules.dash(of: stroke) == ([], 0) && StrokeRules.trim(of: stroke) == nil)
        #expect(StrokeRules.preset(of: stroke) == .solid)
    }
}
