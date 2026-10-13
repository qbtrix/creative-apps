// ShapeFakesAdversarialTests.swift: edge cases for the LM-0a2b fake shapes (#317). Locked and empty writes leave no
// undo entry, bad drafts give nil, a scale keeps the opposite handle on every handle, and multi-layer duplicate and
// paste keep paint order in one entry.
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

@Test func everyWriteOnALockedLayerThrowsAndLeavesNoEntry() {
    var engine = CommandEngine(document: FlareFixtures.bounce)
    let box = Rect(minX: 0, minY: 0, maxX: 550, maxY: 400)
    let path = FlarePath(polyline: [Point(x: 0, y: 0), Point(x: 9, y: 9)], closed: false)
    #expect(throws: CommandError.layerLocked("background")) {
        try shapes.commitBox(.move(dx: 5, dy: 5), layers: ["background"], sceneID: "scene-1", frame: 0, box: box,
                             autoKey: false, in: &engine)
    }
    #expect(throws: CommandError.layerLocked("background")) { try shapes.translate([item("background")], dx: 5, dy: 5, in: &engine) }
    #expect(throws: CommandError.layerLocked("background")) { try shapes.setPath(path, of: item("background"), in: &engine) }
    #expect(!engine.canUndo && engine.document == FlareFixtures.bounce)
}

@Test func writesThatChangeNothingLeaveNoEntry() throws {
    var engine = CommandEngine(document: FlareFixtures.bounce)
    try shapes.delete([], in: &engine)
    try shapes.translate([], dx: 5, dy: 5, in: &engine)
    #expect(try shapes.duplicate(layers: ["nope"], owner: scene, in: &engine).isEmpty)
    try shapes.commitBox(.rotate(degrees: 30), layers: ["nope"], sceneID: "scene-1", frame: 0,
                         box: Rect(minX: 0, minY: 0, maxX: 9, maxY: 9), autoKey: true, in: &engine)
    #expect(!engine.canUndo && engine.document == FlareFixtures.bounce)
}

@Test func badBoxesAndPointsGiveNoDraft() {
    let huge = 1e308, nan = Double.nan
    #expect(shapes.draft(.rectangle, from: Point(x: -huge, y: -huge), to: Point(x: huge, y: huge), modifiers: [.option], previous: nil) == nil)
    #expect(shapes.draft(.ellipse, from: Point(x: nan, y: 0), to: Point(x: 9, y: 9), modifiers: [], previous: nil) == nil)
    #expect(shapes.draft(.pen, from: Point(x: .infinity, y: 0), to: Point(x: 0, y: 0), modifiers: [], previous: nil) == nil)
    #expect(shapes.draft(.ellipse, from: Point(x: 3, y: 3), to: Point(x: 3, y: 3), modifiers: [.shift], previous: nil) == nil)
}

@Test func anEllipseDraftFillsItsBoxExactly() throws {
    let ellipse = try #require(shapes.draft(.ellipse, from: Point(x: 100, y: 50), to: Point(x: 0, y: 0), modifiers: [], previous: nil))
    #expect(ellipse.shape.bounds == Rect(minX: 0, minY: 0, maxX: 100, maxY: 50))
    #expect(ellipse.shape.points.count == FakeShapes.ellipseSides && !ellipse.shape.points.contains { !$0.isFinite })
}

@Test(arguments: 0..<8)
func aScaleOnAStillLayerKeepsTheOppositeHandleOnEveryHandle(_ handle: Int) throws {
    var engine = CommandEngine(document: FlareFixtures.bounce)
    let box = try #require(bounds(engine, "shadow"))
    let (grip, fixed) = (FakeShapes.handle(handle, on: box), FakeShapes.handle(handle + 4, on: box))
    let to = Point(x: grip.x + (grip.x - fixed.x) * 0.75, y: grip.y + (grip.y - fixed.y) * 0.75)  // outward, no flip
    try shapes.commitBox(.scale(handle: handle, to: to), layers: ["shadow"], sceneID: "scene-1", frame: 7, box: box,
                         autoKey: false, in: &engine)
    let after = try #require(bounds(engine, "shadow"))
    let (before, now) = (FakeShapes.handle(handle + 4, on: box), FakeShapes.handle(handle + 4, on: after))
    #expect(abs(before.x - now.x) < 1e-9 && abs(before.y - now.y) < 1e-9 && engine.undoActionName == "Undo Scale")
    #expect(layers(engine)[1].tracks["scaleX"]?.map(\.frame) == [0])  // not animated: one key at frame 0
}

@Test func aFullTurnPutsTheLayerBack() {
    let box = Rect(minX: 10, minY: 20, maxX: 300, maxY: 200)
    let turn = shapes.boxResult(.rotate(degrees: 360), layers: ["shadow"], document: FlareFixtures.bounce, sceneID: "scene-1",
                                frame: 0, box: box)
    #expect(turn["shadow"] == ["x": 0, "y": 0, "rotation": 360])
}

@Test func duplicatingTwoLayersPutsEachAboveItsOriginalInOneEntry() throws {
    var engine = CommandEngine(document: FlareFixtures.bounce)
    #expect(try shapes.duplicate(layers: ["ball", "shadow"], owner: scene, in: &engine) == ["shadow-copy-1", "ball-copy-1"])
    #expect(layers(engine).map(\.name) == ["Background", "Shadow", "Shadow copy", "Ball", "Ball copy"])
    #expect(engine.undoActionName == "Undo Duplicate")
    try engine.undo()
    #expect(engine.document == FlareFixtures.bounce && !engine.canUndo)
}

@Test func pastingTwoLayersKeepsTheirOrderAndANonFiniteOffsetChangesNothing() throws {
    var engine = CommandEngine(document: FlareFixtures.bounce)
    let data = try shapes.copy(layers: ["ball", "shadow"], owner: scene, from: engine.document)
    #expect(throws: (any Error).self) { try shapes.paste(data, owner: scene, aboveLayerID: nil, offset: .nan, in: &engine) }
    #expect(!engine.canUndo && engine.document == FlareFixtures.bounce)
    #expect(try shapes.paste(data, owner: scene, aboveLayerID: "shadow", offset: 10, in: &engine) == ["shadow-copy-1", "ball-copy-1"])
    #expect(layers(engine).map(\.name) == ["Background", "Shadow", "Shadow copy", "Ball copy", "Ball"])
    #expect(layers(engine)[2].tracks["x"] == [Keyframe(frame: 0, value: 10)] && engine.undoActionName == "Undo Paste")
}

@Test func pastingAboveAMissingOrLockedLayerThrowsLikeCommitAndLeavesNoEntry() throws {
    var engine = CommandEngine(document: FlareFixtures.bounce)
    let data = try shapes.copy(layers: ["ball"], owner: scene, from: engine.document)
    #expect(throws: CommandError.layerNotFound("nope")) {
        try shapes.paste(data, owner: scene, aboveLayerID: "nope", offset: 10, in: &engine)
    }
    #expect(throws: CommandError.layerLocked("background")) {
        try shapes.paste(data, owner: scene, aboveLayerID: "background", offset: 10, in: &engine)
    }
    #expect(!engine.canUndo && engine.document == FlareFixtures.bounce)
}
