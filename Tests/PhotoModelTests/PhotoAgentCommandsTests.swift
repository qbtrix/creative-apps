// PhotoAgentCommandsTests.swift: the commands an agent drives Photo with (#6028). `document.read` lists the canvas,
// the layers top-first and the selection; `view.snapshot` is a downscaled PNG of the canvas or a region and records
// nothing; `paint.stroke` paints through its points with Photo's brush on the selected image layer as one
// "Brush Stroke" step, then leaves the tool and the brush as they were. Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster
@testable import PhotoModel
import SuiteKernel
import Testing

@Suite struct PhotoAgentCommandsTests {
    static func opened() throws -> PhotoWorkspace {
        var w = PhotoWorkspace(services: .fake)
        try w.newCanvas(width: 80, height: 60)
        return w
    }
    static func run(_ id: String, _ params: JSONValue, on w: inout PhotoWorkspace) throws -> CommandOutcome {
        try PhotoWorkspace.catalog.run(id, params: params, on: &w)
    }
    static func stroke(_ points: [(Double, Double)], size: Double = 6, opacity: Double = 1) -> JSONValue {
        .object(["points": .array(points.map { .object(["x": .number($0.0), "y": .number($0.1)]) }),
                 "size": .number(size), "hardness": .number(1), "opacity": .number(opacity),
                 "color": .object(["r": .number(1), "g": .number(0), "b": .number(0), "a": .number(1)])])
    }

    @Test func readListsTheCanvasLayersTopFirstAndTheSelection() throws {
        var w = try Self.opened()
        w.addLayer()
        let outline = try Self.run("document.read", .object([:]), on: &w).result.decode(DocumentOutline.self)
        #expect(outline.width == 80 && outline.height == 60)
        #expect(outline.layers.map(\.name) == w.layers.map(\.name) && outline.layers.count == 2)
        #expect(outline.layers.last?.box == Rect(minX: 0, minY: 0, maxX: 80, maxY: 60) && outline.layers.last?.kind == "pixels")
        #expect(outline.layers.allSatisfy { !$0.hidden && $0.opacity == 1 })
        #expect(outline.selected == w.selectedLayerIDs)
        #expect(PhotoWorkspace.catalog.availability("document.read", on: PhotoWorkspace(services: .fake)) == .unavailable("Open a document first."))
    }

    @Test func snapshotIsADownscaledPNGAndRecordsNothing() throws {
        var w = try Self.opened()
        let steps = w.history.kernel.steps
        let shot = try Self.run("view.snapshot", .object(["maxSide": .number(40)]), on: &w)
        #expect(shot.undoStep == nil && w.history.kernel.steps == steps)
        guard case .object(let body) = shot.result, case .string(let text)? = body["png"], let png = Data(base64Encoded: text) else {
            Issue.record("no png in \(shot.result)"); return
        }
        #expect(png.starts(with: [0x89, 0x50, 0x4E, 0x47]))
        #expect(body["width"] == .number(40) && body["height"] == .number(30))
        let region = JSONValue.object(["maxSide": .number(64), "region": .object(["minX": .number(10), "minY": .number(10), "maxX": .number(30), "maxY": .number(20)])])
        let part = try Self.run("view.snapshot", region, on: &w).result
        #expect(part == .object(["png": part.field("png"), "width": .number(20), "height": .number(10)]))
        let off = JSONValue.object(["maxSide": .number(64), "region": .object(["minX": .number(200), "minY": .number(200), "maxX": .number(300), "maxY": .number(300)])])
        #expect(throws: CatalogError.failed(id: "view.snapshot", message: "The region misses the canvas.")) { try Self.run("view.snapshot", off, on: &w) }
    }

    @Test func strokePaintsOneBrushStrokeStepAndRestoresTheBrush() throws {
        var w = try Self.opened()
        w.selectTool(.select)
        let before = (w.tool, w.brushOptions), white = try w.composite().pixel(x: 40, y: 30)
        let done = try Self.run("paint.stroke", Self.stroke([(10, 30), (70, 30)]), on: &w)
        #expect(done.undoStep == "Brush Stroke" && w.history.kernel.steps == ["Brush Stroke"])
        let painted = try w.composite().pixel(x: 40, y: 30)
        #expect(painted.r > 0.9 && painted.g < 0.1 && painted.b < 0.1, "\(painted)")
        #expect(try w.composite().pixel(x: 40, y: 5) == white)
        #expect(w.tool == before.0 && w.brushOptions == before.1)
        _ = try Self.run("edit.undo", .object([:]), on: &w)
        #expect(try w.composite().pixel(x: 40, y: 30) == white)
    }

    @Test func aOnePointStrokePaintsADab() throws {
        var w = try Self.opened()
        _ = try Self.run("paint.stroke", Self.stroke([(20, 20)], size: 8), on: &w)
        #expect(try w.composite().pixel(x: 20, y: 20).g < 0.1 && w.history.kernel.steps == ["Brush Stroke"])
    }

    @Test func strokeRefusesWithoutAnImageLayer() throws {
        var w = try Self.opened()
        w.addAdjustmentLayer(.curves)
        #expect(PhotoWorkspace.catalog.availability("paint.stroke", on: w) == .unavailable("Select an image layer to paint on."))
        #expect(throws: CatalogError.self) { try Self.run("paint.stroke", Self.stroke([(10, 10), (20, 20)]), on: &w) }
        #expect(PhotoWorkspace.catalog.availability("paint.stroke", on: PhotoWorkspace(services: .fake)) == .unavailable("Open or make an image first."))
    }
}

private extension JSONValue {
    func field(_ key: String) -> JSONValue { if case .object(let o) = self { o[key] ?? .null } else { .null } }
}
