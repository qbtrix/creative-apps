// LiveKeysJourneyTests.swift: KY-9, the live-keys model journey (docs/blueprints/flare/features/live-keys.md,
// "Journey steps" 1-7). Each test walks its steps on a real `CommandEngine` over `FlareFixtures`, through the live types
// seen only as their protocols: `LiveProperties` as `PropertyAnimating`, `LiveKeyframes` as `KeyframeEditing` and
// `LiveEasing` as `KeyframeEasing`. Every value and undo name is the packet's.
import FlareCore
import FlareModel
import Testing

private let scene = LayerOwner.scene("scene-1")
private let wave = LayerOwner.symbol("wave")
private let red = Fill.solid(FlareColor(r: 1, g: 59.0 / 255, b: 48.0 / 255))   // FF3B30

private func layer(_ id: String, of owner: LayerOwner = scene, in engine: CommandEngine) -> Layer? {
    engine.document.layers(of: owner)?.first { $0.id == id }
}

private func row(_ name: String, _ ids: [String], at frame: Int, of props: any PropertyAnimating,
                 in engine: CommandEngine) -> AnimatedProperty? {
    props.properties(engine.document, owner: scene, layerIDs: ids, frame: frame).first { $0.name == name }
}

struct LiveKeysJourneyTests {
    /// Steps 1 and 2 (J6): the key states at the playhead, Mixed with no marker, and a still row's edit.
    @Test func testMoveAndKey() throws {
        let props: any PropertyAnimating = LiveProperties()
        var engine = CommandEngine(document: FlareFixtures.bounce)
        // 1. Ball X animated, Shadow X not, both together Mixed with no marker.
        #expect(layer("ball", in: engine)?.tracks["x"]?.map(\.frame) == [0, 12, 24, 36, 47])
        #expect(row("x", ["ball"], at: 30, of: props, in: engine)?.keyState == .animated)
        #expect(row("x", ["shadow"], at: 30, of: props, in: engine)?.keyState == .notAnimated)
        let mixed = row("x", ["ball", "shadow"], at: 30, of: props, in: engine)
        #expect(mixed != nil && mixed?.value == nil && mixed?.keyState == .notAnimated)
        // 2. Shadow X at 30, auto-key off: its one key lands at 0 and the row stays still.
        #expect(layer("shadow", in: engine)?.tracks["x"] == nil)
        try props.setValue(200, of: "x", owner: scene, layerIDs: ["shadow"], frame: 30, autoKey: false,
                           coalesceKey: nil, in: &engine)
        #expect(layer("shadow", in: engine)?.tracks["x"] == [Keyframe(frame: 0, value: 200)])
        #expect(row("x", ["shadow"], at: 30, of: props, in: engine)?.keyState == .notAnimated)
        #expect(row("x", ["shadow"], at: 0, of: props, in: engine)?.value == 200)
        #expect(row("x", ["shadow"], at: 30, of: props, in: engine)?.value == 200)
        #expect(engine.undoActionName == "Undo Set Keyframe")
        try engine.undo()
        #expect(engine.document == FlareFixtures.bounce && !engine.canUndo)
    }

    /// Steps 3 and 4 (J7): the stopwatch keys 0 and the last frame; a 120-step scrub is one undo entry.
    @Test func testInspectorKeysTransform() throws {
        let props: any PropertyAnimating = LiveProperties()
        var engine = CommandEngine(document: FlareFixtures.bounce)
        // 3. The stopwatch on Shadow X at 0.
        try props.toggleAnimated("x", owner: scene, layerID: "shadow", frame: 0, lastFrame: 47, in: &engine)
        #expect(layer("shadow", in: engine)?.tracks["x"]?.map(\.frame) == [0, 47])
        #expect(row("x", ["shadow"], at: 30, of: props, in: engine)?.keyState == .animated)
        #expect(row("x", ["shadow"], at: 0, of: props, in: engine)?.keyState == .keyedHere)
        #expect(engine.undoActionName == "Undo Animate X")
        // 4. 120 scrub steps on Ball rotation under one coalesce key: one undo restores Ball.
        let keyed = engine.document
        for step in 1...120 {
            try props.setValue(Double(step) * 3, of: "rotation", owner: scene, layerIDs: ["ball"], frame: 12,
                               autoKey: false, coalesceKey: "scrub-rotation", in: &engine)
        }
        #expect(layer("ball", in: engine)?.tracks["rotation"] == [Keyframe(frame: 0, value: 360)])
        try engine.undo()
        #expect(engine.document == keyed)
        #expect(layer("ball", in: engine) == layer("ball", in: CommandEngine(document: FlareFixtures.bounce)))
        #expect(engine.undoActionName == "Undo Animate X")
        try engine.undo()
        #expect(engine.document == FlareFixtures.bounce && !engine.canUndo)
    }

    /// Step 5 (J8): Ball's fill, then stroke width, cap and join, each its own entry; one undo restores only the join.
    @Test func testFillAndStroke() throws {
        let props: any PropertyAnimating = LiveProperties()
        var engine = CommandEngine(document: FlareFixtures.bounce)
        let count = layer("ball", in: engine)?.shapes.count ?? 0
        let items = (0..<count).map { StageAddress(owner: scene, layerID: "ball", item: .shape($0)) }
        #expect(!items.isEmpty)
        try props.setFill(red, of: items, in: &engine)
        #expect(engine.undoActionName == "Undo Set Fill")
        let capped = Stroke(width: 4, cap: .round), joined = Stroke(width: 4, join: .round, cap: .round)
        try props.setStroke(Stroke(width: 4), of: items, in: &engine)
        try props.setStroke(capped, of: items, in: &engine)
        try props.setStroke(joined, of: items, in: &engine)
        #expect(layer("ball", in: engine)?.shapes.allSatisfy { $0.fill == red && $0.stroke == joined } == true)
        #expect(engine.undoActionName == "Undo Set Stroke")
        try engine.undo()
        #expect(layer("ball", in: engine)?.shapes.allSatisfy { $0.fill == red && $0.stroke == capped } == true)
        for _ in 0..<3 { try engine.undo() }
        #expect(engine.document == FlareFixtures.bounce && !engine.canUndo)
    }

    /// Step 6 (J11): move, a refused collision, delete, insert, remove and a label, each one named entry.
    @Test func testRetimeDeleteInsertAndLabel() throws {
        let keys: any KeyframeEditing = LiveKeyframes()
        var engine = CommandEngine(document: FlareFixtures.bounce)
        func ball() -> [Int] { keys.rows(engine.document, owner: scene).first { $0.layerID == "ball" }?.keyFrames ?? [] }
        let every = keys.rows(engine.document, owner: scene).map(\.layerID)
        try keys.moveKeys([KeyRef(layerID: "ball", property: nil, frame: 24)], by: 4, owner: scene, coalesceKey: nil, in: &engine)
        #expect(ball() == [0, 12, 28, 36, 47])
        #expect(engine.undoActionName == "Undo Move Keyframe")
        let moved = engine.document
        #expect(throws: (any Error).self) {
            try keys.moveKeys([KeyRef(layerID: "ball", property: nil, frame: 28)], by: 8, owner: scene, coalesceKey: nil, in: &engine)
        }
        #expect(engine.document == moved && engine.undoActionName == "Undo Move Keyframe")
        try keys.removeKeys([KeyRef(layerID: "ball", property: nil, frame: 12)], owner: scene, in: &engine)
        #expect(ball() == [0, 28, 36, 47])
        #expect(engine.undoActionName == "Undo Delete Keyframe")
        try keys.insertFrames(2, at: 10, layerIDs: every, owner: scene, in: &engine)
        #expect(ball() == [0, 30, 38, 49])
        #expect(engine.undoActionName == "Undo Insert Frame")
        try keys.removeFrames(1, at: 10, layerIDs: every, owner: scene, in: &engine)
        #expect(ball() == [0, 29, 37, 48])
        #expect(engine.undoActionName == "Undo Remove Frame")
        try keys.setLabel("hit", at: 29, sceneID: "scene-1", in: &engine)
        #expect(keys.labels(engine.document, sceneID: "scene-1") == ["hit": 29])
        #expect(engine.undoActionName == "Undo Set Frame Label")
        for _ in 0..<5 { try engine.undo() }
        #expect(engine.document == FlareFixtures.bounce && !engine.canUndo)
    }

    /// Step 7 (J12): inside "wave", the hand's rotation key moves and undoes exactly, and Ease Out lands on its first
    /// segment through `LiveEasing`'s owner path.
    @Test func testEasingInsideASymbol() throws {
        let keys: any KeyframeEditing = LiveKeyframes()
        let easing: any KeyframeEasing = LiveEasing()
        var engine = CommandEngine(document: FlareFixtures.character)
        func hand() -> [Keyframe] { layer("hand", of: wave, in: engine)?.tracks["rotation"] ?? [] }
        #expect(hand().map(\.frame) == [0, 12, 23])
        try keys.moveKeys([KeyRef(layerID: "hand", property: "rotation", frame: 23)], by: 7, owner: wave,
                          coalesceKey: nil, in: &engine)
        #expect(hand().map(\.frame) == [0, 12, 30])
        #expect(engine.document.scenes == FlareFixtures.character.scenes)
        #expect(engine.undoActionName == "Undo Move Keyframe")
        try engine.undo()
        #expect(engine.document == FlareFixtures.character && !engine.canUndo)
        try easing.setEasing(.easeOut, at: KeyRef(layerID: "hand", property: "rotation", frame: 0), owner: wave,
                             coalesceKey: nil, in: &engine)
        #expect(hand().first?.easing == .easeOut && hand().dropFirst().allSatisfy { $0.easing == .linear })
        #expect(engine.undoActionName == "Undo Set Keyframe Easing")
        try engine.undo()
        #expect(engine.document == FlareFixtures.character && !engine.canUndo)
    }
}
