// LivePropertiesPaintTests.swift: KY-4, the live FILL and STROKE writes (docs/blueprints/flare/features/live-keys.md).
// Each write is one undo entry over every shape address passed, a direct-selected shape changes alone, a bad stroke
// throws and changes nothing, no shape is a no-op, and the live type is a `PropertyAnimating`.
import FlareCore
@testable import FlareModel
import Testing

private let scene = LayerOwner.scene("scene-1")
private let red = Fill.solid(FlareColor(r: 1, g: 59.0 / 255, b: 48.0 / 255))   // FF3B30

/// One `.shape` address per shape of `layerID`, as the workspace sends for a selected layer.
private func shapes(of layerID: String, owner: LayerOwner = scene, in document: Document) -> [StageAddress] {
    let count = document.layers(of: owner)?.first { $0.id == layerID }?.shapes.count ?? 0
    return (0..<count).map { StageAddress(owner: owner, layerID: layerID, item: .shape($0)) }
}

private func layer(_ id: String, owner: LayerOwner = scene, in engine: CommandEngine) -> Layer? {
    engine.document.layers(of: owner)?.first { $0.id == id }
}

@Test func fillOnBallSetsEveryShapeInOneEntry() throws {
    let doc = FlareFixtures.bounce
    var engine = CommandEngine(document: doc)
    let items = shapes(of: "ball", in: doc)
    #expect(!items.isEmpty)
    try LiveProperties().setFill(red, of: items, in: &engine)
    #expect(layer("ball", in: engine)?.shapes.allSatisfy { $0.fill == red } == true)
    #expect(engine.undoActionName == "Undo Set Fill")
    try engine.undo()
    #expect(engine.document == doc)
    #expect(!engine.canUndo)
}

@Test func eachStrokeEditIsOneEntryAndUndoRestoresOnlyTheLast() throws {
    let doc = FlareFixtures.bounce
    var engine = CommandEngine(document: doc)
    let live = LiveProperties(), items = shapes(of: "ball", in: doc)
    let wide = Stroke(width: 4), capped = Stroke(width: 4, cap: .round), joined = Stroke(width: 4, join: .round, cap: .round)
    try live.setStroke(wide, of: items, in: &engine)
    try live.setStroke(capped, of: items, in: &engine)
    try live.setStroke(joined, of: items, in: &engine)
    #expect(layer("ball", in: engine)?.shapes.allSatisfy { $0.stroke == joined } == true)
    #expect(engine.undoActionName == "Undo Set Stroke")
    try engine.undo()
    #expect(layer("ball", in: engine)?.shapes.allSatisfy { $0.stroke == capped } == true)
    try engine.undo()
    try engine.undo()
    #expect(engine.document == doc)
    #expect(!engine.canUndo)
}

@Test func aDirectSelectedItemsFillChangesOnlyThatShape() throws {
    let doc = FlareFixtures.character
    var engine = CommandEngine(document: doc)
    let before = layer("legs", in: engine)?.shapes ?? []
    #expect(before.count == 2)
    try LiveProperties().setFill(red, of: [StageAddress(owner: scene, layerID: "legs", item: .shape(1))], in: &engine)
    let after = layer("legs", in: engine)?.shapes ?? []
    #expect(after.first == before.first)
    #expect(after.last?.fill == red)
    #expect(engine.undoActionName == "Undo Set Fill")
}

@Test func aNegativeStrokeWidthThrowsAndChangesNothing() throws {
    let doc = FlareFixtures.bounce
    var engine = CommandEngine(document: doc)
    let live = LiveProperties()
    try live.setFill(red, of: shapes(of: "ball", in: doc), in: &engine)
    let filled = engine.document
    let refusal = CommandError.invalidDocument("Stroke width can't be negative.")
    #expect(throws: refusal) {
        try live.setStroke(Stroke(width: -1), of: shapes(of: "ball", in: doc), in: &engine)
    }
    #expect(FlareLayerError.command(refusal).message == "Stroke width can't be negative.")
    #expect(engine.document == filled)
    #expect(engine.canUndo)
    #expect(engine.undoActionName == "Undo Set Fill")
}

@Test func noShapeIsANoOpWithNoEntry() throws {
    let doc = FlareFixtures.character
    var engine = CommandEngine(document: doc)
    let live = LiveProperties()
    let instance = StageAddress(owner: scene, layerID: "arms", item: .instance(0))
    try live.setFill(red, of: [], in: &engine)
    try live.setStroke(Stroke(width: 4), of: [], in: &engine)
    try live.setFill(red, of: [instance], in: &engine)
    try live.setStroke(nil, of: [instance], in: &engine)
    #expect(engine.document == doc)
    #expect(!engine.canUndo)
}

@Test func liveIsAPropertyAnimating() {
    let animating: any PropertyAnimating = LiveProperties()
    #expect(animating is LiveProperties)
}

@Test func aSymbolLayersShapeFillSetsAndUndoesExactly() throws {
    let doc = FlareFixtures.character
    var engine = CommandEngine(document: doc)
    let wave = LayerOwner.symbol("wave")
    let items = shapes(of: "hand", owner: wave, in: doc)
    #expect(!items.isEmpty)
    try LiveProperties().setFill(red, of: items, in: &engine)
    #expect(layer("hand", owner: wave, in: engine)?.shapes.allSatisfy { $0.fill == red } == true)
    #expect(engine.document.scenes == doc.scenes)
    #expect(engine.undoActionName == "Undo Set Fill")
    try engine.undo()
    #expect(engine.document == doc)
    #expect(!engine.canUndo)
}

/// A non-finite width says the width needs a number, not that it is negative; a NaN color channel refuses with a
/// sentence the person sees as-is, before any command. Neither adds an undo entry.
@Test func aNonFiniteStrokeWidthOrColorThrowsASentenceAndAddsNoEntry() throws {
    let doc = FlareFixtures.bounce
    var engine = CommandEngine(document: doc)
    let live = LiveProperties(), items = shapes(of: "ball", in: doc)
    let width = CommandError.invalidDocument("Stroke width needs a number.")
    #expect(throws: width) { try live.setStroke(Stroke(width: .nan), of: items, in: &engine) }
    #expect(throws: width) { try live.setStroke(Stroke(width: .infinity), of: items, in: &engine) }
    #expect(FlareLayerError.command(width).message == "Stroke width needs a number.")
    let color = CommandError.invalidDocument("Each stroke color channel needs a number.")
    #expect(throws: color) {
        try live.setStroke(Stroke(color: FlareColor(r: .nan, g: 0, b: 0), width: 2), of: items, in: &engine)
    }
    #expect(FlareLayerError.command(color).message == "Each stroke color channel needs a number.")
    #expect(engine.document == doc)
    #expect(!engine.canUndo)
}

@Test func removingAStrokeIsNamedRemoveStroke() throws {
    let doc = FlareFixtures.bounce
    var engine = CommandEngine(document: doc)
    let live = LiveProperties(), items = shapes(of: "ball", in: doc)
    try live.setStroke(Stroke(width: 3), of: items, in: &engine)
    try live.setStroke(nil, of: items, in: &engine)
    #expect(layer("ball", in: engine)?.shapes.allSatisfy { $0.stroke == nil } == true)
    #expect(engine.undoActionName == "Undo Remove Stroke")
    try engine.undo()
    #expect(layer("ball", in: engine)?.shapes.allSatisfy { $0.stroke == Stroke(width: 3) } == true)
}
