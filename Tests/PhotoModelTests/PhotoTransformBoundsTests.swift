// PhotoTransformBoundsTests.swift: Free Transform's box frames the layer's painted pixels (alpha above
// 0), not the whole layer: a canvas-sized brush layer with a small square gets the square's box, paint
// across tiles gets their union (also past clear tiles), a selection cuts the painted box, an offset
// layer's box sits on the canvas where its paint does, an opaque layer keeps its whole bounds, and a
// clear layer (or a selection over clear pixels) refuses with "Nothing to transform.". Commit and the
// live preview place the moved square on its new box, and the layer keeps its extent (grown when the
// box leaves it) so later strokes still land. Runs on Linux and macOS.
import CoreRaster
import SuiteKernel
import Testing

@testable import PhotoModel

@Suite struct PhotoTransformBoundsTests {
    /// A 400 x 300 white image (2 x 2 tiles) under a new canvas-sized layer with `squares` filled red on it.
    private func painted(_ squares: [PixelRect]) throws -> PhotoWorkspace {
        var workspace = try whiteImage(400, 300)
        workspace.addLayer()
        workspace.setToolOption(.color(red: 200, green: 30, blue: 40))
        for square in squares {
            workspace.setSelection(square)
            workspace.fillSelection()
        }
        workspace.deselect()
        return workspace
    }

    private let square = PixelRect(x: 100, y: 80, width: 60, height: 50)
    /// Across the tile edge at 256 in both directions.
    private let crossing = PixelRect(x: 240, y: 200, width: 60, height: 80)

    private func box(_ r: PixelRect) -> TransformBox {
        TransformBox(box: Rect(minX: Double(r.x), minY: Double(r.y), maxX: Double(r.maxX), maxY: Double(r.maxY)))
    }

    @Test func aBrushLayerFramesItsPaintedPixels() throws {
        var workspace = try painted([square])
        let layer = try #require(workspace.selectedLayer)
        #expect(workspace.bounds(of: layer) == PixelRect(x: 0, y: 0, width: 400, height: 300))
        #expect(workspace.transformSelection == box(square))
        try workspace.beginTransform()
        #expect(workspace.transformDraft?.box == square)
        #expect(workspace.transformSelection == box(square))
    }

    @Test func paintAcrossTilesFramesTheUnion() throws {
        var workspace = try painted([square, crossing])
        try workspace.beginTransform()
        #expect(workspace.transformDraft?.box == PixelRect(x: 100, y: 80, width: 200, height: 200))
    }

    @Test func paintPastClearTilesIsFound() throws {
        let corner = PixelRect(x: 300, y: 270, width: 40, height: 20)
        var workspace = try painted([corner])
        try workspace.beginTransform()
        #expect(workspace.transformDraft?.box == corner, "three clear tiles first, the paint in the last")
    }

    @Test func aClearLayerRefuses() throws {
        var workspace = try painted([])
        #expect(workspace.transformHelp == nil, "the menu stays cheap: no scan for availability")
        #expect(workspace.transformSelection == nil)
        #expect(throws: PhotoRefusal("Nothing to transform.")) { try workspace.beginTransform() }
        #expect(workspace.transformDraft == nil)
    }

    @Test func aSelectionCutsThePaintedBox() throws {
        var workspace = try painted([square, crossing])
        workspace.setSelection(PixelRect(x: 120, y: 90, width: 280, height: 210))
        try workspace.beginTransform()
        #expect(workspace.transformDraft?.box == PixelRect(x: 120, y: 90, width: 180, height: 190))
        workspace.cancelTransform()
        workspace.setSelection(PixelRect(x: 320, y: 10, width: 60, height: 60))
        #expect(throws: PhotoRefusal("Nothing to transform.")) { try workspace.beginTransform() }
        #expect(workspace.transformDraft == nil)
    }

    @Test func anOffsetLayerFramesItsPaintOnTheCanvas() throws {
        var workspace = try painted([square])
        stroke(&workspace, .select, from: point(110, 90), to: point(117, 95))
        let layer = try #require(workspace.selectedLayer)
        #expect((layer.offsetX, layer.offsetY) == (7, 5))
        try workspace.beginTransform()
        #expect(workspace.transformDraft?.box == PixelRect(x: 107, y: 85, width: 60, height: 50))
        workspace.cancelTransform()
        workspace.setSelection(PixelRect(x: 130, y: 100, width: 100, height: 100))
        try workspace.beginTransform()
        #expect(workspace.transformDraft?.box == PixelRect(x: 130, y: 100, width: 37, height: 35))
    }

    @Test func anOpaqueLayerFramesTheWholeLayer() throws {
        var workspace = try whiteImage(400, 300)
        try workspace.beginTransform()
        #expect(workspace.transformDraft?.box == PixelRect(x: 0, y: 0, width: 400, height: 300))
    }

    @Test func commitAndThePreviewPlaceTheMovedSquare() throws {
        var workspace = try painted([square])
        try workspace.beginTransform()
        let moved = Rect(minX: 110, minY: 85, maxX: 170, maxY: 135)
        try workspace.setTransform(TransformBox(box: moved), name: "Move", drag: nil)
        let preview = try workspace.transformPreview.composite()
        try workspace.commitTransform()
        let layer = try #require(workspace.selectedLayer)
        #expect(workspace.bounds(of: layer) == PixelRect(x: 0, y: 0, width: 400, height: 300),
                "the layer keeps its extent")
        let picture = try workspace.composite()
        #expect(picture == preview, "Return lays exactly the last preview")
        #expect(try picture.pixel(x: 112, y: 87) != picture.pixel(x: 102, y: 82), "the square moved off (102, 82)")
        #expect(try picture.pixel(x: 102, y: 82) == picture.pixel(x: 5, y: 5), "white where the square was")
        try workspace.beginTransform()
        #expect(workspace.transformDraft?.box == PixelRect(x: 110, y: 85, width: 60, height: 50))
        workspace.cancelTransform()
        workspace.setSelection(PixelRect(x: 300, y: 200, width: 20, height: 20))
        workspace.fillSelection()
        workspace.deselect()
        try workspace.beginTransform()
        #expect(workspace.transformDraft?.box == PixelRect(x: 110, y: 85, width: 210, height: 135),
                "paint outside the old box lands on the layer")
    }

    @Test func aMoveOffTheLayerGrowsIt() throws {
        var workspace = try painted([square])
        try workspace.beginTransform()
        let off = TransformBox(box: Rect(minX: 370, minY: 280, maxX: 430, maxY: 330))
        try workspace.setTransform(off, name: "Move", drag: nil)
        try workspace.commitTransform()
        let layer = try #require(workspace.selectedLayer)
        #expect(workspace.bounds(of: layer) == PixelRect(x: 0, y: 0, width: 430, height: 330))
        try workspace.beginTransform()
        #expect(workspace.transformDraft?.box == PixelRect(x: 370, y: 280, width: 60, height: 50))
    }
}
