// PhotoDragRoutingTests.swift: drags carry their modifier keys and zoom to
// the component that owns the tool (S-7a). Shift reaches the marquee's
// selectionDrag; today's `sampling:` wrappers are drags with Option; the
// eyedropper sets the brush color without a history step; a transform in
// progress takes every drag. Runs on Linux and macOS.
import CoreRaster
@testable import PhotoModel
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
        let options = model.brushOptions
        #expect((options.red, options.green, options.blue) == (255, 204, 0))
    }

    @Test func theLiveEyedropperRefusesWithoutAChange() throws {
        var model = PhotoWorkspace()
        try model.newCanvas(width: 64, height: 64)
        model.selectTool(.eyedropper)
        let before = model
        model.drag(from: Mask.Point(x: 8, y: 8), to: Mask.Point(x: 40, y: 40))
        model.endDrag()
        #expect(model == before)
        #expect(model.toolHelp(.eyedropper)?.isEmpty == false)
    }

    @Test func aTransformInProgressTakesTheDrag() throws {
        var model = try PhotoWorkspace.fixture(.sample)
        model.selectTool(.brush)
        let id = try #require(model.selectedLayerID)
        model.transformDraft = TransformDraft(layerID: id, box: PixelRect(x: 0, y: 0, width: 800, height: 600))
        let before = model
        model.drag(from: Self.a, to: Self.b)
        model.endDrag()
        #expect(model == before)
    }
}
