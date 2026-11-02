// PhotoTransformDragTests.swift: a canvas drag while Free Transform is up (PhotoTransform.swift,
// PhotoStroke.endDrag). A press on no handle moves nothing itself, so its release records no "Transform" step
// even when the handles' own drag changed the draft meanwhile (the window runs both on one live copy); a press
// on the box's body moves the draft and records one. Runs on Linux and macOS.
import CoreRaster
import SuiteKernel
import Testing

@testable import PhotoModel

@Suite struct PhotoTransformDragTests {
    @Test func aPressOffTheBoxRecordsNoTransformStepWhenTheHandlesTurnTheDraft() throws {
        var workspace = try PhotoLiveTransformTests.transforming()
        workspace.drags([(from: Mask.Point(x: 5, y: 5), to: Mask.Point(x: 6, y: 6), pressure: 1, sampling: false)])
        var box = try #require(workspace.transformSelection)
        box.degrees = 20
        try workspace.setTransform(box, name: "Rotate", drag: "knob")
        workspace.endDrag()
        #expect(workspace.undoActionName == "Undo Rotate", "\(workspace.undoActionName)")
    }

    @Test func aPressOnTheBodyMovesTheDraftAndRecordsOneTransformStep() throws {
        var workspace = try PhotoLiveTransformTests.transforming()
        let before = try #require(workspace.transformSelection?.box)
        workspace.drags([(from: Mask.Point(x: 150, y: 100), to: Mask.Point(x: 170, y: 110), pressure: 1, sampling: false)])
        workspace.endDrag()
        let box = try #require(workspace.transformSelection?.box)
        #expect(box.minX == before.minX + 20 && box.minY == before.minY + 10, "\(box)")
        #expect(workspace.undoActionName == "Undo Transform", "\(workspace.undoActionName)")
    }
}
