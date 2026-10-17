// FlareStubsTests.swift: the inspector-timeline contract stubs (IT-0, lead.md rule 18). Every Model signature the
// packet gives IT-1, IT-2 and IT-3 compiles and is callable on `.fake()`; each timeline setter leaves the document
// and its undo history unchanged and says why in its error (paint is built: FlarePaintTests); `load(_:)` clears the
// new state.
import FlareCore
@testable import FlareModel
import Testing

/// Bounce on the fakes with Ball selected at frame 12.
private func ballAt12() -> FlareWorkspace {
    var w = FlareWorkspace(services: .fake())
    w.load(FlareFixtures.bounce)
    w.selectLayer("ball")
    w.currentFrame = 12
    return w
}

@Test func inspectorSummaryReadsTheSceneOrTheSelectedLayer() {
    var w = FlareWorkspace(services: .fake())
    w.load(FlareFixtures.bounce)
    let scene = w.inspectorSummary
    #expect(scene.showsScene && scene.title == w.selectedScene?.name && scene.keys == nil)
    w.selectLayer("ball")
    w.currentFrame = 12
    let ball = w.inspectorSummary
    #expect(!ball.showsScene && ball.title == "Ball" && ball.frame == 12)
}

@Test func paintReadsNothingWithoutALayerAndAReadoutWithOne() {
    var w = FlareWorkspace(services: .fake())
    w.load(FlareFixtures.bounce)
    #expect(w.paint == nil)
    #expect(ballAt12().paint != nil)
}

@Test func paintSettersEditTheFakesWithoutATimelineError() {
    let setters: [(inout FlareWorkspace) -> Void] = [
        { $0.setFill(hex: "FF3B30") }, { $0.setStrokeWidth(4) }, { $0.setStrokeCap(.round) },
        { $0.setStrokeJoin(.bevel) }, { $0.setStrokeColor(hex: "00FF00") },
    ]
    for set in setters {
        var w = ballAt12()
        set(&w)
        #expect(w.canUndo && w.paintError == nil && w.timelineError == nil)
    }
}

@Test func keyEditsWithNoKeySelectedChangeNothingAndSetTimelineError() {
    let setters: [(inout FlareWorkspace) -> Void] = [
        { $0.moveSelectedKeys(by: 2, dragStart: 12) }, { $0.removeSelectedKeys() },
    ]
    for set in setters {
        var w = ballAt12()
        let before = w.document
        set(&w)
        #expect(w.document == before && !w.canUndo && w.selectedKeys.isEmpty)
        #expect(w.timelineError == FlareWorkspace.selectKeyFirst)
        #expect(w.paintError == nil)
    }
}

@Test func endKeyDragEndsTheDragWithoutAnError() {
    var w = ballAt12()
    let serial = w.keyDragSerial
    w.endKeyDrag()
    #expect(w.keyDragSerial == serial + 1 && w.timelineError == nil)
}

@Test func timelineLabelsReadTheSceneLabelsByFrame() {
    let w = ballAt12()
    #expect(w.timelineLabels.isEmpty == (w.services.keyframes.labels(FlareFixtures.bounce, sceneID: "scene-1").isEmpty))
    #expect(FlareWorkspace(services: .fake()).timelineLabels.isEmpty)
}

@Test func loadClearsPaintErrorSelectedKeysAndTimelineError() {
    var w = ballAt12()
    w.setFill(hex: "FF3B3")
    w.removeSelectedKeys()
    w.selectedKeys = [KeyRef(layerID: "ball", property: nil, frame: 12)]
    #expect(w.paintError != nil && w.timelineError != nil && !w.selectedKeys.isEmpty)
    w.load(FlareFixtures.bounce)
    #expect(w.paintError == nil && w.timelineError == nil && w.selectedKeys.isEmpty)
}
