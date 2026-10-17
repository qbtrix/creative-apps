// HaloTextColorTests.swift (TX-2): the color row's edit. On a text, solid or
// shape layer `setLayerColor` is one "Change Color" step (QB-F3) that picks in
// a row merge into; a null takes no color and records nothing; components
// clamp to 0...1 and a NaN pick changes nothing; `HaloLayerColor(bytes:)` and
// `bytes` round-trip 8-bit sRGB. Linux and macOS.
@testable import HaloModel
import Testing

private let picked = HaloLayerColor(red: 0.2, green: 0.4, blue: 0.6)

/// `fixture` on `.fake` services with the layer named `select` selected.
private func colorProject(_ fixture: String, select: String) throws -> HaloProject {
    var project = HaloProject(services: .fake)
    project.restore(try #require(HaloFixtures.project(fixture)))
    let layer = try #require(project.selectedComposition?.layers.first { $0.name == select })
    project.selectLayer(layer.id)
    return project
}

/// `empty` with Layer > New > Text run: "Text 1" selected, one step.
private func textProject() throws -> HaloProject {
    var project = HaloProject(services: .fake)
    project.restore(try #require(HaloFixtures.project("empty")))
    project.newLayer(.text)
    #expect(project.selectedLayer?.name == "Text 1")
    return project
}

@Test func aTextLayerColorIsOneNamedStep() throws {
    var project = try textProject()
    let steps = project.history.undo.count
    #expect(project.selectedLayerColor == HaloLayerKind.text.defaultColor)
    project.setLayerColor(picked)
    #expect(project.selectedLayerColor == picked)
    #expect(project.selectedLayer?.color == picked)
    #expect(project.history.undo.count == steps + 1)
    #expect(project.undoTitle == "Undo Change Color")
    #expect(project.file.unsaved)
    project.undo()
    #expect(project.selectedLayerColor == HaloLayerKind.text.defaultColor)
    project.redo()
    #expect(project.selectedLayerColor == picked)
}

@Test func picksInARowAreOneStep() throws {
    var project = try textProject()
    let steps = project.history.undo.count
    project.setLayerColor(HaloLayerColor(red: 0.1, green: 0.1, blue: 0.1))
    project.setLayerColor(picked)
    #expect(project.history.undo.count == steps + 1)
    #expect(project.selectedLayerColor == picked)
    project.undo()
    #expect(project.selectedLayerColor == HaloLayerKind.text.defaultColor)
}

@Test func aPickAfterAnotherEditIsANewStep() throws {
    var project = try textProject()
    project.setLayerColor(picked)
    project.endCoalescing()
    let steps = project.history.undo.count
    project.setLayerColor(HaloLayerColor(red: 1, green: 0, blue: 0))
    #expect(project.history.undo.count == steps + 1)
}

@Test func theSameColorRecordsNothing() throws {
    var project = try textProject()
    project.setLayerColor(picked)
    project.endCoalescing()
    let history = project.history
    project.setLayerColor(picked)
    #expect(project.history == history)
}

@Test(arguments: [("keyed", "Ball"), ("three-layers", "Background"), ("three-layers", "Badge")])
func solidsAndShapesTakeAColor(fixture: String, layer: String) throws {
    var project = try colorProject(fixture, select: layer)
    #expect(project.selectedLayerColor == project.selectedLayer?.color)
    project.setLayerColor(picked)
    #expect(project.selectedLayerColor == picked)
    #expect(project.history.undo.count == 1)
    #expect(project.undoTitle == "Undo Change Color")
}

@Test func aNullTakesNoColor() throws {
    var project = try colorProject("three-layers", select: "Rig")
    #expect(project.selectedLayer?.kind == .null)
    #expect(project.selectedLayerColor == nil)
    let before = project.document
    project.setLayerColor(picked)
    #expect(project.document == before)
    #expect(project.history.undo.isEmpty)
    #expect(project.refusal == nil)
    #expect(!project.file.unsaved)
}

@Test func outOfRangeComponentsClamp() throws {
    var project = try textProject()
    project.setLayerColor(HaloLayerColor(red: 1.5, green: -1, blue: 0.5))
    #expect(project.selectedLayerColor == HaloLayerColor(red: 1, green: 0, blue: 0.5))
    project.setLayerColor(HaloLayerColor(red: .infinity, green: -.infinity, blue: 0.5))
    #expect(project.selectedLayerColor == HaloLayerColor(red: 1, green: 0, blue: 0.5))
}

@Test(arguments: [
    HaloLayerColor(red: .nan, green: 0.4, blue: 0.6), HaloLayerColor(red: 0.2, green: .nan, blue: 0.6),
    HaloLayerColor(red: 0.2, green: 0.4, blue: .nan),
])
func aNaNComponentChangesNothing(color: HaloLayerColor) throws {
    var project = try textProject()
    let before = project.document
    let history = project.history
    project.setLayerColor(color)
    #expect(project.document == before)
    #expect(project.history == history)
    #expect(project.refusal == nil)
}

@Test func noLayerOrNoCompositionIsRefusedUnderTheColorRow() throws {
    var empty = HaloProject(services: .fake)
    empty.restore(try #require(HaloFixtures.project("empty")))
    #expect(empty.selectedLayerColor == nil)
    empty.setLayerColor(picked)
    #expect(empty.refusal == HaloRefusal(control: "halo.inspector.text.color", message: HaloEditError.noLayerSelected.message))
    #expect(empty.history.undo.isEmpty)

    var none = HaloProject(services: .fake)
    none.setLayerColor(picked)
    #expect(none.refusal == HaloRefusal(control: "halo.inspector.text.color", message: HaloEditError.noComposition.message))
    #expect(none.history.undo.isEmpty)
}

@Test func bytesRoundTripEightBitSRGB() {
    let color = HaloLayerColor(bytes: 51, 102, 153)
    #expect(abs(color.red - 0.2) < 1e-12)
    #expect(abs(color.green - 0.4) < 1e-12)
    #expect(abs(color.blue - 0.6) < 1e-12)
    let bytes = picked.bytes
    #expect(bytes.red == 51 && bytes.green == 102 && bytes.blue == 153)
    #expect(HaloLayerColor(bytes: 0, 128, 255).bytes == (0, 128, 255))
}

@Test func bytesClampAndReadNaNAsZero() {
    let bytes = HaloLayerColor(red: 1.5, green: -1, blue: .nan).bytes
    #expect(bytes.red == 255 && bytes.green == 0 && bytes.blue == 0)
    #expect(HaloLayerColor(red: 0.5, green: 0.501, blue: 0.499).bytes == (128, 128, 127))
}
