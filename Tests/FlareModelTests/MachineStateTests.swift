// MachineStateTests.swift: the Interactions editor's state on FlareWorkspace (LM-0c2b, #605) over the fake machines
// and preview. The acceptance test: J19 from labels on `button`, the refused Remove State, and the preview on `button
// with machine`. The quality rows: one named undo step per edit (QB-F3), a refusal that says why where it happened and
// changes nothing (QB-F2), the switch on the next tick, and model budgets (QB-L7's debug bound).
import FlareCore
@testable import FlareModel
import Testing

private func workspace(_ document: Document) -> FlareWorkspace {
    var w = FlareWorkspace(services: .fake())
    w.load(document)
    return w
}

@Test func j19BuildsAMachineFromLabelsAndRefusesRemovingAUsedStateInMachineError() throws {
    var w = workspace(FlareFixtures.button)
    #expect(w.machines.isEmpty && w.machine == nil && w.machineLayout == nil && w.machineIssues.isEmpty)
    w.addMachine(named: "Button", firstStateLabel: "idle")
    #expect(w.machineID == "machine-1" && w.machine?.initialState == "idle" && w.undoActionName == "Undo Add Machine")
    w.addState(fromLabel: "hover")
    w.addState(fromLabel: "pressed")
    let machine = try #require(w.machine)
    #expect(machine.states.count == 3 && machine.initialState == "idle")
    #expect(w.machineLayout?.nodes.map(\.column) == [0, 1, 1] && w.machineIssues.count == 2)
    w.renameMachine(to: "Hover button")
    #expect(w.machine?.name == "Hover button" && w.undoActionName == "Undo Rename Machine")
    #expect(w.document == FlareFixtures.buttonWithStates && w.machineError == nil)

    w.addTransition(FlareTransition(from: "idle", to: "hover", trigger: "pointer"))
    let before = w.document, undoName = w.undoActionName
    w.removeState("hover")
    #expect(w.machineError == "hover is used by the transition idle → hover.")
    #expect(w.document == before && w.undoActionName == undoName && w.layerError == nil)
}

@Test func statesComeFromLabelsAndEndBeforeTheNextOrAtTheScenesLastFrame() {
    let w = workspace(FlareFixtures.button)
    #expect(w.machineStateFromLabel("idle") == MachineState(id: "idle", name: "idle", sceneID: "scene-1", startFrame: 0, endFrame: 23))
    #expect(w.machineStateFromLabel("hover")?.endFrame == 47)
    #expect(w.machineStateFromLabel("pressed")?.endFrame == 71)
    #expect(w.machineStateFromLabel("nope") == nil && FlareWorkspace(services: .fake()).machineStateFromLabel("idle") == nil)
}

@Test func previewSwitchesOnTheSameCallTicksThroughTheRangeAndAnyEditStopsIt() {
    var w = workspace(FlareFixtures.buttonWithMachine)
    w.selectMachine("machine-1")
    w.startPreview()
    #expect(w.machinePreview?.stateID == "idle" && w.machinePreview?.frame == 0)
    w.setPreviewInput("hover", to: .bool(true))
    #expect(w.machinePreview?.stateID == "hover" && w.machinePreview?.frame == 24)
    w.advancePreview(frames: 1)
    #expect(w.machinePreview?.frame == 25)
    w.firePreview("click")
    #expect(w.machinePreview?.stateID == "pressed")
    let document = w.document
    w.renameMachine(to: "Renamed")
    #expect(w.machinePreview == nil && w.machine?.name == "Renamed")
    // A preview never edits the document or the undo stack.
    w.startPreview()
    w.advancePreview(frames: 5)
    w.selectMachine(nil)
    #expect(w.machinePreview == nil && w.machine == nil)
    w.undo()
    #expect(w.document == document)
}

@Test func transitionsInputsAndInitialStateEachTakeOneNamedStep() {
    var w = workspace(FlareFixtures.buttonWithMachine)
    w.selectMachine("machine-1")
    let steps: [(String, (inout FlareWorkspace) -> Void)] = [
        ("Add Input", { $0.addInput(MachineInput(name: "speed", defaultValue: .number(1))) }),
        ("Edit Input", { $0.updateInput(MachineInput(name: "speed", defaultValue: .number(2))) }),
        ("Remove Input", { $0.removeInput(named: "speed") }),
        ("Edit Transition", { $0.updateTransition(at: 2, to: FlareTransition(from: "hover", to: "pressed", trigger: "tap")) }),
        ("Remove Transition", { $0.removeTransition(at: 2) }),
        ("Edit State", { $0.updateState(MachineState(id: "pressed", name: "Pressed", sceneID: "scene-1", startFrame: 48, endFrame: 60)) }),
        ("Set Initial State", { $0.setInitialState("hover") }),
        ("Remove State", { $0.removeState("pressed") }),
    ]
    for (name, edit) in steps {
        edit(&w)
        #expect(w.undoActionName == "Undo \(name)" && w.machineError == nil, "\(name)")
    }
    for _ in steps { w.undo() }
    #expect(w.document == FlareFixtures.buttonWithMachine && !w.canUndo)
}

@Test func refusalsSayWhyInMachineErrorAndChangeNothing() {
    var none = FlareWorkspace(services: .fake())
    none.addMachine(named: "Button", firstStateLabel: "idle")
    #expect(none.machineError == "The scene has no label \u{201C}idle\u{201D}." && none.layerError == nil)
    var w = workspace(FlareFixtures.buttonWithMachine)
    w.addInput(MachineInput(name: "x", defaultValue: .bool(true)))
    #expect(w.machineError == "Add or select a machine first.")
    w.startPreview()
    #expect(w.machineError == "Add or select a machine first." && w.machinePreview == nil)
    w.addMachine(named: "  ", firstStateLabel: "idle")
    #expect(w.machineError == "Type a name for the machine.")
    w.selectMachine("machine-1")
    #expect(w.machineError == nil)
    w.addState(fromLabel: "hover")
    #expect(w.machineError == "Hover button already has a state hover.")
    w.updateInput(MachineInput(name: "hover", defaultValue: .number(1)))
    #expect(w.machineError == "hover is a true or false input.")
    w.removeInput(named: "hover")
    #expect(w.machineError == "hover is used by the transition idle → hover.")
    w.renameMachine(to: "Hover button")
    w.selectMachine("nope")
    #expect(w.machineID == "machine-1" && w.document == FlareFixtures.buttonWithMachine && !w.canUndo && w.layerError == nil)
    // A service that is off says its reason.
    var off = FlareServices.fake()
    off.machines = FakeMachines(unavailable: "Not connected yet (IN-6).")
    var o = FlareWorkspace(services: off)
    o.load(FlareFixtures.button)
    o.addMachine(named: "Button", firstStateLabel: "idle")
    #expect(o.machineError == "Not connected yet (IN-6)." && o.machineID == nil && !o.canUndo)
}

@Test func removingTheEditedMachineEditsTheNextAndUndoLeavesNoStaleMachine() {
    var w = workspace(FlareFixtures.buttonWithMachine)
    w.addMachine(named: "Second", firstStateLabel: "hover")
    #expect(w.machineID == "machine-2" && w.machines.count == 2)
    w.removeMachine()
    #expect(w.machineID == "machine-1" && w.undoActionName == "Undo Remove Machine")
    w.undo(); w.selectMachine("machine-2"); w.undo()
    #expect(w.machine == nil && w.machineLayout == nil && w.machineIssues.isEmpty)
}

@Test func machineEditsAndPreviewTicksStayWithinTheirModelBudgets() {
    // QB-L7's debug bound for one step through the engine (≤ 10 ms), and a preview tick well inside a frame.
    var w = workspace(FlareFixtures.buttonWithMachine)
    w.selectMachine("machine-1")
    let clock = ContinuousClock()
    let edits = clock.measure { for i in 0..<100 { w.renameMachine(to: "Name \(i)") } }
    #expect(edits / 100 < .milliseconds(10))
    w.startPreview()
    let ticks = clock.measure {
        for i in 0..<1_000 {
            w.setPreviewInput("hover", to: .bool(i % 2 == 0))
            w.advancePreview(frames: 1)
        }
    }
    #expect(ticks / 1_000 < .milliseconds(1) && w.machinePreview != nil)
}
