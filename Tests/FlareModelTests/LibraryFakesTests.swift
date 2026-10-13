// LibraryFakesTests.swift: LM-0c1 (docs/blueprints/flare.md, 7.1): convert Legs and the fake draw list is equal before
// and after; usage 3 after two places; entering a symbol makes the owner `.symbol` and the timeline the symbol's
// length; exiting returns to the frame left. LM-0c1 has no quality-bar row beyond that, so no budget test here.
import FlareCore
@testable import FlareModel
import Testing

private let services = FlareServices.fake()
private let character = FlareFixtures.character
private let scene = LayerOwner.scene("scene-1")

/// The items as painted: addresses change when art moves into an instance, so they are blanked.
private func painted(_ list: StageDrawList) -> [StageItem] {
    list.items.map { var item = $0; item.address = StageAddress(owner: scene, layerID: "", item: .shape(0)); return item }
}
private func undoEntries(_ engine: CommandEngine) throws -> Int {
    var copy = engine, n = 0
    while copy.canUndo { try copy.undo(); n += 1 }
    return n
}
private func workspace(frame: Int) -> FlareWorkspace {
    var w = FlareWorkspace(services: services)
    w.load(character)
    w.currentFrame = frame
    return w
}

@Test func characterIsNamedValidAndHasEachPartOnItsOwnLayer() throws {
    #expect(FlareFixtures.named("character") == character && character.scenes.first?.layers.map(\.name) == ["Legs", "Body", "Arms", "Head"])
    #expect(services.library.symbols(character) == [SymbolSummary(id: "wave", name: "Wave", durationFrames: 12, usage: 1)])
}

@Test(arguments: [0, 7, 30, 47])
func convertingLegsKeepsTheDrawListAndIsOneStep(_ frame: Int) throws {
    var e = CommandEngine(document: character)
    let before = services.stage.drawList(e.document, sceneID: "scene-1", frame: frame, editing: nil)
    let id = try services.library.convertToSymbol(["legs"], sceneID: "scene-1", name: " Legs ", in: &e)
    let after = services.stage.drawList(e.document, sceneID: "scene-1", frame: frame, editing: nil)
    #expect(painted(after) == painted(before) && after.items.count == 5)
    #expect(services.library.symbols(e.document).last == SymbolSummary(id: id, name: "Legs", durationFrames: 48, usage: 1))
    #expect(try undoEntries(e) == 1 && e.undoActionName == "Undo Convert to Symbol")
    try e.undo()
    #expect(e.document == character)
}

@Test func usageIsThreeAfterTwoPlaces() throws {
    var e = CommandEngine(document: character)
    let id = try services.library.convertToSymbol(["legs"], sceneID: "scene-1", name: "Legs", in: &e)
    let first = try services.library.placeInstance(of: id, at: Point(x: 40, y: 50), owner: scene, layerID: "body", in: &e)
    let second = try services.library.placeInstance(of: id, at: Point(x: 90, y: 50), owner: scene, layerID: "body", in: &e)
    #expect(first.item == .instance(0) && second.item == .instance(1) && e.undoActionName == "Undo Place Symbol")
    #expect(services.library.symbols(e.document).first { $0.id == id }?.usage == 3)
    #expect(e.document.layers(of: scene)?[1].instances.last?.transform == Transform(x: 90, y: 50))
    #expect(throws: CommandError.symbolInUse(id)) { try services.library.removeSymbol(id, in: &e) }
}

@Test func placingRefusesALockedLayerAMissingSymbolAndASymbolInsideItself() throws {
    var locked = character
    locked.scenes[0].layers[1].isLocked = true
    var e = CommandEngine(document: locked)
    func place(_ id: String, _ owner: LayerOwner, _ layer: String) throws {
        _ = try services.library.placeInstance(of: id, at: Point(x: 0, y: 0), owner: owner, layerID: layer, in: &e)
    }
    #expect(throws: CommandError.layerLocked("body")) { try place("wave", scene, "body") }
    #expect(throws: CommandError.symbolNotFound("nope")) { try place("nope", scene, "head") }
    #expect(throws: CommandError.self) { try place("wave", .symbol("wave"), "wave-arm") }  // a cycle
    #expect(e.document == locked && !e.canUndo)
}

@Test func instanceRenameAndSwatchWritesAreOneStepEach() throws {
    var e = CommandEngine(document: character)
    let arms = StageAddress(owner: scene, layerID: "arms", item: .instance(0))
    #expect(throws: CommandError.self) { try services.library.setInstanceTransform(Transform(x: .nan), at: arms, coalesceKey: nil, in: &e) }
    for x in stride(from: 300.0, to: 340, by: 4) {
        try services.library.setInstanceTransform(Transform(x: x, y: 170), at: arms, coalesceKey: "drag", in: &e)
    }
    try services.library.setInstancePlayback(.playOnce, firstFrame: 4, at: arms, in: &e)
    let instance = try #require(e.document.layers(of: scene)?[2].instances.first)
    #expect(instance.transform.x == 336 && instance.loop == .playOnce && instance.firstFrame == 4)
    #expect(throws: CommandError.self) { try services.library.setInstancePlayback(.loop, firstFrame: -1, at: arms, in: &e) }
    try services.library.renameSymbol("wave", to: "Hello", in: &e)
    #expect(throws: CommandError.self) { try services.library.renameSymbol("wave", to: "  ", in: &e) }
    let swatch = Swatch(name: "Shirt", color: FlareColor(r: 0.2, g: 0.5, b: 0.85))
    try services.library.addSwatch(swatch, in: &e)
    #expect(services.library.swatches(e.document) == [swatch] && e.document.symbols.first?.name == "Hello")
    try services.library.removeSwatch("Shirt", in: &e)
    #expect(try undoEntries(e) == 5)
    let off = FakeLibrary(unavailable: "Not connected yet (IN-5).")
    #expect(off.symbols(character).isEmpty && off.swatches(character).isEmpty)
    #expect(throws: NotBuilt(reason: "Not connected yet (IN-5).")) { try off.removeSwatch("Shirt", in: &e) }
}

@Test func enteringASymbolSwitchesTheOwnerAndTimelineAndExitReturnsToTheFrameLeft() {
    var w = workspace(frame: 30)
    #expect(w.editingOwner == scene && w.timelineDurationFrames == 48 && w.symbolBreadcrumb.isEmpty)
    w.setSelection([StageAddress(owner: scene, layerID: "arms", item: .instance(0))])
    w.editSelectedInstance()
    #expect(w.editingOwner == .symbol("wave") && w.timelineDurationFrames == 12 && w.currentFrame == 0)
    #expect(w.symbolBreadcrumb == ["Scene 1", "Wave"] && w.selection.isEmpty)
    w.convertToSymbol(named: "Inside")
    #expect(w.layerError == .refused("Leave the symbol to convert scene art."))
    w.currentFrame = 9
    w.exitSymbol()
    w.exitSymbol()  // a second Escape does nothing
    #expect(w.editingOwner == scene && w.timelineDurationFrames == 48 && w.currentFrame == 30)
}

@Test func convertPlaceAndDeleteHelpThroughTheWorkspace() throws {
    var w = workspace(frame: 20)
    w.selectLayer("legs")
    w.convertToSymbol(named: "Legs")
    w.editSelectedInstance()
    #expect(w.editingSymbol?.name == "Legs")
    w.undo()  // the edited symbol is gone, so the workspace leaves it
    #expect(w.editingSymbolID == nil && w.editingOwner == scene && w.currentFrame == 20 && w.document == character)
    w.selectLayer("legs")
    w.convertToSymbol(named: "Legs")
    let id = try #require(w.librarySymbols.last?.id)
    #expect(w.selection == [StageAddress(owner: scene, layerID: "legs", item: .instance(0))])
    w.placeSymbol(id, at: Point(x: 10, y: 10))
    w.placeSymbol(id, at: Point(x: 20, y: 10))
    w.renameSymbol(id, to: "Leg pair")
    #expect(w.librarySymbols.last?.usage == 3 && w.undoActionName == "Undo Rename Symbol")
    #expect(w.symbolRemoveHelp(id) == "Leg pair is used 3 times." && w.symbolRemoveHelp("wave") == "Wave is used once.")
    w.removeSymbol(id)
    #expect(w.layerError == .refused("Leg pair is used 3 times.") && w.librarySymbols.count == 2)
}
