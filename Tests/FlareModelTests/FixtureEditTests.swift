// FixtureEditTests.swift: FixtureEdit's exact undo, its absence from the
// registry, and that every contract struct builds with a plain `import FlareModel`.
import FlareCore
import FlareModel
import Testing

private let ball = Layer(id: "ball", name: "Ball", shapes: [FlareShape(points: [
    Point(x: 0, y: 0), Point(x: 10, y: 0), Point(x: 10, y: 10),
])], tracks: ["x": [Keyframe(frame: 0, value: 5)]])
private let fixture = Document(scenes: [FlareScene(id: "scene-1", name: "Scene 1", layers: [ball])])

@Test func fixtureEditUndoRestoresTheDocumentExactly() throws {
    var engine = CommandEngine(document: fixture)
    let edit = FixtureEdit("Rename Scene", from: engine.document) { $0.scenes[0].name = "Intro" }
    try engine.perform(edit)
    #expect(engine.document.scenes.map(\.name) == ["Intro"] && engine.undoActionName == "Undo Rename Scene")
    try engine.undo()
    #expect(engine.document == fixture)
    try engine.redo()
    #expect(engine.document == edit.edited)
}

@Test func fixtureEditThatBreaksTheDocumentChangesNothing() {
    var engine = CommandEngine(document: fixture)
    #expect(throws: CommandError.self) {
        try engine.perform(FixtureEdit("Set Timing", from: fixture) { $0.scenes[0].fps = 0 })
    }
    #expect(engine.document == fixture && !engine.canUndo)
    var doc = fixture
    #expect(throws: CommandError.notExecuted) { try FixtureEdit("Edit", edited: fixture).undo(&doc) }
}

@Test func fixtureEditIsNeverRegisteredAndShiftOptionIsThree() {
    #expect(!CommandRegistry.builtIn.contains(FixtureEdit.id))
    #expect(DragModifiers([.shift, .option]).rawValue == 3)
}

@Test func everyContractStructBuildsFromOutsideTheModule() {
    let address = StageAddress(owner: .scene("scene-1"), layerID: "ball", item: .shape(0))
    let item = StageItem(address: address, path: FlarePath(), fill: .solid(FlareColor.black),
                         stroke: Stroke(), transform: .identity, opacity: 1)
    let list = StageDrawList(width: 550, height: 400, background: .white, items: [item])
    #expect(address.instancePath.isEmpty && !item.isText && list.hiddenTextCount == 0)
    #expect(CanvasPreset.all.map(\.name) == ["1080p 16:9", "Square", "Vertical 9:16", "Web 550 × 400"])
    #expect(CanvasPreset(name: "Tiny", width: 10, height: 10, fps: 12, durationFrames: 1).fps == 12)
    let draft = ShapeDraft(tool: .rectangle, shape: ball.shapes[0])
    #expect(draft.anchors.isEmpty && !draft.isClosed && BoxGesture.move(dx: 1, dy: 2) != .rotate(degrees: 90))
    let property = AnimatedProperty(name: "x", title: "X", value: nil, range: -1000...1000,
                                    unit: "pt", decimals: 1, keyState: .notAnimated)
    #expect(property.value == nil && KeyRef(layerID: "ball", property: nil, frame: 24).property == nil)
    let row = TimelineRow(layerID: "ball", name: "Ball", isVisible: true, isLocked: false,
                          keyFrames: [0, 24], segments: [0...24], easedSegments: [0: .easeOut])
    #expect(row.easedSegments[0] == .easeOut)
    let onion = OnionSettings()
    #expect(!onion.isOn && onion.before == 2 && onion.after == 2 && onion.falloff == 0.5)
    #expect(Ghost(frame: 22, side: .before, opacity: 0.5, items: [item]).items == [item])
}
