// LiveScenesGuidesTests.swift: SN-4's acceptance (docs/blueprints/flare/features/live-scenes.md): a guide drag
// with one coalesce key is one "Move Guide" entry that one undo puts back, a new key is a new entry, `MoveGuide`s
// on one guide merge and on another do not, a bad index throws and changes nothing, add and remove undo exactly,
// and a drag step stays inside its budget (QB-L7).
import FlareCore
import FlareModel
import Testing

private let live = LiveScenes()
private let scene = "scene-1"

/// `bounce` with one horizontal guide at y 300, and that guide's index.
private func oneGuide() throws -> (engine: CommandEngine, index: Int) {
    var engine = CommandEngine(document: FlareFixtures.bounce)
    let index = try live.addGuide(.horizontal, at: 300, sceneID: scene, in: &engine)
    return (engine, index)
}

private func position(_ index: Int, _ engine: CommandEngine) -> Double? {
    let guides = engine.document.scenes.first { $0.id == scene }?.guides ?? []
    return guides.indices.contains(index) ? guides[index].position : nil
}

@Test func dragIsOneEntry() throws {
    var (engine, index) = try oneGuide()
    #expect(index == 0 && position(index, engine) == 300)
    let added = engine.document
    for step in 1...20 {
        try live.moveGuide(at: index, to: 300 + Double(step), sceneID: scene, coalesceKey: "drag-1", in: &engine)
    }
    #expect(position(index, engine) == 320 && engine.undoActionName == "Undo Move Guide")
    try engine.undo()
    #expect(engine.document == added && engine.undoActionName == "Undo Add Guide")

    // The steps merge on one guide only.
    var a = MoveGuide(sceneID: scene, index: 0, position: 310)
    let sameGuide = a.merge(MoveGuide(sceneID: scene, index: 0, position: 320))
    let otherGuide = a.merge(MoveGuide(sceneID: scene, index: 1, position: 330))
    #expect(sameGuide && !otherGuide && a.position == 320)

    // A drag with a new key is a second entry.
    try engine.redo()
    #expect(position(index, engine) == 320)
    try live.moveGuide(at: index, to: 340, sceneID: scene, coalesceKey: "drag-2", in: &engine)
    try engine.undo()
    #expect(position(index, engine) == 320 && engine.undoActionName == "Undo Move Guide")
    try engine.undo()
    #expect(engine.document == added)
}

@Test func aBadIndexThrowsAndChangesNothing() throws {
    var (engine, _) = try oneGuide()
    let start = engine.document
    #expect(throws: CommandError.invalidIndex(5)) { try live.removeGuide(at: 5, sceneID: scene, in: &engine) }
    #expect(throws: CommandError.invalidIndex(5)) {
        try live.moveGuide(at: 5, to: 10, sceneID: scene, coalesceKey: nil, in: &engine)
    }
    #expect(engine.document == start && engine.undoActionName == "Undo Add Guide")
}

@Test func addAndRemoveUndoExactly() throws {
    let before = FlareFixtures.bounce
    var (engine, index) = try oneGuide()
    let added = engine.document
    try live.removeGuide(at: index, sceneID: scene, in: &engine)
    #expect(engine.document == before && engine.undoActionName == "Undo Remove Guide")
    try engine.undo()
    #expect(engine.document == added)
    try engine.undo()
    #expect(engine.document == before)
}

@Test func dragStepWithinBudget() throws {
    var (engine, index) = try oneGuide()
    let clock = ContinuousClock()
    var times: [Duration] = []
    for step in 1...50 {
        let time = try clock.measure {
            try live.moveGuide(at: index, to: 300 + Double(step), sceneID: scene, coalesceKey: "drag", in: &engine)
        }
        times.append(time)
    }
    times.sort()
    let budget = Duration.milliseconds(10)
    let median = times[times.count / 2]
    let p95 = times[times.count * 95 / 100]
    let max = times[times.count - 1]
    print("LiveScenesGuideDrag p50 \(median) p95 \(p95) max \(max) budget \(budget)")
    #expect(median <= budget)
    #expect(position(index, engine) == 350)
}
