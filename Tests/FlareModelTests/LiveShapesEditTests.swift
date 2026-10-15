// LiveShapesEditTests.swift: ST-9 of live-stage (#740), the live edits. Each edit is one named undo entry of real
// FlareCore commands that one undo() reverts exactly; a text move and a garbage paste throw and change nothing; a
// duplicate or paste is named by the fake's rule ("Ball copy", "Ball copy 2") with a fresh id; and `LiveShapes` is a
// `ShapeBuilding`.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FlareCore
import FlareModel
import Testing

private let scene = LayerOwner.scene("scene-1")
private let shapes: any ShapeBuilding = LiveShapes()

private func item(_ layer: String, _ item: StageAddress.Item = .shape(0)) -> StageAddress {
    StageAddress(owner: scene, layerID: layer, item: item)
}
private func layers(_ engine: CommandEngine) -> [Layer] { engine.document.layers(of: scene) ?? [] }

@Test func liveSetPathThenUndoRestoresThePathExactly() throws {
    var engine = CommandEngine(document: FlareFixtures.bounce)
    let line = FlarePath(polyline: [Point(x: 0, y: 0), Point(x: 50, y: 0), Point(x: 50, y: 50)], closed: true)
    try shapes.setPath(line, of: item("shadow"), in: &engine)
    let edited = layers(engine)[1].shapes[0]
    #expect(edited.path == line && edited.points.count == 3 && engine.undoActionName == "Undo Edit Path")
    try engine.undo()
    #expect(engine.document == FlareFixtures.bounce && !engine.canUndo)
}

@Test func liveTranslateMovesTheShapeNotTheLayer() throws {
    var engine = CommandEngine(document: FlareFixtures.bounce)
    try shapes.translate([item("ball"), item("ball")], dx: 5, dy: -3, in: &engine)
    let before = try #require(FlareFixtures.bounce.layers(of: scene)?[2]), after = layers(engine)[2]
    #expect(after.tracks == before.tracks && engine.undoActionName == "Undo Move")
    #expect(after.shapes[0].points == before.shapes[0].points.map { Point(x: $0.x + 5, y: $0.y - 3) })
    try engine.undo()
    #expect(engine.document == FlareFixtures.bounce && !engine.canUndo)
}

@Test func liveTranslateMovesAnInstanceByItsTransform() throws {
    var engine = CommandEngine(document: FlareFixtures.showcase)
    try shapes.translate([item("spinner", .instance(0)), item("ball")], dx: 10, dy: 4, in: &engine)
    let spinner = try #require(layers(engine).first { $0.id == "spinner" })
    #expect(spinner.instances[0].transform == Transform(x: 480, y: 84) && engine.undoActionName == "Undo Move")
    try engine.undo()
    #expect(engine.document == FlareFixtures.showcase && !engine.canUndo)
}

@Test func liveTranslatingTextThrowsAndChangesNothing() {
    var engine = CommandEngine(document: FlareFixtures.showcase)
    #expect(throws: CommandError.invalidDocument("Text can't be moved yet.")) {
        try shapes.translate([item("ball"), item("title", .text(0))], dx: 5, dy: 5, in: &engine)
    }
    #expect(engine.document == FlareFixtures.showcase && !engine.canUndo)
}

@Test func liveDeleteOfAShapeAndAnInstanceIsOneUndoDelete() throws {
    var engine = CommandEngine(document: FlareFixtures.showcase)
    try shapes.delete([item("ball"), item("spinner", .instance(0)), item("title", .text(0))], in: &engine)
    // Each emptied layer goes too, as the fake does.
    #expect(layers(engine).map(\.id) == ["background", "shadow"] && engine.undoActionName == "Undo Delete")
    try engine.undo()
    #expect(engine.document == FlareFixtures.showcase && !engine.canUndo)
}

@Test func liveDuplicateGivesBallCopyWithAFreshID() throws {
    var engine = CommandEngine(document: FlareFixtures.bounce)
    let first = try shapes.duplicate(layers: ["ball"], owner: scene, in: &engine)
    #expect(first.count == 1 && layers(engine).map(\.name) == ["Background", "Shadow", "Ball", "Ball copy"])
    #expect(engine.undoActionName == "Undo Duplicate" && Set(layers(engine).map(\.id)).count == 4)
    let second = try shapes.duplicate(layers: first, owner: scene, in: &engine)
    #expect(layers(engine).map(\.name).suffix(2) == ["Ball copy", "Ball copy 2"])
    #expect(second.count == 1 && second != first && Set(layers(engine).map(\.id)).count == 5)
    try engine.undo()
    try engine.undo()
    #expect(engine.document == FlareFixtures.bounce && !engine.canUndo)
}

@Test func liveCopyThenPasteGivesBallCopyTenPointsRightInOneUndoPaste() throws {
    var engine = CommandEngine(document: FlareFixtures.bounce)
    let data = try shapes.copy(layers: ["ball"], owner: scene, from: engine.document)
    #expect(engine.document == FlareFixtures.bounce && !engine.canUndo)
    let added = try shapes.paste(data, owner: scene, aboveLayerID: "shadow", offset: 10, in: &engine)
    #expect(added.count == 1 && !["ball", "shadow", "background"].contains(added[0]))
    #expect(layers(engine).map(\.name) == ["Background", "Shadow", "Ball copy", "Ball"])
    #expect(layers(engine)[2].tracks["x"]?.map(\.value) == [90, 190, 285, 380, 480])  // 10 pt right
    #expect(engine.undoActionName == "Undo Paste")
    try engine.undo()
    #expect(engine.document == FlareFixtures.bounce && !engine.canUndo)
}

@Test(arguments: ["x", "garbage", "[]", #"["e30="]"#])
func liveGarbagePasteThrowsNothingToPaste(_ text: String) {
    var engine = CommandEngine(document: FlareFixtures.bounce)
    #expect(throws: CommandError.invalidDocument("Nothing to paste.")) {
        try shapes.paste(Data(text.utf8), owner: scene, aboveLayerID: nil, offset: 10, in: &engine)
    }
    #expect(engine.document == FlareFixtures.bounce && !engine.canUndo)
}

@Test func livePasteAboveAMissingOrLockedLayerThrows() throws {
    var engine = CommandEngine(document: FlareFixtures.bounce)
    let data = try shapes.copy(layers: ["ball"], owner: scene, from: engine.document)
    #expect(throws: CommandError.layerNotFound("nope")) {
        try shapes.paste(data, owner: scene, aboveLayerID: "nope", offset: 10, in: &engine)
    }
    try engine.perform(SetLayerFlags(owner: scene, layerID: "shadow", isLocked: true))
    let locked = engine.document
    #expect(throws: CommandError.layerLocked("shadow")) {
        try shapes.paste(data, owner: scene, aboveLayerID: "shadow", offset: 10, in: &engine)
    }
    #expect(engine.document == locked)
}

/// Bounce with Ball renamed `name`, built directly so no undo entry precedes the duplicate.
private func bounce(ballNamed name: String) -> Document {
    var document = FlareFixtures.bounce
    for s in document.scenes.indices {
        for l in document.scenes[s].layers.indices where document.scenes[s].layers[l].id == "ball" {
            document.scenes[s].layers[l].name = name
        }
    }
    return document
}

// One " copy" or " copy N" comes off before the new suffix, live and fake alike.
@Test(arguments: [("Ball", "Ball copy"), ("Ball copy", "Ball copy 2"), ("Ball copy 2", "Ball copy"),
                  ("Ball copy copy", "Ball copy copy 2"), ("Ball copy copy 2", "Ball copy copy")])
func liveDuplicateNamesTheCopyAsTheFakeDoes(_ name: String, _ expected: String) throws {
    var live = CommandEngine(document: bounce(ballNamed: name)), fake = live
    let liveAdded = try shapes.duplicate(layers: ["ball"], owner: scene, in: &live)
    let fakeAdded = try FakeShapes().duplicate(layers: ["ball"], owner: scene, in: &fake)
    let liveName = layers(live).first { liveAdded.contains($0.id) }?.name
    let fakeName = layers(fake).first { fakeAdded.contains($0.id) }?.name
    #expect(liveName == expected && fakeName == expected)
}
