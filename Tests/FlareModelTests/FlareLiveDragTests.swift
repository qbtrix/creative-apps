// FlareLiveDragTests.swift: a stage drag on a copy (#1792). The copy shows what the workspace would while the drag
// lasts, the workspace itself doesn't change, and the last sample plus `endDrag` leaves the workspace as every sample
// did: the same document, selection and one undo step.
import FlareCore
@testable import FlareModel
import Testing

private func opened(_ document: Document, tool: FlareTool = .select) -> FlareWorkspace {
    var workspace = FlareWorkspace(services: .fake())
    workspace.load(document)
    workspace.selectTool(tool)
    return workspace
}

/// Samples from `start` towards `end` in `count` steps, as the stage sends them.
private func samples(from start: Point, to end: Point, count: Int = 12) -> [StageDragSample] {
    (1...count).map { i in
        let t = Double(i) / Double(count)
        return StageDragSample(start: start, end: Point(x: start.x + (end.x - start.x) * t, y: start.y + (end.y - start.y) * t))
    }
}

/// `drags` on a live copy of `workspace`, then on the workspace sample by sample: (live, every-sample workspace).
private func both(_ workspace: FlareWorkspace, _ drags: [StageDragSample]) -> (FlareLiveDrag, FlareWorkspace) {
    var live = FlareLiveDrag(on: workspace), direct = workspace
    for s in drags {
        live.move(s)
        direct.dragChanged(from: s.start, to: s.end, modifiers: s.modifiers, stageScale: s.stageScale)
    }
    return (live, direct)
}

/// Mouse-up the way the stage sends it: the live drag's last sample, then `endDrag`.
private func committed(_ workspace: FlareWorkspace, _ live: FlareLiveDrag) -> FlareWorkspace {
    var workspace = workspace
    if let s = live.last {
        workspace.dragChanged(from: s.start, to: s.end, modifiers: s.modifiers, stageScale: s.stageScale)
    }
    workspace.endDrag()
    return workspace
}

@Test func aRectangleDragDrawsOnTheCopyAndCommitsOnce() throws {
    let workspace = opened(FlareFixtures.empty, tool: .rectangle)
    let (live, direct) = both(workspace, samples(from: Point(x: 10, y: 20), to: Point(x: 110, y: 70)))
    let draft = try #require(live.stageMarks.draft)
    #expect(draft == direct.stageMarks.draft)
    #expect(live.last?.end == Point(x: 110, y: 70))
    #expect(workspace.draft == nil && workspace.canUndo == false)
    var all = direct
    all.endDrag()
    let up = committed(workspace, live)
    #expect(up == all)
    #expect(up.undoActionName != nil && up.undoActionName == all.undoActionName)
    #expect(up.stageList?.items.count == (workspace.stageList?.items.count ?? 0) + 1)
}

@Test func aMoveDragPreviewsOnTheCopyAndMovesOnce() throws {
    let workspace = opened(FlareFixtures.bounce)
    let (live, direct) = both(workspace, samples(from: Point(x: 80, y: 100), to: Point(x: 120, y: 140)))
    let preview = try #require(live.movePreview)
    #expect(preview == direct.dragPreview)
    #expect(preview != workspace.stageList)
    #expect(workspace.dragPreview == nil)
    var all = direct
    all.endDrag()
    let up = committed(workspace, live)
    #expect(up == all && up.document != workspace.document)
}

@Test func aMarqueeShowsOnTheCopyAndSelectsAsEverySampleDid() {
    let workspace = opened(FlareFixtures.bounce)
    let (live, direct) = both(workspace, samples(from: Point(x: 540, y: 60), to: Point(x: 10, y: 10)))
    #expect(live.stageMarks.marquee == Rect(minX: 10, minY: 10, maxX: 540, maxY: 60))
    #expect(live.movePreview == nil && workspace.marquee == nil)
    var all = direct
    all.endDrag()
    #expect(committed(workspace, live) == all)
}

@Test func beforeItsFirstSampleTheCopyShowsTheWorkspace() {
    var workspace = opened(FlareFixtures.bounce)
    workspace.drag(from: Point(x: 80, y: 100), to: Point(x: 80, y: 100))
    let live = FlareLiveDrag(on: workspace)
    #expect(live.last == nil && live.movePreview == nil)
    #expect(live.stageMarks == workspace.stageMarks && live.stageMarks.selection != nil)
    #expect(committed(workspace, live) == workspace)
}
