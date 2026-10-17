// FlareLiveDragBuiltTests.swift: RenderBudgetFlareTests' canvas drag, without the window (#1792). The budget test opens
// New Sample Animation, selects Ball's first easing segment and chooses Rectangle, then drags on the stage, which runs
// the samples on a FlareLiveDrag and commits the last one plus `endDrag` at mouse-up. On the real services (`.built`,
// what the app launches on) that adds one stage item; on `FlareWorkspace()`'s `.live` services the stage and shapes are
// `NotBuilt`, so nothing draws and the stage list stays empty, which is what the budget test measured.
import FlareCore
import FlareModel
import Testing

/// The budget test's workspace on `services`, a 120-sample Rectangle drag through the stage's path, and the stage
/// item counts before and after.
private func rectangleDrag(on services: FlareServices) throws -> (before: Int, after: Int) {
    var workspace = FlareWorkspace(services: services)
    workspace.newSampleAnimation()
    let segment = try #require(workspace.easingSegments.first, "the sample has no easing segment")
    workspace.selectEasingSegment(segment)
    workspace.selectTool(.rectangle)
    let before = workspace.stageList?.items.count ?? 0
    let start = Point(x: 100, y: 80), end = Point(x: 260, y: 150)
    var live = FlareLiveDrag(on: workspace)
    for i in 1...120 {
        let t = Double(i) / 120
        live.move(StageDragSample(
            start: start, end: Point(x: start.x + (end.x - start.x) * t, y: start.y + (end.y - start.y) * t),
            stageScale: 0.8))
    }
    let s = try #require(live.last)
    workspace.dragChanged(from: s.start, to: s.end, modifiers: s.modifiers, stageScale: s.stageScale)
    workspace.endDrag()
    return (before, workspace.stageList?.items.count ?? 0)
}

@Test func budgetDragDrawsARectangleOnTheBuiltServices() throws {
    let (before, after) = try rectangleDrag(on: .built)
    #expect(before >= 1, "the sample's Ball isn't on the stage")
    #expect(after == before + 1)
}

@Test func budgetDragDrawsNothingOnTheLiveStubs() throws {
    let (before, after) = try rectangleDrag(on: .live)
    #expect(before == 0 && after == 0)
}
