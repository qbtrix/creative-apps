// PhotoSelectToolTests.swift: Photo's Select tool on the shared kernel rule (#6012): a click picks the layer whose
// pixel is under it and moves nothing, Shift toggles, an empty click keeps Photo's one picked layer, a box picks the
// layers it touches, the Layers list shows the same picks, and no pick is an undo step.
import CoreRaster
@testable import PhotoModel
import SuiteKernel
import Testing

struct PhotoSelectToolTests {
    /// A 100 x 100 image: a clear top layer painted only in its top-left 20 x 20, over an opaque background.
    static func two() throws -> (PhotoWorkspace, top: String, bottom: String) {
        var w = PhotoWorkspace()
        try w.newImage(DocumentSetup(width: 100, height: 100))
        let bottom = try #require(w.selectedLayerID)
        w.addLayer()
        let top = try #require(w.selectedLayerID)
        w.selectTool(.brush)
        w.drag(from: Mask.Point(x: 10, y: 10), to: Mask.Point(x: 12, y: 10))
        w.endDrag()
        w.selectTool(.select)
        return (w, top, bottom)
    }

    static func click(_ w: inout PhotoWorkspace, _ x: Double, _ y: Double, _ mods: DragModifiers = []) {
        w.drag(from: Mask.Point(x: x, y: y), to: Mask.Point(x: x, y: y), modifiers: mods)
        w.endDrag()
    }

    @Test func clickPicksTheLayerUnderItAndMovesNothing() throws {
        var (w, top, bottom) = try Self.two()
        let offsets = w.layers.map { [$0.offsetX, $0.offsetY] }, steps = w.undoActionName
        Self.click(&w, 80, 80)
        #expect(w.selectedLayerIDs == [bottom])
        Self.click(&w, 10, 10)
        #expect(w.selectedLayerIDs == [top])
        Self.click(&w, 80, 80, .shift)
        #expect(Set(w.selectedLayerIDs) == [top, bottom])
        Self.click(&w, 80, 80, .shift)
        #expect(w.selectedLayerIDs == [top])
        Self.click(&w, 500, 500)
        #expect(w.selectedLayerIDs == [top], "an empty click keeps Photo's one picked layer")
        #expect(w.layers.map { [$0.offsetX, $0.offsetY] } == offsets)
        #expect(w.undoActionName == steps, "a pick is not an undo step")
    }

    @Test func boxPicksTheLayersItTouches() throws {
        var (w, top, bottom) = try Self.two()
        w.drag(from: Mask.Point(x: 50, y: 50), to: Mask.Point(x: 90, y: 90))
        w.endDrag()
        #expect(w.selectedLayerIDs == [bottom])
        w.drag(from: Mask.Point(x: 0, y: 0), to: Mask.Point(x: 30, y: 30))
        w.endDrag()
        #expect(w.selectedLayerIDs == [top, bottom])
    }
}
