// LibraryFakesTests.swift: the LM-0c1 fake library on `character` and editing a symbol in place
// (docs/blueprints/flare.md, 7.1). The acceptance test: converting Legs leaves the fake draw list equal; usage is 3
// after two places; entering a symbol makes the owner `.symbol` and the timeline the symbol's length; exiting
// returns to the frame left.
import FlareCore
@testable import FlareModel
import Testing

private let services = FlareServices.fake()
private let character = FlareFixtures.character
private let scene = LayerOwner.scene("scene-1")

/// The draw list's items without their addresses: what the stage paints.
private func painted(_ document: Document, frame: Int = 6) -> [StageItem] {
    services.stage.drawList(document, sceneID: "scene-1", frame: frame, editing: nil).items.map {
        var item = $0
        item.address = StageAddress(owner: scene, layerID: "", item: .shape(0))
        return item
    }
}

private func usage(_ document: Document, _ id: String) -> Int? {
    services.library.symbols(document).first { $0.id == id }?.usage
}

private func characterWorkspace() -> FlareWorkspace {
    var w = FlareWorkspace(services: services)
    w.load(character)
    return w
}

@Test func characterHasFourPartsAndAnAnimatedWave() throws {
    try FlareFormat.validate(character)
    #expect(FlareFixtures.named("character") == character)
    let layers = try #require(character.scenes.first?.layers)
    #expect(layers.map(\.name) == ["Legs", "Body", "Arms", "Head"])
    #expect(layers[2].instances.map(\.symbolID) == ["wave"] && layers[0].shapes.count == 2)
    #expect(services.library.symbols(character) == [SymbolSummary(id: "wave", name: "Wave", durationFrames: 24, usage: 1)])
    // Wave is animated: the arm sits differently at frames 0 and 6.
    #expect(painted(character, frame: 0) != painted(character, frame: 6))
}

@Test func convertLegsKeepsTheDrawListAndPlacingTwiceMakesUsage3() throws {
    for frame in [0, 6, 47] {
        var e = CommandEngine(document: character)
        let id = try services.library.convertToSymbol(["legs"], sceneID: "scene-1", name: "Legs", in: &e)
        #expect(painted(e.document, frame: frame) == painted(character, frame: frame))
        #expect(id == "symbol-1" && usage(e.document, id) == 1 && e.undoActionName == "Undo Convert to Symbol")
    }
    var e = CommandEngine(document: character)
    let id = try services.library.convertToSymbol(["legs"], sceneID: "scene-1", name: "Legs", in: &e)
    let first = try services.library.placeInstance(of: id, at: Point(x: 100, y: 50), owner: scene, layerID: "legs", in: &e)
    let second = try services.library.placeInstance(of: id, at: Point(x: 400, y: 50), owner: scene, layerID: "body", in: &e)
    #expect(usage(e.document, id) == 3 && e.undoActionName == "Undo Place Symbol")
    #expect(first == StageAddress(owner: scene, layerID: "legs", item: .instance(1)))
    #expect(second == StageAddress(owner: scene, layerID: "body", item: .instance(0)))
    #expect(e.document.scenes.first?.layers.first { $0.id == "body" }?.instances.first?.transform == Transform(x: 400, y: 50))
    while e.canUndo { try e.undo() }
    #expect(e.document == character)
}

@Test func usageCountsNestedInstancesAndPlaceRefusesCyclesLocksAndUnknownSymbols() throws {
    var e = CommandEngine(document: character)
    let legs = try services.library.convertToSymbol(["legs"], sceneID: "scene-1", name: "Legs", in: &e)
    _ = try services.library.placeInstance(of: "wave", at: Point(x: 0, y: 0), owner: .symbol(legs), layerID: "legs", in: &e)
    #expect(usage(e.document, "wave") == 2)
    var locked = e.document
    locked.scenes[0].layers[1].isLocked = true
    e = CommandEngine(document: locked)
    let origin = Point(x: 0, y: 0)
    // Legs inside itself is a cycle; a locked layer and an unknown symbol are refused too.
    #expect(throws: CommandError.self) { try services.library.placeInstance(of: legs, at: origin, owner: .symbol(legs), layerID: "legs", in: &e) }
    #expect(throws: CommandError.layerLocked("body")) { try services.library.placeInstance(of: "wave", at: origin, owner: scene, layerID: "body", in: &e) }
    #expect(throws: CommandError.symbolNotFound("nope")) { try services.library.placeInstance(of: "nope", at: origin, owner: scene, layerID: "head", in: &e) }
    #expect(e.document == locked && !e.canUndo)
}

@Test func instanceTransformCoalescesAndPlaybackRenameRemoveAndSwatchesAreOneStepEach() throws {
    var e = CommandEngine(document: character)
    let arms = StageAddress(owner: scene, layerID: "arms", item: .instance(0))
    for x in 1...20 {
        try services.library.setInstanceTransform(Transform(x: Double(x)), at: arms, coalesceKey: "drag", in: &e)
    }
    try services.library.setInstancePlayback(.playOnce, firstFrame: 4, at: arms, in: &e)
    let instance = e.document.scenes.first?.layers.first { $0.id == "arms" }?.instances.first
    #expect(instance?.transform == Transform(x: 20) && instance?.loop == .playOnce && instance?.firstFrame == 4)
    #expect(throws: CommandError.invalidFrame(-1)) { try services.library.setInstancePlayback(.loop, firstFrame: -1, at: arms, in: &e) }
    try services.library.renameSymbol("wave", to: "Hello", in: &e)
    #expect(services.library.symbols(e.document).map(\.name) == ["Hello"] && e.undoActionName == "Undo Rename Symbol")
    #expect(throws: CommandError.symbolInUse("wave")) { try services.library.removeSymbol("wave", in: &e) }
    let red = Swatch(name: "Red", color: FlareColor(r: 1, g: 0, b: 0))
    try services.library.addSwatch(red, in: &e)
    #expect(services.library.swatches(e.document) == [red])
    try services.library.removeSwatch("Red", in: &e)
    #expect(services.library.swatches(e.document).isEmpty)
    var steps = 0
    while e.canUndo { try e.undo(); steps += 1 }
    #expect(steps == 5 && e.document == character)
    let off = FakeLibrary(unavailable: "off")
    #expect(off.symbols(character).isEmpty && off.swatches(character).isEmpty)
    #expect(throws: NotBuilt(reason: "off")) { try off.convertToSymbol(["legs"], sceneID: "scene-1", name: "Legs", in: &e) }
}

@Test func enterSymbolSwitchesOwnerAndTimelineAndExitReturnsToTheFrameLeft() {
    var w = characterWorkspace()
    w.currentFrame = 30
    w.selection = [StageAddress(owner: scene, layerID: "legs", item: .shape(0))]
    let id = w.convertToSymbol(named: "Legs")
    #expect(id == "symbol-1" && w.undoActionName == "Undo Convert to Symbol" && w.timelineFrames == 48)
    w.placeSymbol("symbol-1", at: Point(x: 10, y: 10))
    w.placeSymbol("symbol-1", at: Point(x: 20, y: 10))
    #expect(w.librarySymbols.first { $0.id == "symbol-1" }?.usage == 3)
    #expect(w.removeSymbolHelp("symbol-1") == "Legs is used 3 times." && w.removeSymbolHelp("missing") == nil)
    w.editSymbol("wave")
    #expect(w.editingSymbolID == "wave" && w.propertyOwner == .symbol("wave"))
    #expect(w.timelineFrames == 24 && w.currentFrame == 0 && w.breadcrumb == ["Scene 1", "Wave"])
    w.exitSymbol()
    #expect(w.editingSymbolID == nil && w.propertyOwner == scene && w.currentFrame == 30 && w.timelineFrames == 48)
    #expect(w.breadcrumb == ["Scene 1"])
}

@Test func returnOnAnInstanceEditsItsSymbol() {
    var w = characterWorkspace()
    w.currentFrame = 12
    w.editSelectedInstance()
    #expect(w.editingSymbolID == nil && w.layerError == .refused(FlareWorkspace.noInstanceMessage))
    w.selection = [StageAddress(owner: scene, layerID: "arms", item: .instance(0))]
    w.editSelectedInstance()
    #expect(w.editingSymbolID == "wave" && w.selection.isEmpty && w.currentFrame == 0)
    w.editSymbol("missing")
    #expect(w.editingSymbolID == "wave")
    w.exitSymbol()
    #expect(w.currentFrame == 12)
}

@Test func convertAndPlaceRefuseWithAReason() {
    var w = characterWorkspace()
    #expect(w.convertToSymbol(named: "Nothing") == nil && w.layerError == .refused(FlareWorkspace.convertNeedsArtMessage))
    w.placeSymbol("wave", at: Point(x: 0, y: 0))
    #expect(w.layerError == .refused(FlareWorkspace.placeNeedsLayerMessage))
    w.editSymbol("wave")
    w.selection = [StageAddress(owner: .symbol("wave"), layerID: "hand", item: .shape(0))]
    #expect(w.convertToSymbol(named: "Inner") == nil && w.layerError == .refused(FlareWorkspace.convertInSymbolMessage))
    #expect(w.document == character && !w.canUndo)
}
