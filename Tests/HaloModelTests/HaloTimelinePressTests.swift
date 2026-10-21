// HaloTimelinePressTests.swift: what a press, a drag and ⌘A on Halo's
// timeline send (key-editing KE-2), the Model half of HaloTimelineClickTests.
// A key press sends `.pickLaneKeys` in the strip's mode (plain replaces,
// Shift extends, Command toggles), a bed press clears, ⌘A routes through
// Select All Keys' help, and a menu nudge is one move and its end.
// Linux and macOS.
@testable import HaloModel
import SuiteKernel
import Testing

@Test func aKeyPressPicksTheLaneInThePressMode() {
    let project = commandProject("parented", .fake)
    let ball = "comp-1-layer-2"
    #expect(project.lanePressCommand(layerID: ball, frame: 12, mode: "replace")
        == .pickLaneKeys(layerID: ball, frame: 12, mode: .replace))
    #expect(project.lanePressCommand(layerID: ball, frame: 12, mode: "extend")
        == .pickLaneKeys(layerID: ball, frame: 12, mode: .extend))
    #expect(project.lanePressCommand(layerID: ball, frame: 12, mode: "toggle")
        == .pickLaneKeys(layerID: ball, frame: 12, mode: .toggle))
    #expect(project.lanePressCommand(layerID: ball, frame: 12, mode: "unknown")
        == .pickLaneKeys(layerID: ball, frame: 12, mode: .replace))
}

@Test func aBedPressClearsThePick() {
    let project = commandProject("parented", .fake)
    #expect(project.lanePressCommand(layerID: "comp-1-layer-2", frame: nil, mode: "replace")
        == .pickLaneKeys(layerID: "comp-1-layer-2", frame: nil, mode: .replace))
}

@Test func whilePickingCantActAKeyPressSelectsTheLayerAndABedPressSendsNothing() {
    let project = HaloProject(services: .fake)
    #expect(project.lanePressCommand(layerID: "layer", frame: 0, mode: "extend") == .selectLayer("layer"))
    #expect(project.lanePressCommand(layerID: "layer", frame: nil, mode: "replace") == nil)
}

@Test func selectAllKeysIsDisabledWithItsHelp() {
    let project = commandProject("parented", .fake)
    #expect(project.unavailableHelp(for: .selectAllKeys) == project.selectAllKeysHelp)
}

@Test func aKeyDragFoldsUnderTheFirstPickedFrame() {
    var project = commandProject("parented", .fake)
    #expect(project.keyDragStart == 0)
    project.pickLaneKeys(layerID: "comp-1-layer-2", frame: 12, mode: .replace)
    #expect(project.keyDragStart == 12)
}

@Test func aMenuNudgeIsOneMoveAndItsEnd() {
    var project = commandProject("parented", .fake)
    project.pickLaneKeys(layerID: "comp-1-layer-2", frame: 12, mode: .replace)
    #expect(project.nudgeKeysCommands(by: -1) == [.moveKeys(by: -1, dragStart: 12), .endKeyDrag])
    #expect(project.unavailableHelp(for: .moveKeys(by: 1, dragStart: 0)) == project.moveKeysHelp)
}
