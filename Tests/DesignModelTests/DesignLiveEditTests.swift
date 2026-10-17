// DesignLiveEditTests.swift: the live drag box's logic (DesignLiveEdit, design-window
// D0-8a): a drag's samples and a scrub's values change only the copy until the end,
// and the end leaves the workspace as the same calls made on it directly would, as
// one undo step, with the copy cleared. On `cards`, A is node-2 at (100, 100, 100 × 80).
// Runs on Linux and macOS.
import DesignModel
import Testing

/// `cards` on the fake services.
private func cards() -> DesignWorkspace {
    var workspace = DesignFixtures.cards
    workspace.useServices(.fake)
    return workspace
}

/// The i-th of 120 samples of a drag from A's middle, 1 pt right and half a point down each.
private func sample(_ i: Int) -> DesignPoint { pt(150 + Double(i), 140 + Double(i) / 2) }

@Test func aDragMovesOnlyTheCopyUntilItEnds() {
    var model = cards()
    var live = DesignLiveEdit()
    let start = sample(0)
    model.drag(from: start, to: start)
    live.begin(from: model)
    #expect(model.selectedNode?.id == "node-2")
    for i in 1...120 {
        live.sample(from: start, to: sample(i))
    }
    #expect(model.selectedNode?.frame == rc(100, 100, 100, 80))
    #expect(live.workspace?.selectedNode?.frame == rc(220, 160, 100, 80))

    live.end(into: &model)
    var direct = cards()
    for i in 0...120 { direct.drag(from: start, to: sample(i)) }
    direct.endDrag()
    #expect(model == direct)
    #expect(model.selectedNode?.frame == rc(220, 160, 100, 80))
    #expect(model.undoActionName == "Undo Move")
    model.undo()
    #expect(!model.canUndo)
    #expect(live.workspace == nil)
}

@Test func aPressWithNoSampleOnlyEnds() {
    var model = cards()
    var live = DesignLiveEdit()
    model.drag(from: sample(0), to: sample(0))
    live.begin(from: model)
    live.end(into: &model)
    #expect(model.selectedNode?.id == "node-2")
    #expect(model.selectedNode?.frame == rc(100, 100, 100, 80))
    #expect(!model.canUndo)
    #expect(live.workspace == nil)
}

@Test func nothingIsLiveBeforeBegin() {
    var model = cards()
    var live = DesignLiveEdit()
    live.sample(from: sample(0), to: sample(40))
    live.preview(.opacity(0.5))
    #expect(live.workspace == nil)
    live.end(into: &model)
    #expect(model == cards())
}

@Test func aScrubPreviewsOnTheCopyAndCommitsOneStep() throws {
    var model = cards()
    model.selectItem("node-2")
    var live = DesignLiveEdit()
    live.begin(from: model)
    for value in stride(from: 0.9, through: 0.3, by: -0.1) { live.preview(.opacity(value)) }
    #expect(model.selectedNode?.opacity == 1)
    let shown = try #require(live.workspace?.selectedNode?.opacity)
    #expect(abs(shown - 0.3) < 1e-9)
    #expect(live.workspace?.canUndo == true)

    #expect(live.end(into: &model) == nil)
    #expect(abs((model.selectedNode?.opacity ?? 0) - 0.3) < 1e-9)
    #expect(model.undoActionName == "Undo Change Opacity")
    #expect(live.workspace == nil)

    // The scrub's step is closed: a second scrub is a second step.
    live.begin(from: model)
    live.preview(.opacity(0.8))
    live.end(into: &model)
    model.undo()
    #expect(abs((model.selectedNode?.opacity ?? 0) - 0.3) < 1e-9)
    model.undo()
    #expect(model.selectedNode?.opacity == 1)
    #expect(!model.canUndo)
}

@Test func aRefusedScrubSaysWhyAndChangesNothing() {
    var model = cards()
    var live = DesignLiveEdit()
    live.begin(from: model)
    live.preview(.opacity(0.5))
    #expect(live.workspace == model)
    #expect(live.end(into: &model) == .nothingSelected)
    #expect(model == cards())
    #expect(live.workspace == nil)
}
