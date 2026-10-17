// FlareTimelineEditTests.swift: inspector-timeline IT-3 acceptance on `.built`. Ball's summary key 24 dragged to 28 in
// four one-frame steps is one "Undo Move Keyframe"; a drag onto 36 refuses and moves nothing; deleting 12 is one entry;
// two frames inserted at 10 move 28 to 30 and one removed moves it to 29; a label set at 29 reads back and nil removes it.
import FlareCore
@testable import FlareModel
import Testing

private func bounce() -> FlareWorkspace {
    var w = FlareWorkspace(services: .built)
    w.load(FlareFixtures.bounce)
    return w
}

private func ballX(_ w: FlareWorkspace) -> [Int] {
    w.ownerLayers?.first { $0.id == "ball" }?.tracks["x"]?.map(\.frame) ?? []
}

private func ballKey(_ frame: Int) -> KeyRef { KeyRef(layerID: "ball", property: nil, frame: frame) }

/// Drags Ball's selected key `steps` one-frame steps from `start`, then ends the drag.
private func drag(_ w: inout FlareWorkspace, from start: Int, steps: Int) {
    for _ in 0..<steps { w.moveSelectedKeys(by: 1, dragStart: start) }
    w.endKeyDrag()
}

struct FlareTimelineEditTests {
    @Test func selectKeyReplacesOrTogglesTheSelection() {
        var w = bounce()
        w.selectKey(ballKey(12), extending: false)
        w.selectKey(ballKey(24), extending: true)
        #expect(w.selectedKeys == [ballKey(12), ballKey(24)])
        w.selectKey(ballKey(12), extending: true)
        #expect(w.selectedKeys == [ballKey(24)])
        w.selectKey(ballKey(36), extending: false)
        #expect(w.selectedKeys == [ballKey(36)] && w.timelineError == nil)
    }

    @Test func aFourStepDragIsOneUndoMoveKeyframe() {
        var w = bounce()
        w.selectKey(ballKey(24), extending: false)
        drag(&w, from: 24, steps: 4)
        #expect(ballX(w) == [0, 12, 28, 36, 47])
        #expect(w.selectedKeys == [ballKey(28)] && w.timelineError == nil)
        #expect(w.undoActionName == "Undo Move Keyframe")
        w.undo()
        #expect(ballX(w) == [0, 12, 24, 36, 47])
        #expect(!w.canUndo)
    }

    @Test func twoDragsAreTwoEntries() {
        var w = bounce()
        w.selectKey(ballKey(24), extending: false)
        drag(&w, from: 24, steps: 2)
        drag(&w, from: 26, steps: 2)
        w.undo()
        #expect(ballX(w) == [0, 12, 26, 36, 47])
    }

    @Test func aDragOntoAnotherKeyRefusesAndMovesNothing() {
        var w = bounce()
        w.selectKey(ballKey(24), extending: false)
        drag(&w, from: 24, steps: 4)
        let before = w.document
        w.moveSelectedKeys(by: 8, dragStart: 28)
        #expect(w.document == before && w.timelineError != nil)
        #expect(w.selectedKeys == [ballKey(28)] && w.undoActionName == "Undo Move Keyframe")
        w.selectKey(ballKey(28), extending: false)
        #expect(w.timelineError == nil)
    }

    @Test func movingWithNothingSelectedRefuses() {
        var w = bounce()
        let before = w.document
        w.moveSelectedKeys(by: 1, dragStart: 24)
        w.removeSelectedKeys()
        #expect(w.document == before && !w.canUndo && w.timelineError == FlareWorkspace.selectKeyFirst)
    }

    @Test func deletingTheSelectedKeyIsOneEntry() {
        var w = bounce()
        w.selectKey(ballKey(12), extending: false)
        w.removeSelectedKeys()
        #expect(ballX(w) == [0, 24, 36, 47] && w.selectedKeys.isEmpty)
        #expect(w.undoActionName == "Undo Delete Keyframe")
        w.undo()
        #expect(ballX(w) == [0, 12, 24, 36, 47] && !w.canUndo)
    }

    @Test func framesAndLabelsFollowThePlayhead() {
        var w = bounce()
        w.selectKey(ballKey(24), extending: false)
        drag(&w, from: 24, steps: 4)
        w.currentFrame = 10
        w.insertFrames(2)
        #expect(ballX(w).contains(30) && !ballX(w).contains(28) && w.selectedKeys == [ballKey(30)])
        #expect(w.undoActionName == "Undo Insert Frame")
        w.removeFrames(1)
        #expect(ballX(w).contains(29) && !ballX(w).contains(30) && w.selectedKeys == [ballKey(29)])
        #expect(w.undoActionName == "Undo Remove Frame")
        w.currentFrame = 29
        w.setLabel("hit")
        #expect(w.timelineLabels[29] == "hit" && w.timelineError == nil)
        w.currentFrame = 20
        w.insertFrames(1)
        #expect(w.timelineLabels[30] == "hit" && w.timelineLabels[29] == nil)
        w.currentFrame = 30
        w.setLabel(nil)
        #expect(w.timelineLabels[30] == nil)
        w.undo()
        #expect(w.timelineLabels[30] == "hit")
    }

    @Test func editsWithNoDocumentRefuse() {
        var w = FlareWorkspace(services: .built)
        w.insertFrames(1)
        #expect(w.timelineError != nil && w.document == nil)
        w.setLabel("hit")
        #expect(w.timelineError != nil && w.timelineLabels.isEmpty)
    }
}
