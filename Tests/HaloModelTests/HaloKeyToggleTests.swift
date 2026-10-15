// HaloKeyToggleTests.swift: LK-6, the stopwatch, the key diamond and the
// LAYER group's pickers. Each toggle is its own step named from the row's
// state before it, Set Parent is one step and a cycle is refused under the
// Parent picker, the Parent choices never offer a cycle, and Blend lists all
// sixteen modes. On `.fake` and on `.live` with FakeProjectHistory. Linux and
// macOS.
import CoreRaster
@testable import HaloModel
import Testing

private let toggleServices: [HaloServices] = {
    var live = HaloServices.live
    live.history = FakeProjectHistory()
    return [.fake, live]
}()

/// `fixture` on `services` with Ball selected and the playhead at frame 12.
private func ballProject(_ services: HaloServices, _ fixture: String = "keyed") throws -> HaloProject {
    let state = try #require(HaloFixtures.project(fixture))
    var project = HaloProject(services: services)
    project.restore(state)
    project.selectLayer(try layerID("Ball", in: project))
    project.scrub(to: 12)
    return project
}

private func layerID(_ name: String, in project: HaloProject) throws -> String {
    try #require(project.selectedComposition?.layers.first { $0.name == name }).id
}

private func track(_ p: HaloProperty, of name: String, in project: HaloProject) throws -> [Int] {
    let layer = try #require(project.selectedComposition?.layers.first { $0.name == name })
    return (layer.tracks[p.rawValue] ?? []).map(\.frame)
}

@Test(arguments: toggleServices)
func theStopwatchNamesItsStepFromTheStateBefore(_ services: HaloServices) throws {
    var project = try ballProject(services)
    project.scrub(to: 6)
    project.toggleAnimation(.rotation)
    #expect(project.history.undoTitle == "Undo Animate Rotation")
    #expect(try track(.rotation, of: "Ball", in: project) == [6, 47])
    #expect(project.history.undo.count == 1)
    project.toggleAnimation(.rotation)
    #expect(project.history.undoTitle == "Undo Stop Animating Rotation")
    #expect(project.history.undo.count == 2)
    #expect(project.propertyRows.first { $0.property == .rotation }?.keyState == .notAnimated)
}

@Test(arguments: toggleServices)
func aToggleNeverMergesWithAScrub(_ services: HaloServices) throws {
    var project = try ballProject(services)
    project.setProperty(.rotation, to: 10)
    project.toggleAnimation(.rotation)
    project.setProperty(.rotation, to: 20)
    #expect(project.history.undo.count == 3)
    #expect(project.history.undoTitle == "Undo Change Rotation")
}

@Test(arguments: toggleServices)
func theDiamondAddsThenRemovesAKey(_ services: HaloServices) throws {
    var project = try ballProject(services)
    project.scrub(to: 20)
    project.toggleKey(.opacity)
    #expect(project.history.undoTitle == "Undo Add Key")
    #expect(try track(.opacity, of: "Ball", in: project) == [0, 12, 20])
    project.toggleKey(.opacity)
    #expect(project.history.undoTitle == "Undo Remove Key")
    #expect(try track(.opacity, of: "Ball", in: project) == [0, 12])
    #expect(project.history.undo.count == 2)
}

@Test(arguments: toggleServices)
func setParentIsOneStepAndACycleIsRefusedUnderThePicker(_ services: HaloServices) throws {
    var project = try ballProject(services, "parented")
    let ball = try layerID("Ball", in: project), rig = try layerID("Rig", in: project)
    project.setParent(rig)
    #expect(project.history.undoTitle == "Undo Set Parent")
    #expect(project.selectedLayer?.parentID == rig)
    project.selectLayer(rig)
    let before = project.document
    project.setParent(ball)
    #expect(project.refusal == HaloRefusal(control: "halo.inspector.parent", message: "Rig can't follow a layer that follows it."))
    #expect(project.document == before)
    #expect(project.history.undo.count == 1)
}

@Test(arguments: toggleServices)
func parentChoicesNeverOfferACycle(_ services: HaloServices) throws {
    var project = try ballProject(services, "parented")
    #expect(Set(project.parentChoices.map(\.name)) == ["Floor", "Rig"])
    #expect(project.parentChoices.map(\.name) == ["Rig", "Floor"])  // timeline order
    let rig = try layerID("Rig", in: project)
    #expect(project.parentChoices.contains { $0.id == rig })
    project.setParent(rig)
    project.selectLayer(rig)
    #expect(project.parentChoices.map(\.name) == ["Floor"])
    #expect(HaloProject(services: services).parentChoices.isEmpty)
}

@Test func blendChoicesListEveryModeWithItsTitle() {
    let choices = HaloProject().blendChoices
    #expect(choices.count == 16)
    #expect(choices.map(\.mode) == BlendMode.allCases)
    #expect(choices.first?.title == "Normal")
    #expect(choices.contains { $0.mode == .multiply && $0.title == "Multiply" })
    #expect(choices.contains { $0.mode == .colorDodge && $0.title == "Color Dodge" })
    #expect(choices.contains { $0.mode == .softLight && $0.title == "Soft Light" })
    #expect(Set(choices.map(\.title)).count == 16)
}

@Test(arguments: toggleServices)
func togglesWithoutALayerDoNothing(_ services: HaloServices) throws {
    let state = try #require(HaloFixtures.project("keyed"))
    var project = HaloProject(services: services)
    project.restore(state)
    let before = project.document
    project.toggleAnimation(.rotation)
    project.toggleKey(.opacity)
    project.setParent(nil)
    #expect(project.document == before)
    #expect(project.history.undo.isEmpty)
}
