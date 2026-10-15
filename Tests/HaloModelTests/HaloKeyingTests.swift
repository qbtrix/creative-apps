// HaloKeyingTests.swift: LK-5, the inspector's TRANSFORM rows. `propertyRows`
// at the playhead, a scrub coalesced into one "Change <title>" step per row,
// a typed value as its own step, a typed non-number refused under its row
// with the document untouched, and the percent rows' shown values. On `.fake`
// and on `.live` with FakeProjectHistory (the live history may still be a
// stub). Linux and macOS.
@testable import HaloModel
import Testing

private let keyingServices: [HaloServices] = {
    var live = HaloServices.live
    live.history = FakeProjectHistory()
    return [.fake, live]
}()

/// `keyed` on `services` with Ball selected and the playhead at frame 12.
private func ballProject(_ services: HaloServices) throws -> HaloProject {
    let state = try #require(HaloFixtures.project("keyed"))
    var project = HaloProject(services: services)
    project.restore(state)
    let ball = try #require(project.selectedComposition?.layers.first { $0.name == "Ball" })
    project.selectLayer(ball.id)
    project.scrub(to: 12)
    return project
}

private func row(_ p: HaloProperty, in project: HaloProject) throws -> HaloPropertyRow {
    try #require(project.propertyRows.first { $0.property == p })
}

@Test(arguments: keyingServices)
func propertyRowsAreTheSelectedLayersEightRowsInOrder(_ services: HaloServices) throws {
    var project = try ballProject(services)
    #expect(project.propertyRows.map(\.property) == HaloProperty.allCases)
    #expect(try row(.opacity, in: project).value == 1)
    #expect(try row(.opacity, in: project).keyState == .keyedHere)
    let floor = try #require(project.selectedComposition?.layers.first { $0.name == "Floor" })
    project.selectLayer(floor.id)
    #expect(project.propertyRows.count == 8)
    let empty = HaloProject(services: services)
    #expect(empty.propertyRows.isEmpty)
    let noLayer = try #require(HaloFixtures.project("keyed"))
    var unselected = HaloProject(services: services)
    unselected.restore(noLayer)
    #expect(unselected.selectedLayerID == nil)
    #expect(unselected.propertyRows == [])
}

@Test(arguments: keyingServices)
func aScrubIsOneStepUntilItEnds(_ services: HaloServices) throws {
    var project = try ballProject(services)
    project.setProperty(.rotation, to: 10)
    project.setProperty(.rotation, to: 20)
    project.setProperty(.rotation, to: 30)
    #expect(project.history.undo.count == 1)
    #expect(project.history.undoTitle == "Undo Change Rotation")
    #expect(try row(.rotation, in: project).value == 30)
    #expect(project.file.unsaved)
    project.endPropertyScrub()
    project.setProperty(.rotation, to: 40)
    #expect(project.history.undo.count == 2)
    #expect(try row(.rotation, in: project).value == 40)
}

@Test(arguments: keyingServices)
func aScrubOfAnotherRowIsItsOwnStep(_ services: HaloServices) throws {
    var project = try ballProject(services)
    project.setProperty(.rotation, to: 10)
    project.setProperty(.y, to: 300)
    #expect(project.history.undo.count == 2)
    #expect(project.history.undoTitle == "Undo Change Position Y")
}

@Test(arguments: keyingServices)
func setPropertyWithoutALayerDoesNothing(_ services: HaloServices) throws {
    let state = try #require(HaloFixtures.project("keyed"))
    var project = HaloProject(services: services)
    project.restore(state)
    let before = project
    project.setProperty(.rotation, to: 45)
    project.setProperty(.rotation, text: "45")
    #expect(project.document == before.document)
    #expect(project.history.undo.isEmpty)
}

@Test(arguments: keyingServices)
func typedTextThatIsNotANumberIsRefusedUnderItsRow(_ services: HaloServices) throws {
    var project = try ballProject(services)
    project.setProperty(.rotation, to: 10)
    let before = project.document
    project.setProperty(.rotation, text: "abc")
    #expect(project.refusal == HaloRefusal(control: "halo.inspector.row.rotation", message: "Rotation needs a number."))
    #expect(project.document == before)
    #expect(project.history.undo.count == 1)
    project.setProperty(.rotation, text: "45°")
    #expect(project.refusal == nil)
}

@Test(arguments: keyingServices)
func aTypedValueIsItsOwnStepEvenRightAfterAScrub(_ services: HaloServices) throws {
    var project = try ballProject(services)
    project.setProperty(.rotation, to: 10)
    project.setProperty(.rotation, to: 20)
    project.setProperty(.rotation, text: "45°")
    #expect(project.history.undo.count == 2)
    #expect(try row(.rotation, in: project).value == 45)
    project.setProperty(.rotation, to: 50)  // the next scrub is its own step too
    #expect(project.history.undo.count == 3)
    project.setProperty(.opacity, text: " 50 %")
    #expect(project.history.undo.count == 4)
    #expect(project.history.undoTitle == "Undo Change Opacity")
    #expect(try row(.opacity, in: project).value == 0.5)
}

@Test(arguments: keyingServices)
func percentRowsShowAHundredTimesTheStoredValue(_ services: HaloServices) throws {
    var project = try ballProject(services)
    project.setProperty(.opacity, to: 0.5)
    let opacity = try row(.opacity, in: project)
    #expect(opacity.shown == 50)
    #expect(opacity.shownRange == 0...100)
    #expect(opacity.shownStep == 1)
    #expect(HaloProperty.opacity.stored(fromShown: 50) == 0.5)
    #expect(HaloProperty.scaleX.stored(fromShown: 250) == 2.5)
    let rotation = try row(.rotation, in: project)
    #expect(rotation.shown == rotation.value)
    #expect(rotation.shownRange == -36_000...36_000)
    #expect(rotation.shownStep == 1)
    #expect(HaloProperty.rotation.stored(fromShown: 45) == 45)
}
