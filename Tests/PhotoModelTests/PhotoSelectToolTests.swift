// PhotoSelectToolTests.swift: Photo's Select tool (V) on the shared kernel rule (#6012): a click picks the layer
// whose pixel is under it and moves nothing, Shift toggles, an empty click keeps Photo's one picked layer, a box from
// empty canvas picks the layers it touches, the Layers list shows the same picks, and no pick is an undo step. A drag
// pressed on a layer moves it (Move folded into Select): one "Move Layer" step, on Move's live lift path.
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
        // The background is opaque, so each box starts off the canvas, where no layer is.
        w.drag(from: Mask.Point(x: 150, y: 150), to: Mask.Point(x: 50, y: 50))
        w.endDrag()
        #expect(w.selectedLayerIDs == [bottom])
        w.drag(from: Mask.Point(x: -10, y: -10), to: Mask.Point(x: 30, y: 30))
        w.endDrag()
        #expect(w.selectedLayerIDs == [top, bottom])
        #expect(w.layers.allSatisfy { $0.offsetX == 0 && $0.offsetY == 0 }, "a box moves nothing")
    }

    @Test func aPressOnALayerMovesItInOneUndoStep() throws {
        var (w, top, bottom) = try Self.two()
        w.selectLayer(bottom)
        let before = w.layers, steps = w.history.kernel.steps
        let press = Mask.Point(x: 10, y: 10)
        #expect(w.dragRunsLive(pressAt: press) && !w.dragShowsLineOnly(pressAt: press), "the window routes it to the live lift")
        // The press lands on the top layer's paint: it becomes the pick and moves; the background stays.
        for x in [10.0, 12, 15] { w.drag(from: Mask.Point(x: 10, y: 10), to: Mask.Point(x: x, y: 13)) }
        #expect(w.selectBox == nil, "a move draws no box")
        w.endDrag()
        #expect(w.selectedLayerIDs == [top])
        #expect(w.layers.first { $0.id == top }.map { [$0.offsetX, $0.offsetY] } == [5, 3])
        #expect(w.layers.first { $0.id == bottom }.map { [$0.offsetX, $0.offsetY] } == [0, 0])
        #expect(w.history.kernel.steps == steps + ["Move Layer"], "one undo step")
        w.undo()
        #expect(w.layers == before)
    }

    @Test func aPressOnEmptyCanvasDrawsABoxSelection() throws {
        var w = PhotoWorkspace()
        try w.newImage(DocumentSetup(width: 100, height: 100, background: .transparent))
        let bottom = try #require(w.selectedLayerID)
        w.selectTool(.brush)
        w.drag(from: Mask.Point(x: 80, y: 80), to: Mask.Point(x: 82, y: 80))
        w.endDrag()
        w.addLayer()
        w.drag(from: Mask.Point(x: 10, y: 10), to: Mask.Point(x: 12, y: 10))
        w.endDrag()
        w.selectTool(.select)
        let steps = w.history.kernel.steps
        let press = Mask.Point(x: 50, y: 50)
        #expect(w.dragShowsLineOnly(pressAt: press) && !w.dragRunsLive(pressAt: press), "the window routes it to the box's copy")
        w.drag(from: press, to: Mask.Point(x: 95, y: 95))
        #expect(w.selectBox == Rect(minX: 50, minY: 50, maxX: 95, maxY: 95), "the press on clear pixels draws a box")
        w.endDrag()
        #expect(w.selectedLayerIDs == [bottom])
        #expect(w.layers.allSatisfy { $0.offsetX == 0 && $0.offsetY == 0 }, "a box moves nothing")
        #expect(w.history.kernel.steps == steps, "a box pick is not an undo step")
    }
}
