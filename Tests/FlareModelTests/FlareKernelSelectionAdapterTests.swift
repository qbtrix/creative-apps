// FlareKernelSelectionAdapterTests.swift: the stage selection on SuiteKernel's `Selection<StageAddress>`
// (adopt-kernel-selection AS-flare). The kernel keeps the ordered picks; a change ends the coalescing run, a click
// that changes nothing keeps it; Shift-click under Select drops the whole layer; a marquee joins through `Marquee.union`.
import FlareCore
@testable import FlareModel
import Testing

private func workspace(_ tool: FlareTool = .select) -> FlareWorkspace {
    var workspace = FlareWorkspace(services: .fake())
    workspace.load(FlareFixtures.bounce)
    workspace.selectTool(tool)
    return workspace
}

private func p(_ x: Double, _ y: Double) -> Point { Point(x: x, y: y) }
private func address(_ layerID: String, _ item: Int = 0) -> StageAddress {
    StageAddress(owner: .scene("scene-1"), layerID: layerID, item: .shape(item))
}

@Test func theKernelKeepsTheClickOrderAndThePrimaryLeadsTheLayersPanel() {
    var w = workspace()
    w.drag(from: p(80, 100), to: p(80, 100))
    w.drag(from: p(275, 352), to: p(275, 352), modifiers: .shift)
    #expect(w.picks.ordered == [address("ball"), address("shadow")])
    #expect(w.picks.primary == address("shadow") && w.selectedLayerID == "shadow")
}

@Test func aClickThatChangesTheSelectionEndsTheEditRun() {
    var w = workspace()
    let before = w.propertyScrubSerial
    w.drag(from: p(80, 100), to: p(80, 100))
    #expect(w.propertyScrubSerial != before)
    let picked = w.propertyScrubSerial
    w.deselect()
    #expect(w.selection.isEmpty && w.propertyScrubSerial != picked)
}

@Test func aClickOnTheLoneSelectedItemKeepsTheEditRun() {
    var w = workspace()
    w.drag(from: p(80, 100), to: p(80, 100))
    w.selectLayer("shadow")
    let before = w.propertyScrubSerial
    w.drag(from: p(80, 100), to: p(80, 100))
    #expect(w.propertyScrubSerial == before && w.selectedLayerID == "ball")
}

@Test func settingTheSameSelectionKeepsTheEditRun() {
    var w = workspace()
    w.setSelection([address("ball"), address("shadow")])
    let before = w.propertyScrubSerial
    w.setSelection([address("ball"), address("shadow")])
    #expect(w.propertyScrubSerial == before)
}

@Test func shiftClickUnderSelectDropsEveryItemOfTheHitLayer() {
    var w = workspace()
    w.setSelection([address("ball", 1), address("shadow")])
    w.drag(from: p(80, 100), to: p(80, 100), modifiers: .shift)
    #expect(w.selection == [address("shadow")] && w.selectedLayerID == "shadow")
}

@Test func aShiftMarqueeJoinsAfterTheSelectionAndAPlainOneReplacesIt() {
    var w = workspace()
    w.drag(from: p(80, 100), to: p(80, 100))
    w.drag(from: p(1, 1), to: p(549, 399), modifiers: .shift)
    #expect(w.selection == [address("ball"), address("shadow")])
    w.drag(from: p(80, 100), to: p(80, 100))
    w.drag(from: p(200, 330), to: p(340, 380))
    #expect(w.selection == [address("shadow")])
}
