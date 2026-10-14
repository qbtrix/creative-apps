// LockedLayerStaleMessageTests.swift: the unlock message a refused Pen click shows (#696) stays while the locked
// layer is selected, and clears once another, unlocked layer is selected, so it never stays up while the Pen draws
// (#699).
import FlareCore
@testable import FlareModel
import Testing

private func click(_ w: inout FlareWorkspace, _ x: Double, _ y: Double) { w.drag(from: Point(x: x, y: y), to: Point(x: x, y: y)) }

/// Bounce with three Pen clicks on an unlocked layer, then the locked Background selected and clicked on (refused).
private func refusedPenPath() -> (FlareWorkspace, unlocked: String) {
    var w = FlareWorkspace(services: .fake())
    w.load(FlareFixtures.bounce)
    let unlocked = w.layers.first { !$0.isLocked }?.id ?? ""
    w.selectLayer(unlocked)
    w.selectTool(.pen)
    for (x, y) in [(0.0, 0.0), (50, 0), (50, 50)] { click(&w, x, y) }
    w.selectLayer("background")
    click(&w, 0, 0)
    return (w, unlocked)
}

@Test func theUnlockMessageStaysWhileTheLockedLayerIsSelected() {
    var (w, _) = refusedPenPath()
    #expect(w.layerError?.message == FlareWorkspace.unlockMessage("Background"))
    w.selectLayer("background")
    click(&w, 0, 50)
    #expect(w.layerError?.message == FlareWorkspace.unlockMessage("Background"))
    #expect(w.draft?.shape.points.count == 3)
}

@Test func selectingAnUnlockedLayerClearsTheUnlockMessageAndThePenKeepsDrawing() {
    var (w, unlocked) = refusedPenPath()
    let points = w.draft?.shape.points ?? []
    w.selectLayer(unlocked)
    #expect(w.layerError == nil)
    click(&w, 0, 50)
    #expect(w.layerError == nil)
    #expect(w.draft?.shape.points.count == 4)
    #expect(Array(w.draft?.shape.points.prefix(3) ?? []) == points)
}

@Test func selectingAnUnlockedLayerKeepsAnErrorThatIsNotTheUnlockMessage() {
    var w = FlareWorkspace(services: .fake())
    w.load(FlareFixtures.bounce)
    let unlocked = w.layers.first { !$0.isLocked }?.id ?? ""
    w.selectLayer("background")
    w.refuse(.refused("Something else."))
    w.selectLayer(unlocked)
    #expect(w.layerError == .refused("Something else."))
}
