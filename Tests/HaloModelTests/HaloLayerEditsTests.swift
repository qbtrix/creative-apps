// HaloLayerEditsTests.swift: LP-1, layer housekeeping. Delete, rename, move
// and duplicate a layer of the selected composition, each one named undo step
// (QB-F3); refused and no-op edits record nothing; undo of each edit through
// `services.history.undo` on the recorded history. Linux and macOS.
@testable import HaloModel
import Testing

/// `fixture` on `services` with `change` applied to its first composition and
/// the layer named `select` selected.
private func layerProject(
    _ fixture: String = "three-layers", _ services: HaloServices = .fake, select: String? = "Badge",
    _ change: (inout HaloComposition) throws -> Void = { _ in }
) throws -> HaloProject {
    var state = try #require(HaloFixtures.project(fixture))
    try change(&state.compositions[0])
    var project = HaloProject(services: services)
    project.restore(state)
    if let select { project.selectLayer(try layerID(select, in: project)) }
    return project
}

private func layerID(_ name: String, in project: HaloProject) throws -> String {
    try #require(project.selectedComposition?.layers.first { $0.name == name }).id
}

private func names(_ project: HaloProject) -> [String] { project.selectedComposition?.layers.map(\.name) ?? [] }

/// The document undo of the newest step returns, and the history after it.
private func undone(_ project: HaloProject) throws -> (HaloDocumentState, HaloHistory) {
    var history = project.history
    return (try #require(project.services.history.undo(project.document, in: &history)), history)
}

/// A PropertyKeying whose writes all throw `error`: the W0 live stub's
/// `.notBuilt("Parenting")`, or any other refusal.
private struct ThrowingKeying: PropertyKeying {
    let error: HaloEditError
    func rows(for layerID: String, in composition: HaloComposition, at frame: Int) -> [HaloPropertyRow] { [] }
    func setValue(_ v: Double, for p: HaloProperty, of id: String, at f: Int, in c: inout HaloComposition) throws {
        throw error
    }
    func toggleAnimation(_ p: HaloProperty, of id: String, at f: Int, in c: inout HaloComposition) throws { throw error }
    func toggleKey(_ p: HaloProperty, of id: String, at f: Int, in c: inout HaloComposition) throws { throw error }
    func setParent(_ parentID: String?, of id: String, at f: Int, in c: inout HaloComposition) throws { throw error }
}

@Test func duplicateInsertsASelectedCopyDirectlyAbove() throws {
    var project = try layerProject { comp in
        comp.layers[1].tracks["x"] = HaloFixtures.keys([(0, 100), (24, 400)])
        comp.layers[1].parentID = comp.layers[3].id
        comp.layers[1].opacity = 0.5
        comp.layers[1].blendMode = .multiply
    }
    let before = project.document
    let badge = try #require(project.selectedLayer)
    project.duplicateSelectedLayer()
    #expect(names(project) == ["Title", "Badge copy", "Badge", "Background", "Rig"])
    let copy = try #require(project.selectedLayer)
    #expect(copy.name == "Badge copy")
    #expect(!before.compositions.flatMap(\.layers).map(\.id).contains(copy.id))
    var same = copy.withID(badge.id)
    same.name = badge.name
    #expect(same == badge)  // tracks, parent, text, span, opacity, blend
    #expect(project.history.undo.count == 1)
    #expect(project.history.undoTitle == "Undo Duplicate Layer")
    let (state, _) = try undone(project)
    #expect(state.compositions == before.compositions)
    #expect(state.selectedLayerID == badge.id)
}

@Test func anUndoneDuplicateNeverGivesItsIDAgain() throws {
    var project = try layerProject()
    project.duplicateSelectedLayer()
    let first = try #require(project.selectedLayer?.id)
    let (state, history) = try undone(project)
    project.history = history
    project.restore(state)
    #expect(names(project) == ["Title", "Badge", "Background", "Rig"])
    project.duplicateSelectedLayer()
    #expect(project.selectedLayer?.name == "Badge copy")
    #expect(project.selectedLayer?.id != first)
}

@Test func renameNormalizesTheNameAsOneStep() throws {
    var project = try layerProject()
    let badge = try layerID("Badge", in: project)
    let before = project.document
    project.renameLayer(badge, to: "  Badge\t2 ")
    #expect(names(project) == ["Title", "Badge 2", "Background", "Rig"])
    #expect(project.history.undo.map(\.name) == ["Rename Layer"])
    #expect(try undone(project).0 == before)
}

@Test func aBlankUnchangedOrUnknownRenameRecordsNothing() throws {
    var project = try layerProject()
    let badge = try layerID("Badge", in: project)
    project.renameLayer(badge, to: "   ")
    #expect(names(project) == ["Title", "Badge", "Background", "Rig"])
    #expect(project.refusal == HaloRefusal(control: "halo.layer.row.\(badge)", message: "Enter a name."))
    project.renameLayer(badge, to: "Badge")
    #expect(project.refusal == nil)
    project.renameLayer("comp-1-layer-99", to: "Ghost")
    #expect(project.refusal == HaloRefusal(control: "halo.layer.row.comp-1-layer-99", message: "That layer no longer exists."))
    #expect(project.history.undo.isEmpty)
}

@Test func moveLandsAtTheClampedIndexAsOneStep() throws {
    var project = try layerProject()
    let badge = try layerID("Badge", in: project)
    let before = project.document
    project.moveLayer(badge, to: 3)
    #expect(names(project) == ["Title", "Background", "Rig", "Badge"])
    #expect(project.history.undo.map(\.name) == ["Move Layer"])
    #expect(project.viewerSummary == "Frame 0: Badge, Background")
    #expect(try undone(project).0 == before)
    project.moveLayer(badge, to: 3)
    #expect(project.history.undo.count == 1)  // same place: no step
    project.restore(before)
    project.moveLayer(badge, to: 99)
    #expect(names(project) == ["Title", "Background", "Rig", "Badge"])
    project.moveLayer(badge, to: -5)
    #expect(names(project) == ["Badge", "Title", "Background", "Rig"])
}

@Test func moveTargetTurnsADropOffsetIntoTheFinalIndex() {
    #expect(HaloProject.moveTarget(from: 1, toOffset: 4, count: 4) == 3)
    #expect(HaloProject.moveTarget(from: 2, toOffset: 0, count: 4) == 0)
    #expect(HaloProject.moveTarget(from: 0, toOffset: 2, count: 4) == 1)
    #expect(HaloProject.moveTarget(from: 7, toOffset: 0, count: 4) == nil)
    #expect(HaloProject.moveTarget(from: -1, toOffset: 0, count: 4) == nil)
    #expect(HaloProject.moveTarget(from: 0, toOffset: 0, count: 0) == nil)
}

@Test func forwardAndBackwardMoveOnePlaceAndDoNothingAtTheEnds() throws {
    var project = try layerProject()
    project.bringSelectedLayerForward()
    #expect(names(project) == ["Badge", "Title", "Background", "Rig"])
    project.sendSelectedLayerBackward()
    #expect(names(project) == ["Title", "Badge", "Background", "Rig"])
    #expect(project.history.undo.map(\.name) == ["Move Layer", "Move Layer"])
    project.selectLayer(try layerID("Title", in: project))
    project.bringSelectedLayerForward()
    project.selectLayer(try layerID("Rig", in: project))
    project.sendSelectedLayerBackward()
    #expect(names(project) == ["Title", "Badge", "Background", "Rig"])
    #expect(project.history.undo.count == 2)
    #expect(project.refusal == nil)
}

@Test func deleteSelectsTheLayerThatTookItsPlace() throws {
    var project = try layerProject()
    let before = project.document
    project.deleteSelectedLayer()
    #expect(names(project) == ["Title", "Background", "Rig"])
    #expect(project.selectedLayer?.name == "Background")
    #expect(project.history.undoTitle == "Undo Delete Layer")
    #expect(try undone(project).0 == before)
    var bottom = try layerProject(select: "Rig")
    bottom.deleteSelectedLayer()
    #expect(bottom.selectedLayer?.name == "Background")
}

@Test func deletingEveryLayerLeavesNoSelection() throws {
    var project = try layerProject(select: "Title")
    for _ in 0..<4 { project.deleteSelectedLayer() }
    #expect(names(project).isEmpty)
    #expect(project.selectedLayerID == nil)
    #expect(project.viewerSummary == "Frame 0: no layers")
    #expect(project.history.undo.count == 4)
}

@Test func deleteWithNothingSelectedIsRefused() throws {
    var project = try layerProject(select: nil)
    project.deleteSelectedLayer()
    #expect(project.refusal == HaloRefusal(control: "halo.layer.list", message: "Select a layer first."))
    #expect(project.history.undo.isEmpty)
    #expect(names(project).count == 4)
}

@Test func everyEditNeedsAComposition() {
    let edits: [(inout HaloProject) -> Void] = [
        { $0.deleteSelectedLayer() }, { $0.renameLayer("x", to: "Y") }, { $0.moveLayer("x", to: 0) },
        { $0.bringSelectedLayerForward() }, { $0.sendSelectedLayerBackward() }, { $0.duplicateSelectedLayer() },
    ]
    for run in edits {
        var project = HaloProject(services: .fake)
        run(&project)
        #expect(project.refusal?.message == "Create a composition first.")
        #expect(project.history.undo.isEmpty)
    }
}

/// `parented` with Ball following Rig (set directly, no `setParent`), the
/// playhead at 12 and Rig selected.
private func parentedProject(_ services: HaloServices) throws -> HaloProject {
    var project = try layerProject("parented", services, select: "Rig") { comp in
        comp.layers[1].parentID = comp.layers[0].id
    }
    project.scrub(to: 12)
    return project
}

private func anchorOnScreen(_ id: String, in comp: HaloComposition) throws -> HaloPoint {
    let placing = FakeLayerPlacing()
    let world = try #require(placing.worldMatrix(of: id, in: comp, at: comp.playheadFrame))
    let x = try #require(placing.value(.anchorX, of: id, in: comp, at: comp.playheadFrame))
    let y = try #require(placing.value(.anchorY, of: id, in: comp, at: comp.playheadFrame))
    return world.apply(HaloPoint(x: x, y: y))
}

@Test func deletingAParentKeepsItsChildInPlace() throws {
    var project = try parentedProject(.fake)
    let before = project.document
    let ball = try layerID("Ball", in: project)
    let onScreen = try anchorOnScreen(ball, in: try #require(project.selectedComposition))
    project.deleteSelectedLayer()
    let comp = try #require(project.selectedComposition)
    #expect(names(project) == ["Ball", "Floor"])
    #expect(comp.layers.first?.parentID == nil)
    let after = try anchorOnScreen(ball, in: comp)
    #expect(abs(after.x - onScreen.x) < 1e-6 && abs(after.y - onScreen.y) < 1e-6)
    #expect(project.history.undo.map(\.name) == ["Delete Layer"])
    #expect(try undone(project).0 == before)
}

@Test func deletingAParentOnAnUnbuiltKeyingClearsTheParentOnly() throws {
    var services = HaloServices.fake
    services.keying = ThrowingKeying(error: .notBuilt("Parenting"))
    var project = try parentedProject(services)
    let tracks = project.selectedComposition?.layers[1].tracks
    project.deleteSelectedLayer()
    #expect(names(project) == ["Ball", "Floor"])
    #expect(project.selectedComposition?.layers.first?.parentID == nil)
    #expect(project.selectedComposition?.layers.first?.tracks == tracks)
    #expect(project.history.undo.count == 1)
}

@Test func anyOtherKeyingErrorRefusesTheWholeDelete() throws {
    var services = HaloServices.fake
    services.keying = ThrowingKeying(error: .parentCycle("Ball"))
    var project = try parentedProject(services)
    let before = project.document
    project.deleteSelectedLayer()
    #expect(project.document == before)
    #expect(project.refusal == HaloRefusal(control: "halo.layer.list", message: "Ball can't follow a layer that follows it."))
    #expect(project.history.undo.isEmpty)
}

@Test func deletingAParentWorksOnLive() throws {
    var project = try parentedProject(.live)
    project.deleteSelectedLayer()
    #expect(project.refusal == nil)
    #expect(names(project) == ["Ball", "Floor"])
    #expect(project.selectedComposition?.layers.first?.parentID == nil)
}
