// ShapeFakesTests.swift: the LM-0a2b fake shapes on the `empty` and `bounce` fixtures (docs/blueprints/flare.md, 7.1):
// a rectangle commit is one "Undo Add Rectangle" entry, Shift gives equal sides, a scale keeps the opposite handle
// within 1e-9, copy then paste adds "Ball copy" in one "Undo Paste", and garbage paste data throws "Nothing to paste.".
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FlareCore
import FlareModel
import Testing

private let shapes = FlareServices.fake().shapes
private let scene = LayerOwner.scene("scene-1")
private func layers(_ engine: CommandEngine) -> [Layer] { engine.document.layers(of: scene) ?? [] }
private func item(_ id: String) -> StageAddress { StageAddress(owner: scene, layerID: id, item: .shape(0)) }
private func bounds(_ e: CommandEngine, _ id: String) -> Rect? { FakeHits().bounds(e.document, sceneID: "scene-1", frame: 0, of: [item(id)]) }
private func draft(_ tool: FlareTool, _ a: Point, _ b: Point, _ keys: DragModifiers = [], _ previous: ShapeDraft? = nil) -> ShapeDraft? {
    shapes.draft(tool, from: a, to: b, modifiers: keys, previous: previous)
}

@Test func aRectangleCommitIsOneUndoAddRectangleEntry() throws {
    var engine = CommandEngine(document: FlareFixtures.empty)
    let box = try #require(draft(.rectangle, Point(x: 40, y: 40), Point(x: 200, y: 160)))
    #expect(try shapes.commit(box, sceneID: "scene-1", aboveLayerID: nil, in: &engine) == "rectangle-1")
    #expect(bounds(engine, "rectangle-1") == Rect(minX: 40, minY: 40, maxX: 200, maxY: 160))
    #expect(layers(engine).map(\.name) == ["Rectangle 1"] && engine.undoActionName == "Undo Add Rectangle")
    try engine.undo()
    #expect(!engine.canUndo && layers(engine).isEmpty)
}

@Test func shiftGivesEqualSidesAndOptionDrawsFromTheCenter() throws {
    let square = try #require(draft(.rectangle, Point(x: 100, y: 100), Point(x: 40, y: 130), .shift))
    #expect(square.shape.bounds == Rect(minX: 40, minY: 100, maxX: 100, maxY: 160))
    let circle = try #require(draft(.ellipse, Point(x: 100, y: 100), Point(x: 110, y: 130), [.shift, .option]))
    #expect(circle.shape.bounds == Rect(minX: 70, minY: 70, maxX: 130, maxY: 130) && circle.shape.points.count == 32)
    #expect(draft(.rectangle, Point(x: 5, y: 5), Point(x: 5, y: 50)) == nil)
    #expect(draft(.select, Point(x: 0, y: 0), Point(x: 9, y: 9)) == nil)
}

@Test func aPenMarksDraggedAnchorsSmoothAndClosesOnItsFirstAnchor() throws {
    var path: ShapeDraft?
    for (x, y, drag) in [(0.0, 0.0, 0.0), (100, 0, 20), (100, 100, 0), (2, 1, 0)] {
        path = draft(.pen, Point(x: x, y: y), Point(x: x + drag, y: y), [], path)
    }
    let pen = try #require(path)
    #expect(pen.anchors.count == 3 && pen.smoothAnchors == [1] && pen.isClosed && pen.shape.closed)
    var engine = CommandEngine(document: FlareFixtures.empty)
    let id = try shapes.commit(pen, sceneID: "scene-1", aboveLayerID: nil, in: &engine)
    #expect(id == "path-1" && engine.undoActionName == "Undo Add Path")
}

@Test(arguments: [(4, Point(x: 170, y: 190)), (0, Point(x: 20, y: 10)), (3, Point(x: 140, y: 0)), (6, Point(x: 75, y: 100))])
func aScaleKeepsTheOppositeHandleFixed(_ handle: Int, _ to: Point) throws {
    var engine = CommandEngine(document: FlareFixtures.bounce)
    let box = try #require(bounds(engine, "ball"))
    try shapes.commitBox(.scale(handle: handle, to: to), layers: ["ball"], sceneID: "scene-1", frame: 0, box: box,
                         autoKey: false, in: &engine)
    let after = try #require(bounds(engine, "ball"))
    let (before, now) = (FakeShapes.handle(handle + 4, on: box), FakeShapes.handle(handle + 4, on: after))
    let grip = FakeShapes.handle(handle, on: after)
    #expect(abs(before.x - now.x) < 1e-9 && abs(before.y - now.y) < 1e-9 && engine.undoActionName == "Undo Scale")
    #expect((handle % 4 == 1 || abs(grip.x - to.x) < 1e-9) && (handle % 4 == 3 || abs(grip.y - to.y) < 1e-9))
}

@Test func boxGesturesFollowTheNotAnimatedRule() throws {
    var engine = CommandEngine(document: FlareFixtures.bounce)
    let box = Rect(minX: 0, minY: 0, maxX: 100, maxY: 100)
    // Shadow has no track, so a move at frame 30 adds one key at 0; Ball is animated, so it keys the playhead.
    try shapes.commitBox(.move(dx: 10, dy: -5), layers: ["shadow", "ball"], sceneID: "scene-1", frame: 30, box: box,
                         autoKey: false, in: &engine)
    let (shadow, ball) = (layers(engine)[1], layers(engine)[2])
    #expect(shadow.tracks["x"] == [Keyframe(frame: 0, value: 10)] && shadow.tracks["y"] == [Keyframe(frame: 0, value: -5)])
    #expect(ball.tracks["x"]?.map(\.frame) == [0, 12, 24, 30, 36, 47] && engine.undoActionName == "Undo Move")
    let turn = shapes.boxResult(.rotate(degrees: 90), layers: ["shadow"], document: engine.document, sceneID: "scene-1",
                                frame: 0, box: box)
    #expect(turn["shadow"] == ["x": 105, "y": 10, "rotation": 90])
    try engine.undo()
    #expect(engine.document == FlareFixtures.bounce)
}

@Test func copyThenPasteAddsBallCopyInOneUndoPaste() throws {
    var engine = CommandEngine(document: FlareFixtures.bounce)
    let data = try shapes.copy(layers: ["ball"], owner: scene, from: engine.document)
    #expect(try shapes.paste(data, owner: scene, aboveLayerID: "ball", offset: 10, in: &engine) == ["ball-copy-1"])
    #expect(layers(engine).map(\.name) == ["Background", "Shadow", "Ball", "Ball copy"] && engine.undoActionName == "Undo Paste")
    #expect(layers(engine)[3].tracks["x"]?.map(\.value) == [90, 190, 285, 380, 480])  // 10 pt right
    #expect(try shapes.duplicate(layers: ["ball-copy-1"], owner: scene, in: &engine) == ["ball-copy-1-copy-2"])
    #expect(layers(engine).map(\.name).suffix(2) == ["Ball copy", "Ball copy 2"] && engine.undoActionName == "Undo Duplicate")
}

// Not JSON, no envelopes, and one envelope ("{}", base64) that is no command.
@Test(arguments: ["garbage", "[]", #"["e30="]"#])
func garbagePasteDataThrowsNothingToPaste(_ text: String) {
    var engine = CommandEngine(document: FlareFixtures.bounce)
    #expect(throws: CommandError.invalidDocument("Nothing to paste.")) {
        try shapes.paste(Data(text.utf8), owner: scene, aboveLayerID: nil, offset: 10, in: &engine)
    }
    #expect(!engine.canUndo)
}

@Test func translateEditPathAndDeleteAreOneEntryEach() throws {
    var engine = CommandEngine(document: FlareFixtures.bounce)
    try shapes.translate([item("shadow"), item("shadow")], dx: 5, dy: 0, in: &engine)
    #expect(bounds(engine, "shadow")?.minX == 240 && engine.undoActionName == "Undo Move")
    let line = FlarePath(polyline: [Point(x: 0, y: 0), Point(x: 50, y: 0), Point(x: 50, y: 50)], closed: true)
    try shapes.setPath(line, of: item("shadow"), in: &engine)
    #expect(layers(engine)[1].shapes[0].path == line && engine.undoActionName == "Undo Edit Path")
    try shapes.delete([item("shadow")], in: &engine)
    #expect(layers(engine)[1].shapes.isEmpty && engine.undoActionName == "Undo Delete")
    try engine.undo()
    #expect(layers(engine)[1].shapes[0].path == line)
    #expect(throws: CommandError.layerLocked("background")) { try shapes.delete([item("background")], in: &engine) }
}

@Test func anUnavailableFakeDrawsNothingAndThrowsItsReason() throws {
    let off = FakeShapes(unavailable: "Not connected yet (IN-1).")
    var engine = CommandEngine(document: FlareFixtures.bounce)
    #expect(off.unavailableHelp(for: .rectangle) == "Not connected yet (IN-1)." && shapes.unavailableHelp(for: .pen) == nil)
    #expect(throws: NotBuilt(reason: "Not connected yet (IN-1).")) { try off.duplicate(layers: ["ball"], owner: scene, in: &engine) }
    #expect(!engine.canUndo)
}
