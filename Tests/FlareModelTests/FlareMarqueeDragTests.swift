// FlareMarqueeDragTests.swift: a selection-tool drag on empty stage is a marquee the app draws while the drag lasts
// (FlareMarqueeDrag). Its samples go to a copy of the model, outside the window's state; `take` hands the copy back
// at mouse-up to end there, and a click or a gesture that isn't a marquee (a pen or rectangle draft, a move) is
// left to the model. Runs on Linux and macOS.
import FlareCore
import FlareModel
import Testing

@Suite struct FlareMarqueeDragTests {
    private func workspace() -> FlareWorkspace {
        var model = FlareWorkspace(services: .fake())
        model.newDocument()
        return model
    }

    @Test func aSelectionDragOnEmptyStageIsAMarqueeThatLeavesTheModelAlone() {
        let model = workspace()
        var drag = FlareMarqueeDrag()
        let first = drag.sample(model, from: Point(x: 10, y: 10), to: Point(x: 40, y: 30), modifiers: [], stageScale: 1)
        let second = drag.sample(model, from: Point(x: 10, y: 10), to: Point(x: 60, y: 40), modifiers: [], stageScale: 1)
        #expect(first && second)
        #expect(drag.marquee == Rect(enclosing: [Point(x: 10, y: 10), Point(x: 60, y: 40)]))
        #expect(model.marquee == nil)
    }

    /// Mouse-up hands back the last sample's points and keys, which the window replays on the model as one drag.
    @Test func takeHandsBackTheGestureForTheModelToReplay() {
        let model = workspace()
        var drag = FlareMarqueeDrag()
        _ = drag.sample(model, from: Point(x: 10, y: 10), to: Point(x: 30, y: 20), modifiers: [.shift], stageScale: 2)
        _ = drag.sample(model, from: Point(x: 10, y: 10), to: Point(x: 60, y: 40), modifiers: [.shift], stageScale: 2)
        let committed = drag.take()
        let again = drag.take()
        #expect(committed == FlareMarqueeDrag.Gesture(start: Point(x: 10, y: 10), end: Point(x: 60, y: 40),
                                                      modifiers: [.shift], stageScale: 2))
        #expect(drag.marquee == nil)
        #expect(again == nil)
    }

    @Test func aClickIsNotAMarqueeSoTheModelTakesIt() {
        var drag = FlareMarqueeDrag()
        let taken = drag.sample(workspace(), from: Point(x: 10, y: 10), to: Point(x: 10, y: 10), modifiers: [], stageScale: 1)
        #expect(!taken)
        #expect(drag.marquee == nil)
    }

    @Test func aPenDragIsDeclinedForTheWholeGesture() {
        var model = workspace()
        model.selectTool(.pen)
        var drag = FlareMarqueeDrag()
        let first = drag.sample(model, from: Point(x: 10, y: 10), to: Point(x: 60, y: 40), modifiers: [], stageScale: 1)
        let second = drag.sample(model, from: Point(x: 10, y: 10), to: Point(x: 80, y: 60), modifiers: [], stageScale: 1)
        #expect(!first && !second)
        let taken = drag.take()
        #expect(taken == nil)
    }

    @Test func cancelDropsTheMarquee() {
        var drag = FlareMarqueeDrag()
        _ = drag.sample(workspace(), from: Point(x: 10, y: 10), to: Point(x: 60, y: 40), modifiers: [], stageScale: 1)
        drag.cancel()
        #expect(drag.marquee == nil)
        let taken = drag.take()
        #expect(taken == nil)
    }
}
