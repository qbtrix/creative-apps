// FlarePlaceTests.swift: svg-place PF-1 (the conformance) and PF-5 (the bodies). Flare takes SVG only and its
// workspace is a `PlacedImageTarget`: an SVG's groups become layers, a wide drawing fits inside the scene, one
// place is one undo step, a ring keeps its hole, a PNG and a damaged SVG add nothing, and the report names what
// the import skipped.
import Foundation
import FlareCore
@testable import FlareModel
import SuiteKernel
import Testing

/// One empty 480×270 scene, opened on `.built`.
private func blank() -> FlareWorkspace {
    var w = FlareWorkspace(services: .built)
    w.load(Document(scenes: [FlareScene(id: "scene-1", name: "Scene 1", width: 480, height: 270)]))
    return w
}

/// The place commands on Flare's workspace, built here so the tests don't wait on PF-6's catalog line.
private let placeCatalog = try? CommandCatalog<FlareWorkspace>(
    app: "flare", PlaceCommands.specs(FlareWorkspace.self), history: FlareCoreHistory.init)

/// Runs `place.image` with `svg` as `name`, centred.
private func place(_ svg: String, as name: String = "logo.svg", on w: inout FlareWorkspace) throws {
    try place(Data(svg.utf8), as: name, on: &w)
}

private func place(_ data: Data, as name: String, on w: inout FlareWorkspace) throws {
    let catalog = try #require(placeCatalog)
    let intent = PlaceIntent.place(name: name, data: data, at: nil).command
    _ = try catalog.run(intent.id, params: intent.params, on: &w)
}

private func layers(_ w: FlareWorkspace) -> [FlareCore.Layer] { w.document?.layers(of: .scene("scene-1")) ?? [] }

/// The number of subpaths in `shape`'s outline.
private func contours(_ shape: FlareShape) -> Int {
    (shape.path?.elements ?? []).filter { if case .move = $0 { true } else { false } }.count
}

/// Two groups: a red square, and a blue ring whose inner square is a hole.
private let logo = """
<svg xmlns="http://www.w3.org/2000/svg" width="200" height="100" viewBox="0 0 200 100">
<g id="red"><rect x="10" y="10" width="80" height="80" fill="#E53935"/></g>
<g id="blue"><path fill="#1E88E5" fill-rule="evenodd" d="M110 10 H190 V90 H110 Z M130 30 V70 H170 V30 Z"/></g>
</svg>
"""

/// A 960×320 drawing, twice as wide as the scene.
private let wide = """
<svg xmlns="http://www.w3.org/2000/svg" width="960" height="320"><rect width="960" height="320" fill="#E53935"/></svg>
"""

/// A shape with a blur filter the import can't keep.
private let blurred = """
<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
<defs><filter id="soft"><feGaussianBlur stdDeviation="3"/></filter></defs>
<rect width="100" height="100" fill="#1E88E5" filter="url(#soft)"/></svg>
"""

@Suite struct FlarePlaceConformanceTests {
    @Test func takesSVGOnly() {
        let w = blank()
        #expect(w.placeFormats == [.svg])
        #expect(w.placeHelp == nil)
        #expect(w.placeCanvas == FlareCore.Rect(minX: 0, minY: 0, maxX: 480, maxY: 270))
        #expect(w.placeFillBox == nil)
        #expect(w.placedSelection == nil)
        #expect(w.placeReport == nil)
    }

    @Test func noDocumentSaysWhy() {
        let w = FlareWorkspace(services: .built)
        #expect(w.placeHelp == FlareLayerError.noDocument.message)
        #expect(w.placeCanvas.width == 0)
    }
}

@Suite struct FlarePlaceTests {
    @Test func groupsStayLayers() throws {
        var w = blank()
        try place(logo, on: &w)
        let added = layers(w)
        #expect(added.map(\.name) == ["red", "blue"])
        let fills = added.compactMap { layer -> FlareCore.Color? in
            guard case .solid(let c)? = layer.shapes.first?.fill else { return nil }
            return c
        }
        let want = [(229.0, 57.0, 53.0), (30.0, 136.0, 229.0)]
        #expect(fills.count == 2)
        for (c, (r, g, b)) in zip(fills, want) {
            #expect(abs(c.r * 255 - r) <= 1 && abs(c.g * 255 - g) <= 1 && abs(c.b * 255 - b) <= 1)
        }
        #expect(w.placeReport == "Placed logo.svg: 2 layers.")
    }

    @Test func fitsInsideScene() throws {
        var w = blank()
        try place(wide, as: "wide.svg", on: &w)
        let box = try #require(layers(w).flatMap(\.shapes).compactMap(\.bounds).first)
        #expect(abs(box.width - 480) < 0.01 && abs(box.height - 160) < 0.01)
        #expect(abs(box.minX) < 0.01 && abs(box.minY - 55) < 0.01)
    }

    @Test func oneUndoStep() throws {
        var w = blank()
        let before = w.document
        try place(logo, on: &w)
        #expect(w.canUndo)
        w.undo()
        #expect(w.document == before)
        #expect(!w.canUndo)
    }

    @Test func ringKeepsItsHole() throws {
        var w = blank()
        try place(logo, on: &w)
        let ring = try #require(layers(w).first { $0.name == "blue" }?.shapes.first)
        #expect(contours(ring) == 2)
    }

    @Test func pngIsRefused() throws {
        var w = blank()
        let before = w.document
        let png = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        let error = #expect(throws: (any Error).self) { try place(png, as: "photo.png", on: &w) }
        #expect(String(describing: error).contains("Flare places SVG files."))
        #expect(w.document == before)
    }

    @Test func damagedSVGAddsNothing() throws {
        var w = blank()
        let before = w.document
        #expect(throws: (any Error).self) { try place("<svg xmlns=\"http://www.w3.org/2000/svg\"><g><rect", on: &w) }
        #expect(w.document == before)
        #expect(!w.canUndo)
    }

    @Test func reportNamesASkippedFilter() throws {
        var w = blank()
        try place(blurred, as: "soft.svg", on: &w)
        let report = try #require(w.placeReport)
        #expect(report.contains("Placed soft.svg"))
        #expect(report.contains("Skipped filter"))
    }
}
