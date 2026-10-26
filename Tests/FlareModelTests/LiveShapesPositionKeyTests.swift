// LiveShapesPositionKeyTests.swift: #1731. On `FlareServices.built` a new shape keys its position once at frame 0,
// inside its one "Add <Shape>" undo step, so an auto-key drag at frame 24 keys 24 and keeps 0. That position is the
// drawn shape's centre, with the path around the layer origin, so a keyed rotation turns the shape in place (B1).
// Runs on Linux and macOS.
import FlareCore
import FlareModel
import Testing

private func keyFrames(_ w: FlareWorkspace) -> [[Int]] { w.timelineRows.map(\.keyFrames) }

@Test func aDrawnShapeKeysZeroAndAnAutoKeyDragKeepsIt() {
    var w = FlareWorkspace(launch: FlareLaunch(arguments: []))
    w.newDocument(); w.selectTool(.rectangle)
    w.drag(from: Point(x: 100, y: 100), to: Point(x: 200, y: 180))
    #expect(keyFrames(w) == [[0]])
    #expect(w.undoActionName == "Undo Add Rectangle")
    w.toggleAutoKey(); w.selectTool(.select); w.setCurrentFrame(24)
    w.drag(from: Point(x: 150, y: 140), to: Point(x: 350, y: 140))
    #expect(keyFrames(w) == [[0, 24]])
    w.undo()
    #expect(keyFrames(w) == [[0]])
    #expect(w.undoActionName == "Undo Add Rectangle")
}

@Test func oneUndoAfterTheDrawRemovesTheShapeAndItsKeys() {
    var w = FlareWorkspace(launch: FlareLaunch(arguments: []))
    w.newDocument(); w.selectTool(.ellipse)
    w.drag(from: Point(x: 100, y: 100), to: Point(x: 200, y: 180))
    #expect(w.layers.map(\.name) == ["Ellipse 1"])
    w.undo()
    #expect(w.layers.isEmpty && w.timelineRows.isEmpty)
    #expect(!w.canUndo)
}

/// The B1 stopgap: the layer's origin is the drawn shape's centre and its path sits around it, so the zero keys
/// hold that centre and the stage still shows the shape where it was drawn.
@Test func theZeroKeysHoldTheShapesCentre() throws {
    var engine = CommandEngine(document: FlareFixtures.empty)
    let shapes = LiveShapes(), owner = LayerOwner.scene("scene-1")
    let draft = try #require(shapes.draft(.rectangle, from: Point(x: 10, y: 10), to: Point(x: 50, y: 40),
                                          modifiers: [], previous: nil))
    let id = try shapes.commit(draft, owner: owner, aboveLayerID: nil, in: &engine)
    let layer = try #require(engine.document.layers(of: owner)?.first { $0.id == id })
    #expect(layer.tracks["x"] == [Keyframe(frame: 0, value: 30)])
    #expect(layer.tracks["y"] == [Keyframe(frame: 0, value: 25)])
    #expect(layer.tracks.count == 2)
    #expect(layer.shapes.first?.bounds == Rect(minX: -20, minY: -15, maxX: 20, maxY: 15))
    let item = try #require(LiveStage().drawList(engine.document, sceneID: "scene-1", frame: 0, editing: nil).items.first)
    #expect(item.path.transformed(by: item.transform).bounds == Rect(minX: 10, minY: 10, maxX: 50, maxY: 40))
}

/// B1: a drawn shape keyed from 0 to 360 degrees spins in place; before the stopgap its origin was the canvas's
/// top-left corner, so mid-tween it orbited that corner.
@Test(arguments: [FlareTool.rectangle, .ellipse, .pen])
func aDrawnShapeKeyedToSpinTurnsAboutItsOwnCentre(_ tool: FlareTool) throws {
    var engine = CommandEngine(document: FlareFixtures.empty)
    let shapes = LiveShapes(), owner = LayerOwner.scene("scene-1")
    var draft: ShapeDraft?
    if tool == .pen {
        for p in [Point(x: 100, y: 100), Point(x: 200, y: 100), Point(x: 200, y: 180), Point(x: 100, y: 180)] {
            draft = shapes.draft(.pen, from: p, to: p, modifiers: [], previous: draft)
        }
    } else {
        draft = shapes.draft(tool, from: Point(x: 100, y: 100), to: Point(x: 200, y: 180), modifiers: [], previous: nil)
    }
    let id = try shapes.commit(try #require(draft), owner: owner, aboveLayerID: nil, in: &engine)
    for key in [Keyframe(frame: 0, value: 0), Keyframe(frame: 24, value: 360)] {
        try engine.perform(SetKeyframe(owner: owner, layerID: id, property: "rotation", keyframe: key))
    }
    for frame in [0, 6, 12, 18, 24] {
        let item = try #require(LiveStage().drawList(engine.document, sceneID: "scene-1", frame: frame, editing: nil).items.first)
        let box = try #require(item.path.transformed(by: item.transform).bounds)
        let mid = Point(x: (box.minX + box.maxX) / 2, y: (box.minY + box.maxY) / 2)
        #expect(abs(mid.x - 150) < 1e-9 && abs(mid.y - 140) < 1e-9, "\(tool) centre at frame \(frame): \(box)")
    }
}
