// MachineUndoPreviewTests.swift: undo and redo reconcile the Interactions preview with the restored document (#658).
// A history step that changes the document's machines stops the preview, like any machine edit, and an edited machine
// the document no longer has leaves nothing edited. A step that leaves the machines alone keeps the preview running.
import FlareCore
@testable import FlareModel
import Testing

private func previewing() -> FlareWorkspace {
    var w = FlareWorkspace(services: .fake())
    w.load(FlareFixtures.button)
    w.addMachine(named: "Button", firstStateLabel: "idle")
    w.startPreview()
    return w
}

@Test func undoingAddMachineStopsThePreviewAndClearsTheEditedMachine() {
    var w = previewing()
    #expect(w.machinePreview?.machineID == "machine-1")
    w.undo()
    #expect(w.machine == nil && w.machineID == nil && w.machinePreview == nil)
    w.advancePreview(frames: 1)
    #expect(w.machinePreview == nil)
}

@Test func undoingAnEditOfThePreviewedMachineStopsThePreviewButKeepsItEdited() {
    var w = FlareWorkspace(services: .fake())
    w.load(FlareFixtures.button)
    w.addMachine(named: "Button", firstStateLabel: "idle")
    w.addMachineState(fromLabel: "hover")
    w.setInitialMachineState("hover")
    w.startPreview()
    #expect(w.machinePreview?.stateID == "hover")
    w.undo()
    #expect(w.machinePreview == nil && w.machineID == "machine-1")
}

@Test func redoingRemoveMachineStopsThePreviewAndClearsTheEditedMachine() {
    var w = previewing()
    w.removeMachine("machine-1")
    w.undo()
    w.selectMachine("machine-1")
    w.startPreview()
    #expect(w.machinePreview != nil)
    w.redo()
    #expect(w.machine == nil && w.machineID == nil && w.machinePreview == nil)
}

@Test func undoingAnEditThatLeavesTheMachinesAloneKeepsThePreviewRunning() {
    var w = previewing()
    w.renameScene(w.selectedSceneID ?? "", to: "Renamed")
    w.startPreview()
    let running = w.machinePreview
    w.undo()
    #expect(running != nil && w.machinePreview == running && w.machineID == "machine-1")
}
