// LiveShapesPositionKeyTests.swift: #1731. On `FlareServices.built` a new shape keys its position once at frame 0,
// inside its one "Add <Shape>" undo step, so an auto-key drag at frame 24 keys 24 and keeps 0. Runs on Linux and macOS.
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

@Test func theZeroKeysHoldTheStandardPosition() throws {
    var engine = CommandEngine(document: FlareFixtures.empty)
    let shapes = LiveShapes(), owner = LayerOwner.scene("scene-1")
    let draft = try #require(shapes.draft(.rectangle, from: Point(x: 10, y: 10), to: Point(x: 50, y: 40),
                                          modifiers: [], previous: nil))
    let id = try shapes.commit(draft, owner: owner, aboveLayerID: nil, in: &engine)
    let layer = try #require(engine.document.layers(of: owner)?.first { $0.id == id })
    #expect(layer.tracks["x"] == [Keyframe(frame: 0, value: 0)])
    #expect(layer.tracks["y"] == [Keyframe(frame: 0, value: 0)])
    #expect(layer.tracks.count == 2)
}
