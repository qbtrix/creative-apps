// HaloKeyByDragTests.swift: LK-7, dragging a layer in the viewer (#207). The
// artboard-to-composition mapping, a begin that hits and selects, moves that
// only offset the preview, one "Move" on mouse-up (a key on Ball's animated
// x), and a miss, a cancel and a click that record nothing. On `.fake` and on
// `.live` with FakeProjectHistory (the live history may still be a stub).
// Linux and macOS.
@testable import HaloModel
import Testing

private let dragServices: [HaloServices] = {
    var live = HaloServices.live
    live.history = FakeProjectHistory()
    return [.fake, live]
}()

/// `keyed` on `services` with nothing selected and the playhead at frame 12.
private func keyedProject(_ services: HaloServices) throws -> HaloProject {
    let state = try #require(HaloFixtures.project("keyed"))
    var project = HaloProject(services: services)
    project.restore(state)
    project.scrub(to: 12)
    return project
}

private func ballID(_ project: HaloProject) throws -> String {
    try #require(project.selectedComposition?.layers.first { $0.name == "Ball" }).id
}

/// Ball's box center in composition pixels at the playhead.
private func ballCenter(_ project: HaloProject) throws -> HaloPoint {
    let comp = try #require(project.selectedComposition)
    let ball = try #require(comp.layers.first { $0.name == "Ball" })
    let world = try #require(HaloKeyRules.worldMatrix(of: ball.id, in: comp, at: comp.playheadFrame))
    let b = ball.bounds(in: comp)
    return world.apply(HaloPoint(x: b.x + b.width / 2, y: b.y + b.height / 2))
}

private func ballX(_ project: HaloProject, at frame: Int) throws -> Double {
    let comp = try #require(project.selectedComposition)
    let ball = try #require(comp.layers.first { $0.name == "Ball" })
    return HaloKeyRules.value(.x, of: ball, in: comp, at: frame)
}

/// How far `moved` carries three points of layer space past `base`; nil
/// unless it is the same shift at all three, a pure translation.
private func shifted(_ moved: HaloMatrix, from base: HaloMatrix) -> HaloPoint? {
    let shifts = [HaloPoint(x: 0, y: 0), HaloPoint(x: 100, y: 0), HaloPoint(x: 0, y: 100)].map { p in
        let a = moved.apply(p), b = base.apply(p)
        return HaloPoint(x: a.x - b.x, y: a.y - b.y)
    }
    return shifts.allSatisfy { abs($0.x - shifts[0].x) < 1e-9 && abs($0.y - shifts[0].y) < 1e-9 }
        ? HaloPoint(x: (shifts[0].x * 1e6).rounded() / 1e6, y: (shifts[0].y * 1e6).rounded() / 1e6) : nil
}

@Test(arguments: dragServices)
func compositionPointScalesTheArtboardToCompositionPixels(_ services: HaloServices) throws {
    let project = try keyedProject(services)
    let p = try #require(project.compositionPoint(x: 480, y: 270, artboardWidth: 960, artboardHeight: 540))
    #expect(p.x == 960 && p.y == 540)
    let corner = try #require(project.compositionPoint(x: 960, y: 0, artboardWidth: 480, artboardHeight: 270))
    #expect(corner.x == 3840 && corner.y == 0)
    #expect(project.compositionPoint(x: 1, y: 1, artboardWidth: 0, artboardHeight: 540) == nil)
    #expect(project.compositionPoint(x: 1, y: 1, artboardWidth: 960, artboardHeight: 0) == nil)
    #expect(project.compositionPoint(x: 1, y: 1, artboardWidth: -960, artboardHeight: 540) == nil)
    let empty = HaloProject(services: services)
    #expect(empty.compositionPoint(x: 1, y: 1, artboardWidth: 960, artboardHeight: 540) == nil)
}

@Test(arguments: dragServices)
func aDragPreviewsWithoutRecordingThenEndsInOneMove(_ services: HaloServices) throws {
    var project = try keyedProject(services)
    let ball = try ballID(project), center = try ballCenter(project)
    #expect(try ballX(project, at: 12) == 560)
    let steps = project.history.undo
    project.beginViewerDrag(at: center)
    #expect(project.selectedLayerID == ball)
    #expect(project.viewerDrag == HaloViewerDragState(layerID: ball, start: center))
    #expect(project.history.undo == steps)
    let before = project.document
    let baseItem = project.viewerDrawList?.items.first { $0.layerID == ball }
    project.moveViewerDrag(to: HaloPoint(x: center.x + 40, y: center.y + 10))
    project.moveViewerDrag(to: HaloPoint(x: center.x + 100, y: center.y))
    #expect(project.viewerDrag?.delta == HaloPoint(x: 100, y: 0))
    #expect(project.history.undo == steps)
    #expect(project.document == before)
    // The preview: Ball's draw item moves by the delta (both draw lists are real).
    let base = try #require(baseItem)
    let moved = try #require(project.viewerDrawList?.items.first { $0.layerID == ball })
    #expect(shifted(moved.matrix, from: base.matrix) == HaloPoint(x: 100, y: 0))
    project.endViewerDrag()
    #expect(project.viewerDrag == nil)
    #expect(project.history.undo.count == steps.count + 1)
    #expect(project.history.undoTitle == "Undo Move")
    #expect(try ballX(project, at: 12) == 660)
    #expect(try ballX(project, at: 6) == 410)
    #expect(project.file.unsaved)
}

@Test func theFakePreviewOffsetsOnlyBallsDrawItem() throws {
    var project = try keyedProject(.fake)
    let ball = try ballID(project), center = try ballCenter(project)
    let base = try #require(project.viewerDrawList?.items.first { $0.layerID == ball })
    let floor = project.viewerDrawList?.items.first { $0.layerID != ball }
    project.beginViewerDrag(at: center)
    project.moveViewerDrag(to: HaloPoint(x: center.x + 30, y: center.y - 20))
    let moved = try #require(project.viewerDrawList?.items.first { $0.layerID == ball })
    #expect(shifted(moved.matrix, from: base.matrix) == HaloPoint(x: 30, y: -20))
    #expect(project.viewerDrawList?.items.first { $0.layerID != ball } == floor)
}

@Test(arguments: dragServices)
func aBeginOnEmptySpaceChangesNothing(_ services: HaloServices) throws {
    var project = try keyedProject(services)
    let before = project
    project.beginViewerDrag(at: HaloPoint(x: 1800, y: 300))
    project.beginViewerDrag(at: HaloPoint(x: -50, y: -50))
    #expect(project == before)
    #expect(project.viewerDrag == nil)
    #expect(project.selectedLayerID == nil)
    project.moveViewerDrag(to: HaloPoint(x: 10, y: 10))
    project.endViewerDrag()
    #expect(project == before)
}

@Test(arguments: dragServices)
func aCancelRecordsNothing(_ services: HaloServices) throws {
    var project = try keyedProject(services)
    let center = try ballCenter(project)
    project.beginViewerDrag(at: center)
    let selected = project
    project.moveViewerDrag(to: HaloPoint(x: center.x + 200, y: center.y + 50))
    project.cancelViewerDrag()
    #expect(project.viewerDrag == nil)
    #expect(project.document == selected.document)
    #expect(project.history == selected.history)
    #expect(try ballX(project, at: 12) == 560)
    project.endViewerDrag()
    #expect(project.history == selected.history)
}

@Test(arguments: dragServices)
func aClickSelectsWithoutAStep(_ services: HaloServices) throws {
    var project = try keyedProject(services)
    let ball = try ballID(project), center = try ballCenter(project)
    let steps = project.history.undo
    project.beginViewerDrag(at: center)
    project.endViewerDrag()
    #expect(project.selectedLayerID == ball)
    #expect(project.viewerDrag == nil)
    #expect(project.history.undo == steps)
    #expect(!project.file.unsaved)
    // A move back to the start is a zero delta too.
    project.beginViewerDrag(at: center)
    project.moveViewerDrag(to: HaloPoint(x: center.x + 5, y: center.y))
    project.moveViewerDrag(to: center)
    project.endViewerDrag()
    #expect(project.history.undo == steps)
}
