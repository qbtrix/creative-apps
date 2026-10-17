// SidebarSceneSelectTests.swift: the sidebar's `.layers(.select(id:))` lands in `selectItem`. On Keyed Ball, the
// scene row drops Ball's selection (so the easing editor has no segments) even though Scene 1 is already the
// selected scene, and Ball's row brings it back (#1838).
@testable import FlareModel
import Testing

@Test func selectingTheOpenSceneRowDropsTheLayerSelection() {
    var w = FlareWorkspace(services: .fake())
    w.newSampleAnimation()
    #expect(w.selectedSceneID == "scene-1" && w.selectedLayerID == "ball" && !w.easingSegments.isEmpty)

    w.selectItem("scene-1")
    #expect(w.selectedSceneID == "scene-1")
    #expect(w.selectedLayerID == nil)
    #expect(w.easingSegments.isEmpty)

    w.selectItem("ball")
    #expect(w.selectedLayerID == "ball")
    #expect(!w.easingSegments.isEmpty)
}

@Test func anUnknownSidebarIDChangesNothing() {
    var w = FlareWorkspace(services: .fake())
    w.newSampleAnimation()
    w.selectItem("no-such-row")
    #expect(w.selectedSceneID == "scene-1" && w.selectedLayerID == "ball")
}
