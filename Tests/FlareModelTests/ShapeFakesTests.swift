// ShapeFakesTests.swift: the LM-0a2b shape fake (docs/blueprints/flare.md, 7.1): a rectangle commit leaves exactly one
// entry, "Undo Add Rectangle"; Shift gives equal sides; a scale gesture keeps the opposite corner within 1e-9; copy then
// paste adds "Ball copy" in one entry "Undo Paste"; garbage paste data throws "Nothing to paste.".
import FlareCore
import FlareModel
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import Testing

private let shapes = FakeShapes()
private let bounce = FlareFixtures.bounce
private let scene = LayerOwner.scene("scene-1")
private func names(_ engine: CommandEngine) -> [String] { engine.document.scenes[0].layers.map(\.name) }
private func ballBox(_ doc: Document) -> Rect? {
    FakeHits().bounds(doc, sceneID: "scene-1", frame: 0, of: [StageAddress(owner: scene, layerID: "ball", item: .shape(0))])
}

@Test func aRectangleCommitIsOneEntryUndoAddRectangle() throws {
    let draft = try #require(shapes.draft(.rectangle, from: Point(x: 10, y: 20), to: Point(x: 110, y: 70), modifiers: [], previous: nil))
    #expect(draft.shape.points == [Point(x: 10, y: 20), Point(x: 110, y: 20), Point(x: 110, y: 70), Point(x: 10, y: 70)])
    var engine = CommandEngine(document: FlareFixtures.empty)
    #expect(try shapes.commit(draft, sceneID: "scene-1", aboveLayerID: nil, in: &engine) == "rectangle-1")
    #expect(names(engine) == ["Rectangle 1"] && engine.undoActionName == "Undo Add Rectangle")
    try engine.undo()
    #expect(engine.document == FlareFixtures.empty && !engine.canUndo)
    // A second one goes on top with the next number; nothing is drawn above a locked layer.
    try engine.redo()
    #expect(try shapes.commit(draft, sceneID: "scene-1", aboveLayerID: nil, in: &engine) == "rectangle-2")
    var locked = bounce
    locked.scenes[0].layers[1].isLocked = true
    var lockedEngine = CommandEngine(document: locked)
    #expect(throws: CommandError.layerLocked("shadow")) { try shapes.commit(draft, sceneID: "scene-1", aboveLayerID: "shadow", in: &lockedEngine) }
    #expect(lockedEngine.document == locked && !lockedEngine.canUndo)
}

@Test func shiftGivesEqualSidesAndOptionDrawsFromTheCenter() throws {
    let square = try #require(shapes.draft(.rectangle, from: Point(x: 0, y: 0), to: Point(x: 40, y: -10), modifiers: .shift, previous: nil))
    let box = try #require(square.shape.bounds)
    #expect(box.width == 40 && box.height == 40 && box.minY == -40)
    let circle = try #require(shapes.draft(.ellipse, from: Point(x: 100, y: 100), to: Point(x: 130, y: 110),
                                           modifiers: [.shift, .option], previous: nil))
    let round = try #require(circle.shape.bounds)
    #expect(circle.shape.points.count == FakeShapes.ellipseSides && abs(round.width - round.height) < 1e-9)
    #expect(abs(round.minX - 70) < 1e-9 && abs(round.maxX - 130) < 1e-9)
    #expect(shapes.draft(.rectangle, from: Point(x: 5, y: 5), to: Point(x: 5, y: 5), modifiers: [], previous: nil) == nil)
    #expect(shapes.draft(.select, from: Point(x: 0, y: 0), to: Point(x: 9, y: 9), modifiers: [], previous: nil) == nil)
}

@Test func penAnchorsMarkDragsSmoothAndCloseOnTheFirstAnchor() throws {
    var draft: ShapeDraft?
    for (start, end) in [((0.0, 0.0), (0.0, 0.0)), ((50, 0), (60, 10)), ((50, 50), (50, 50)), ((2, 1), (2, 1))] {
        draft = shapes.draft(.pen, from: Point(x: start.0, y: start.1), to: Point(x: end.0, y: end.1), modifiers: [], previous: draft)
    }
    let path = try #require(draft)
    #expect(path.anchors.count == 3 && path.smoothAnchors == [1] && path.isClosed && path.shape.closed)
    var engine = CommandEngine(document: bounce)
    #expect(try shapes.commit(path, sceneID: "scene-1", aboveLayerID: "shadow", in: &engine) == "path-1")
    #expect(names(engine) == ["Background", "Shadow", "Path 1", "Ball"] && engine.undoActionName == "Undo Add Path")
}

@Test func aScaleGestureKeepsTheOppositeCornerFixed() throws {
    let box = try #require(ballBox(bounce))
    var engine = CommandEngine(document: bounce)
    // Drag the bottom-right handle (4) out to (170, 190): the top-left corner stays at (50, 70).
    try shapes.commitBox(.scale(handle: 4, to: Point(x: 170, y: 190)), layers: ["ball"], sceneID: "scene-1", frame: 0,
                         box: box, autoKey: false, in: &engine)
    let scaled = try #require(ballBox(engine.document))
    for (got, want) in [(scaled.minX, 50.0), (scaled.minY, 70), (scaled.maxX, 170), (scaled.maxY, 190)] {
        #expect(abs(got - want) < 1e-9)
    }
    #expect(engine.undoActionName == "Undo Scale")
    try engine.undo()
    #expect(engine.document == bounce && !engine.canUndo)
    // The right middle handle (3) leaves the height alone.
    let wide = shapes.boxResult(.scale(handle: 3, to: Point(x: 170, y: 0)), layers: ["ball"], document: bounce,
                                sceneID: "scene-1", frame: 0, box: box)
    #expect(wide["ball"]?["scaleY"] == 1 && wide["ball"]?["scaleX"] == 2)
    let turned = shapes.boxResult(.rotate(degrees: 180), layers: ["shadow"], document: bounce, sceneID: "scene-1",
                                  frame: 0, box: Rect(minX: 235, minY: 344, maxX: 315, maxY: 360))
    #expect(turned["shadow"] == ["x": 550, "y": 704, "rotation": 180])
}

@Test func boxGesturesFollowTheNotAnimatedRule() throws {
    let box = Rect(minX: 235, minY: 344, maxX: 315, maxY: 360)
    var engine = CommandEngine(document: bounce)
    try shapes.commitBox(.move(dx: 5, dy: 0), layers: ["shadow"], sceneID: "scene-1", frame: 30, box: box, autoKey: false, in: &engine)
    #expect(engine.document.scenes[0].layers[1].tracks["x"] == [Keyframe(frame: 0, value: 5)] && engine.undoActionName == "Undo Move")
    try shapes.commitBox(.move(dx: 5, dy: 0), layers: ["shadow"], sceneID: "scene-1", frame: 30, box: box, autoKey: true, in: &engine)
    #expect(engine.document.scenes[0].layers[1].tracks["x"]?.map(\.frame) == [0, 30])
    // Ball is animated: a move keys the playhead whatever auto-key says.
    try shapes.commitBox(.move(dx: 0, dy: 1), layers: ["ball"], sceneID: "scene-1", frame: 6, box: box, autoKey: false, in: &engine)
    #expect(engine.document.scenes[0].layers[2].tracks["y"]?.map(\.frame) == [0, 6, 12, 24, 36, 47])
}

@Test func copyThenPasteAddsBallCopyInOneEntry() throws {
    var engine = CommandEngine(document: bounce)
    let data = try shapes.copy(layers: ["ball"], owner: scene, from: engine.document)
    #expect(try shapes.paste(data, owner: scene, aboveLayerID: "ball", offset: 10, in: &engine) == ["ball-copy"])
    #expect(names(engine) == ["Background", "Shadow", "Ball", "Ball copy"] && engine.undoActionName == "Undo Paste")
    #expect(engine.document.scenes[0].layers[3].tracks["x"]?.map(\.value) == [90, 190, 285, 380, 480])
    _ = try shapes.paste(data, owner: scene, aboveLayerID: nil, offset: 0, in: &engine)
    #expect(try shapes.duplicate(layers: ["ball-copy"], owner: scene, in: &engine) == ["ball-copy-3"])
    #expect(names(engine) == ["Background", "Shadow", "Ball", "Ball copy", "Ball copy 3", "Ball copy 2"])
    #expect(engine.undoActionName == "Undo Duplicate")
    for _ in 0..<3 { try engine.undo() }
    #expect(engine.document == bounce)
}

@Test func garbagePasteDataThrowsNothingToPaste() throws {
    var engine = CommandEngine(document: bounce)
    let rename = try CommandRegistry.builtIn.encode(RenameLayer(owner: scene, layerID: "ball", name: "X"))
    for data in [Data("garbage".utf8), Data("[]".utf8), try JSONEncoder().encode(["{}"]),
                 try JSONEncoder().encode([String(decoding: rename, as: UTF8.self)])] {
        #expect(throws: CommandError.invalidDocument(FakeShapes.nothingToPaste)) {
            try shapes.paste(data, owner: scene, aboveLayerID: nil, offset: 10, in: &engine)
        }
    }
    #expect(engine.document == bounce && !engine.canUndo)
}

@Test func itemEditsRefuseUntilTheyAreBuilt() {
    var engine = CommandEngine(document: bounce)
    let shadow = StageAddress(owner: scene, layerID: "shadow", item: .shape(0))
    #expect(throws: NotBuilt(reason: FakeShapes.itemEditsHelp)) { try shapes.delete([shadow], in: &engine) }
    #expect(throws: NotBuilt(reason: FakeShapes.itemEditsHelp)) { try shapes.translate([shadow], dx: 1, dy: 1, in: &engine) }
    #expect(throws: NotBuilt(reason: FakeShapes.itemEditsHelp)) { try shapes.setPath(FlarePath(), of: shadow, in: &engine) }
    #expect(engine.document == bounce && !engine.canUndo)
}

@Test func anUnavailableShapeFakeDrawsNothingAndRefusesWrites() {
    let reason = "Not connected yet (IN-1)."
    let off = FakeShapes(unavailable: reason)
    var engine = CommandEngine(document: bounce)
    #expect(off.unavailableHelp(for: .rectangle) == reason && shapes.unavailableHelp(for: .rectangle) == nil)
    #expect(off.draft(.rectangle, from: Point(x: 0, y: 0), to: Point(x: 9, y: 9), modifiers: [], previous: nil) == nil)
    #expect(throws: NotBuilt(reason: reason)) { try off.duplicate(layers: ["ball"], owner: scene, in: &engine) }
    #expect(throws: NotBuilt(reason: reason)) { try off.copy(layers: ["ball"], owner: scene, from: bounce) }
    #expect(engine.document == bounce && !engine.canUndo)
}
