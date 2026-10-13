// FixtureEditAdversarialTests.swift: FixtureEdit inside groups, coalescing,
// a zero-depth engine and a Codable round trip; the registry refusing it; and
// that every CanvasPreset makes a scene the engine accepts.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FlareCore
import FlareModel
import Testing

private let ball = Layer(id: "ball", name: "Ball", shapes: [FlareShape(points: [
    Point(x: 0, y: 0), Point(x: 10, y: 0), Point(x: 10, y: 10),
])], tracks: ["x": [Keyframe(frame: 0, value: 5)]])
private let fixture = Document(scenes: [FlareScene(id: "scene-1", name: "Scene 1", layers: [ball])])

@Test func fixtureEditsInOneGroupUndoTogetherToTheFixture() throws {
    var engine = CommandEngine(document: fixture)
    try engine.group("Retime") { e in
        try e.perform(FixtureEdit("Rename", from: e.document) { $0.scenes[0].name = "Intro" })
        try e.perform(RenameLayer(owner: .scene("scene-1"), layerID: "ball", name: "Red Ball"))
        try e.perform(FixtureEdit("Slow", from: e.document) { $0.scenes[0].fps = 12 })
    }
    #expect(engine.document.scenes[0].name == "Intro" && engine.document.scenes[0].fps == 12)
    #expect(engine.document.scenes[0].layers[0].name == "Red Ball" && engine.undoActionName == "Undo Retime")
    try engine.undo()
    #expect(engine.document == fixture)
    try engine.redo()
    #expect(engine.document.scenes[0].layers[0].name == "Red Ball" && engine.document.scenes[0].fps == 12)
}

@Test func aFailingFixtureEditRollsBackItsWholeGroup() {
    var engine = CommandEngine(document: fixture)
    #expect(throws: CommandError.self) {
        try engine.group("Retime") { e in
            try e.perform(FixtureEdit("Rename", from: e.document) { $0.scenes[0].name = "Intro" })
            try e.perform(FixtureEdit("Break", from: e.document) { $0.scenes[0].width = .nan })
        }
    }
    #expect(engine.document == fixture && !engine.canUndo)
}

@Test func coalescedFixtureEditsUndoInOneStepToTheFirstOriginal() throws {
    var engine = CommandEngine(document: fixture)
    for step in 1...20 {
        let edit = FixtureEdit("Set X", from: engine.document) {
            $0.scenes[0].layers[0].tracks["x"] = [Keyframe(frame: 0, value: Double(step))]
        }
        try engine.perform(edit, coalesceKey: "drag-x")
    }
    #expect(engine.document.scenes[0].layers[0].tracks["x"]?.first?.value == 20)
    try engine.undo()
    #expect(engine.document == fixture && !engine.canUndo)
    try engine.redo()
    #expect(engine.document.scenes[0].layers[0].tracks["x"]?.first?.value == 20)
}

@Test func aFixtureEditIsAWholeDocumentSnapshot() throws {
    // Built before another edit, it replaces that edit too; undo brings it back.
    var engine = CommandEngine(document: fixture)
    let stale = FixtureEdit("Rename Scene", from: fixture) { $0.scenes[0].name = "Intro" }
    try engine.perform(RenameLayer(owner: .scene("scene-1"), layerID: "ball", name: "Red Ball"))
    try engine.perform(stale)
    #expect(engine.document == stale.edited && engine.document.scenes[0].layers[0].name == "Ball")
    try engine.undo()
    #expect(engine.document.scenes[0].layers[0].name == "Red Ball")
}

@Test func aFixtureEditOnAZeroDepthEngineChangesTheDocumentWithoutHistory() throws {
    var engine = CommandEngine(document: fixture, maxUndoDepth: 0)
    let edit = FixtureEdit("Rename Scene", from: fixture) { $0.scenes[0].name = "Intro" }
    try engine.perform(edit)
    #expect(engine.document == edit.edited && !engine.canUndo)
    #expect(throws: CommandError.nothingToUndo) { try engine.undo() }
}

@Test func aDecodedFixtureEditIsFreshAndTheRegistryRefusesIt() throws {
    var executed = FixtureEdit("Rename Scene", from: fixture) { $0.scenes[0].name = "Intro" }
    var doc = fixture
    try executed.execute(&doc)
    let decoded = try JSONDecoder().decode(FixtureEdit.self, from: JSONEncoder().encode(executed))
    #expect(decoded.label == "Rename Scene" && decoded.edited == executed.edited)
    #expect(throws: CommandError.notExecuted) { try decoded.undo(&doc) }
    #expect(throws: CommandError.unknownCommand(FixtureEdit.id)) { try CommandRegistry.builtIn.encode(executed) }
    let envelope = Data(#"{"id":"fixture.edit","params":{"label":"x","edited":{}}}"#.utf8)
    #expect(throws: CommandError.unknownCommand(FixtureEdit.id)) { try CommandRegistry.builtIn.decode(envelope) }
}

@Test func aThrowingEditMakesNoCommand() {
    struct Refused: Error {}
    #expect(throws: Refused.self) {
        _ = try FixtureEdit("Nope", from: fixture) { _ in throw Refused() }
    }
}

@Test func dragModifiersAreIndependentBits() {
    let none: DragModifiers = []
    #expect(none.rawValue == 0 && DragModifiers.shift.rawValue == 1 && DragModifiers.option.rawValue == 2)
    var both: DragModifiers = [.shift, .option]
    both.remove(.shift)
    #expect(both == .option && !both.contains(.shift))
    #expect(DragModifiers(rawValue: 3) == [.option, .shift])
}

@Test func everyCanvasPresetMakesASceneTheEngineAccepts() throws {
    #expect(Set(CanvasPreset.all.map(\.name)).count == CanvasPreset.all.count)
    for preset in CanvasPreset.all {
        let scene = FlareScene(id: "s", name: preset.name, fps: preset.fps, durationFrames: preset.durationFrames,
                               width: preset.width, height: preset.height)
        try FlareFormat.validate(Document(scenes: [scene]))
        var engine = CommandEngine(document: fixture)
        try engine.perform(FixtureEdit("New Scene", from: fixture) { $0.scenes.append(scene) })
        #expect(engine.document.scenes.count == 2)
    }
}

@Test func contractValuesCompareByEveryField() {
    let a = StageAddress(owner: .scene("scene-1"), layerID: "ball", item: .shape(0))
    #expect(a != StageAddress(owner: .scene("scene-1"), layerID: "ball", item: .shape(0), instancePath: [0]))
    #expect(a != StageAddress(owner: .scene("scene-1"), layerID: "ball", item: .text(0)))
    #expect(Set([KeyRef(layerID: "ball", property: nil, frame: 0),
                 KeyRef(layerID: "ball", property: "x", frame: 0)]).count == 2)
    #expect(OnionSettings() != OnionSettings(isOn: true))
}
