// HaloStrokeTests.swift: stroke-style MJ-HK, the Model walk. A layer's stroke
// saves under its own key and old projects open without one (HK-1); a stroke
// on a shape layer as one step, refusals on text and nulls, one step per
// gesture, trim keyed at the playhead and the nine specs listed (HK-6's
// conformance bodies). Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FlareCore
@testable import HaloModel
import SuiteKernel
import Testing

@Suite struct HaloStrokeTests {
    /// 8 pt, round join and cap, drawing the first half of the outline.
    static let drawn = VectorStroke(width: 8, join: .round, cap: .round, trim: StrokeTrim(start: 0, end: 0.5))

    /// `three-layers` (Title text, Badge shape, Background solid, Rig null)
    /// with `name` selected.
    static func selecting(_ name: String) throws -> HaloProject {
        var project = HaloProject(services: .fake)
        project.restore(try #require(HaloFixtures.project("three-layers")))
        let layers = try #require(project.selectedComposition?.layers)
        project.selectLayer(try #require(layers.first { $0.name == name }).id)
        return project
    }

    @Test func oldProjectsOpenWithoutAStroke() throws {
        let state = try #require(HaloFixtures.project("three-layers"))
        let data = try JSONEncoder().encode(state)
        #expect(String(decoding: data, as: UTF8.self).contains("\"stroke\"") == false)
        let decoded = try JSONDecoder().decode(HaloDocumentState.self, from: data)
        #expect(decoded == state)
        #expect(decoded.compositions.flatMap(\.layers).allSatisfy { $0.stroke == nil })
    }

    @Test func aStrokeSavesUnderItsKeyAndComesBack() throws {
        var layer = HaloLayer(
            id: "b", name: "Badge", kind: .shape, inFrame: 0, outFrame: 10, color: HaloLayerKind.shape.defaultColor)
        layer.stroke = Self.drawn
        let data = try JSONEncoder().encode(layer)
        #expect(String(decoding: data, as: UTF8.self).contains("\"stroke\""))
        let decoded = try JSONDecoder().decode(HaloLayer.self, from: data)
        #expect(decoded.stroke == Self.drawn)
        #expect(decoded.withID("c").stroke == Self.drawn)
    }

    @Test func runStrokeAddsAStrokeThroughTheCatalog() throws {
        var project = try Self.selecting("Badge")
        #expect(project.trimHelp == nil)
        #expect(project.selectedStroke == nil)
        project.runStroke(.add)
        #expect(project.selectedStroke == VectorStroke())
        #expect(project.history.undo.count == 1)
    }

    @Test func onlyShapeLayersTakeAStroke() throws {
        for name in ["Title", "Rig", "Background"] {
            #expect(try Self.selecting(name).strokeHelp == "Strokes are for shape layers.", "\(name) offers a stroke")
        }
    }

    @Test func aShapeLayerTakesAStrokeAsOneStep() throws {
        var project = try Self.selecting("Badge")
        #expect(project.strokeHelp == nil)
        try project.setStroke(VectorStroke(), name: "Add Stroke", drag: nil)
        #expect(project.selectedLayer?.stroke == VectorStroke())
        #expect(project.selectedStroke == VectorStroke())
        #expect(project.history.undo.count == 1)
        #expect(project.history.undoTitle == "Undo Add Stroke")
        try project.setStroke(nil, name: "Remove Stroke", drag: nil)
        #expect(project.selectedLayer?.stroke == nil)
    }

    @Test func textAndNullsRefuse() throws {
        for name in ["Title", "Rig", "Background"] {
            var project = try Self.selecting(name)
            #expect(project.strokeHelp == "Strokes are for shape layers.")
            let before = project.document
            #expect(throws: (any Error).self) { try project.setStroke(Self.drawn, name: "Add Stroke", drag: nil) }
            #expect(project.document == before)
            #expect(project.history.undo.isEmpty)
        }
    }

    @Test func oneStepPerGesture() throws {
        var project = try Self.selecting("Badge")
        try project.setStroke(VectorStroke(), name: "Add Stroke", drag: nil)
        for i in 1...120 {
            try project.setStroke(VectorStroke(width: Double(i) / 10), name: "Stroke Width", drag: "width-scrub")
        }
        #expect(project.history.undo.count == 2)
        #expect(project.selectedStroke?.width == 12)
        let steps = project.history.undo.count
        _ = try HaloProject.catalog.run("stroke.join", params: .object(["join": .string("round")]), on: &project)
        #expect(project.selectedStroke?.join == .round)
        #expect(project.history.undo.count == steps + 1)
    }

    @Test func trimOnAnAnimatedTrimEndKeysAtThePlayhead() throws {
        var project = try Self.selecting("Badge")
        try project.setStroke(VectorStroke(trim: StrokeTrim(start: 0, end: 0)), name: "Add Stroke", drag: nil)
        project.toggleKey(.trimEnd)
        project.scrub(to: 12)
        try project.setStroke(VectorStroke(trim: StrokeTrim(start: 0, end: 0.5)), name: "Trim Path", drag: nil)
        let keys = try #require(project.selectedLayer?.tracks["trimEnd"])
        #expect(keys.map(\.frame) == [0, 12])
        #expect(project.selectedStroke?.trim?.end == 0.5)
        project.scrub(to: 0)
        #expect(project.selectedStroke?.trim?.end == 0)
        try project.setStroke(nil, name: "Remove Stroke", drag: nil)
        #expect(project.selectedLayer?.tracks["trimEnd"] == nil && project.selectedStroke == nil)
    }

    @Test func theNineSpecsAreListed() throws {
        let ids = StrokeCommands.specs(HaloProject.self).map(\.id)
        #expect(ids.count == 9)
        #expect(Set(ids).isSubset(of: Set(HaloProject.catalog.ids)))
    }
}
