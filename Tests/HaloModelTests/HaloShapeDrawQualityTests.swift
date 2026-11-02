// HaloShapeDrawQualityTests.swift: the shape-tools quality gate (#5842). A
// drawn layer is named by its kind ("Star") while its undo step reads "Draw
// Star"; a line or arrow gets a stroke so it shows; an arrow's head fills;
// shape.draw's line ends are fractions of the box, so pixels are refused.
// Linux and macOS.
import Foundation
import CoreRaster
import FlareCore
@testable import HaloModel
import SuiteKernel
import Testing

@Suite struct HaloShapeDrawQualityTests {
    static func draw(_ params: [String: JSONValue], on project: inout HaloProject) throws -> CommandOutcome {
        try HaloProject.catalog.run("shape.draw", params: .object(params), on: &project)
    }

    /// The new layer alone in a 600 × 600 composition, rendered at frame 0.
    static func render(_ layer: HaloLayer) throws -> PixelBuffer {
        var layer = layer
        layer.inFrame = 0
        let comp = HaloComposition(
            id: "comp-1", name: "Comp", width: 600, height: 600, framesPerSecond: 24, durationFrames: 24, layers: [layer])
        return try #require(
            comp.renderFrame(at: 0, scale: 1, drawing: LiveFrameDrawing(), rendering: LiveFrameRendering(), text: nil)
        ).pixels
    }

    @Test func theLayerIsNamedByItsKindAndTheStepByTheDraw() throws {
        var project = try HaloShapeTests.project()
        let outcome = try Self.draw(
            ["kind": .string("star"), "x": .number(10), "y": .number(10), "w": .number(100), "h": .number(100)], on: &project)
        #expect(project.selectedLayer?.name == "Star")
        #expect(outcome.undoStep == "Draw Star")

        let drawn = try #require(HaloShapeDrawn(.defaults(.arrow), from: HaloPoint(x: 0, y: 0), to: HaloPoint(x: 50, y: 50)))
        _ = project.drawShape(drawn)
        #expect(project.selectedLayer?.name == "Arrow")
        #expect(project.history.undo.last?.name == "Draw Arrow")
    }

    @Test func linesAndArrowsGetAStrokeAndShow() throws {
        for kind in ["line", "arrow"] {
            var project = try HaloShapeTests.project()
            _ = try Self.draw(
                ["kind": .string(kind), "x": .number(100), "y": .number(100), "w": .number(400), "h": .number(400)],
                on: &project)
            let layer = try #require(project.selectedLayer)
            let stroke = try #require(layer.stroke, "a \(kind) has no stroke")
            #expect(stroke.width > 0)
            #expect(try Self.render(layer).pixel(x: 250, y: 250).a > 0.9, "the \(kind)'s middle is empty")
        }
        var project = try HaloShapeTests.project()
        _ = try Self.draw(["kind": .string("star"), "x": .number(0), "y": .number(0), "w": .number(9), "h": .number(9)], on: &project)
        #expect(project.selectedLayer?.stroke == nil, "a closed shape keeps its fill only")
    }

    @Test func anArrowsHeadIsFilled() throws {
        var project = try HaloShapeTests.project()
        _ = try Self.draw(
            ["kind": .string("arrow"), "head": .number(120),
             "x": .number(100), "y": .number(100), "w": .number(400), "h": .number(400)], on: &project)
        let layer = try #require(project.selectedLayer)
        // 72 px back from the tip (500, 500) along the shaft: inside the head, clear of its outline's stroke.
        let back = 500 - 72 / 2.0.squareRoot()
        #expect(try Self.render(layer).pixel(x: Int(back), y: Int(back)).a > 0.9, "the head is hollow")
    }

    @Test func lineEndsArePartsOfTheBoxNotPixels() throws {
        var project = try HaloShapeTests.project()
        let before = project.document
        #expect(throws: CatalogError.self) {
            try Self.draw(
                ["kind": .string("line"), "x": .number(0), "y": .number(0), "w": .number(100), "h": .number(100),
                 "x1": .number(760), "y1": .number(0), "x2": .number(1), "y2": .number(1)], on: &project)
        }
        #expect(project.document == before)
        let schema = try #require(HaloProject.catalog.spec("shape.draw")).params.json
        #expect("\(schema)".contains("fraction of the box"))
    }
}
