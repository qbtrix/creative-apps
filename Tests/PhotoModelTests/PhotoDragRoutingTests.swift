// PhotoDragRoutingTests.swift: drags carry their modifier keys and zoom to
// the component that owns the tool (S-7a). Shift reaches the marquee's
// selectionDrag; today's `sampling:` wrappers are drags with Option; the
// eyedropper sets the brush color without a history step; a transform in
// progress takes every drag and moves its box. Runs on Linux and macOS.
import CoreRaster
@testable import PhotoModel
import SuiteKernel
import Testing

@Suite struct PhotoDragRoutingTests {
    static let a = Mask.Point(x: 520, y: 180), b = Mask.Point(x: 600, y: 260)

    @Test func aShiftDragReachesSelectionDragWithShift() throws {
        var model = try PhotoWorkspace.fixture(.sample)
        model.selectTool(.marquee)
        model.drag(from: Self.a, to: Self.b, modifiers: [.shift], zoom: 2)
        #expect(model.stroke?.modifiers == [.shift])
        #expect(model.selection == PixelRect(x: 520, y: 180, width: 80, height: 80))
        var batched = try PhotoWorkspace.fixture(.sample)
        batched.selectTool(.marquee)
        batched.drags([(from: Self.a, to: Self.b, pressure: 1, modifiers: [.shift, .option])], zoom: 0.5)
        #expect(batched.stroke?.modifiers == [.shift, .option])
    }

    @Test(arguments: PhotoTool.allCases)
    func theSamplingWrapperIsADragWithOption(_ tool: PhotoTool) throws {
        var old = try PhotoWorkspace.fixture(.sample)
        old.selectTool(tool)
        var new = old
        old.drag(from: Self.a, to: Self.b, sampling: true)
        new.drag(from: Self.a, to: Self.b, modifiers: [.option])
        #expect(old == new)
        old.drags([(from: Self.b, to: Self.a, pressure: 0.5, sampling: true)])
        new.drags([(from: Self.b, to: Self.a, pressure: 0.5, modifiers: [.option])])
        #expect(old == new)
        old.endDrag()
        new.endDrag()
        #expect(old == new)
    }

    @Test func theEyedropperSetsTheBrushColorWithNoHistoryStep() throws {
        var model = try PhotoWorkspace.fixture(.sample)
        model.selectTool(.eyedropper)
        let steps = model.historySteps
        model.drag(from: Self.a, to: Self.b)
        model.endDrag()
        #expect(model.historySteps == steps && !model.canUndo)
        // The kernel's mean of the composite under the drag's end, not a fake's colour (EP-2).
        let want = try #require(model.sampledColor(at: Point(x: Self.b.x, y: Self.b.y), size: model.sampleSize))
        let options = model.brushOptions
        #expect([options.red, options.green, options.blue].map(Int.init) == [want.r, want.g, want.b].map(SampleRules.byte))
    }

    /// On `.live` (its sampler built, eyedropper PE-5) a drag picks the white
    /// canvas into the brush colour, still with no history step.
    @Test func theLiveEyedropperPicksWithNoHistoryStep() throws {
        var model = PhotoWorkspace()
        try model.newCanvas(width: 64, height: 64)
        model.setToolOption(.color(red: 10, green: 20, blue: 30))
        model.selectTool(.eyedropper)
        let steps = model.historySteps
        model.drag(from: Mask.Point(x: 8, y: 8), to: Mask.Point(x: 40, y: 40))
        model.endDrag()
        #expect(model.historySteps == steps)
        let options = model.brushOptions
        #expect((options.red, options.green, options.blue) == (255, 255, 255))
        #expect(model.toolHelp(.eyedropper) == nil)
    }

    @Test func aTransformInProgressTakesTheDrag() throws {
        var model = try PhotoWorkspace.fixture(.sample)
        model.selectTool(.brush)
        let id = try #require(model.selectedLayerID)
        model.transformDraft = TransformDraft(layerID: id, box: PixelRect(x: 0, y: 0, width: 800, height: 600))
        let pixels = model.pixels
        model.drag(from: Self.a, to: Self.b)
        model.endDrag()
        #expect(model.pixels == pixels, "the brush doesn't paint")
        #expect(model.stroke == nil)
        let moved = try #require(model.transformDraft?.transform)
        #expect(moved.dx == 80 && moved.dy == 80, "the drag moves the transform box")
    }
}
