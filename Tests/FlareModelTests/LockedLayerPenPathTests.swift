// LockedLayerPenPathTests.swift: a click refused because a locked layer is selected leaves a Pen path in progress
// alone (#692). It says why, keeps every point, and once the layer is unlocked or another is selected, the next click
// carries on and can close the path.
import FlareCore
@testable import FlareModel
import Testing

private func click(_ w: inout FlareWorkspace, _ x: Double, _ y: Double) { w.drag(from: Point(x: x, y: y), to: Point(x: x, y: y)) }

/// Bounce with three Pen clicks on an unlocked layer, then the locked Background selected (or the layer locked).
private func penPathThenLocked(byLocking: Bool) -> (FlareWorkspace, unlocked: String) {
    var w = FlareWorkspace(services: .fake())
    w.load(FlareFixtures.bounce)
    let unlocked = w.layers.first { !$0.isLocked }?.id ?? ""
    w.selectLayer(unlocked)
    w.selectTool(.pen)
    for (x, y) in [(0.0, 0.0), (50, 0), (50, 50)] { click(&w, x, y) }
    if byLocking { w.toggleLayerFlag(unlocked, .locked) } else { w.selectLayer("background") }
    return (w, unlocked)
}

@Test(arguments: [false, true])
func aRefusedClickKeepsThePenPathAndSaysWhy(byLocking: Bool) {
    var (w, unlocked) = penPathThenLocked(byLocking: byLocking)
    let points = w.draft?.shape.points, document = w.document
    #expect(points?.count == 3)
    click(&w, 0, 0)
    #expect(w.draft?.shape.points == points)
    #expect(w.document == document)
    let name = byLocking ? w.layers.first { $0.id == unlocked }?.name ?? "" : "Background"
    #expect(w.layerError?.message == FlareWorkspace.unlockMessage(name))
}

@Test(arguments: [false, true])
func afterARefusedClickThePenPathCanStillBeClosed(byLocking: Bool) {
    var (w, unlocked) = penPathThenLocked(byLocking: byLocking)
    let count = w.layers.count
    click(&w, 0, 0)
    if byLocking { w.toggleLayerFlag(unlocked, .locked) } else { w.selectLayer(unlocked) }
    click(&w, 0, 0)
    #expect(w.draft == nil)
    #expect(w.layers.count == count + 1)
}

@Test func aRefusedDragShowsThePenPathUnchangedWhileThePointerMoves() {
    var (w, _) = penPathThenLocked(byLocking: false)
    let draft = w.draft
    w.dragChanged(from: Point(x: 10, y: 10), to: Point(x: 30, y: 30))
    #expect(w.draft == draft)
    w.endDrag()
    #expect(w.draft == draft)
}
