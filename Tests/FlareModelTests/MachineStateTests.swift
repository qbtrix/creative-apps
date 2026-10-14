// MachineStateTests.swift: the Interactions editor's state on FlareWorkspace (FlareMachines.swift, #605). The
// acceptance test is J19 from labels on `button` and the preview on `button with machine`; the quality rows are one
// named undo step per edit (QB-F3), a refusal in `machineError` that changes nothing (QB-F2), the preview switch on
// the next tick, and the model budgets (QB-L7's 10 ms debug bound per step, a preview tick inside 1 ms).
import FlareCore
@testable import FlareModel
import Testing

private func open(_ document: Document) -> FlareWorkspace {
    var workspace = FlareWorkspace(services: .fake())
    workspace.load(document)
    return workspace
}

/// How many steps undo walks back, leaving `w` as it was.
private func undoDepth(_ w: FlareWorkspace) -> Int {
    var copy = w, n = 0
    while copy.canUndo { copy.undo(); n += 1 }
    return n
}

@Test func j19BuildsTheMachineFromLabelsThenRefusesRemovingAStateATransitionUses() {
    var w = open(FlareFixtures.button)
    #expect(w.machines.isEmpty && w.machine == nil && w.machineLayout == nil)
    w.addMachine(named: "Button", firstStateLabel: "idle")
    w.addMachineState(fromLabel: "hover")
    w.addMachineState(fromLabel: "pressed")
    let m = w.machine
    #expect(m?.states.map(\.id) == ["idle", "hover", "pressed"] && m?.initialState == "idle")
    #expect(w.machineLayout?.nodes.map(\.column) == [0, 1, 1])
    #expect(w.machineIssues.count == 2 && w.machineIssues.map(\.stateID) == ["hover", "pressed"])
    w.renameMachine("machine-1", to: "  Hover button ")
    #expect(w.document == FlareFixtures.buttonWithStates && w.machineError == nil)
    #expect(undoDepth(w) == 4 && w.undoActionName == "Undo Rename Machine")

    w.addMachineTransition(FlareTransition(from: "idle", to: "hover", trigger: "pointer"))
    let before = w.document, undoName = w.undoActionName
    w.removeMachineState("hover")
    #expect(w.machineError == "hover is used by the transition idle → hover.")
    #expect(w.document == before && w.undoActionName == undoName && w.layerError == nil)
}

@Test func statesFromLabelsEndBeforeTheNextLabelOrAtTheLastFrame() {
    let w = open(FlareFixtures.button)
    #expect(w.machineStateFromLabel("idle")
        == MachineState(id: "idle", name: "idle", sceneID: "scene-1", startFrame: 0, endFrame: 23))
    #expect(w.machineStateFromLabel("pressed")?.endFrame == 71)
    #expect(w.machineStateFromLabel("missing") == nil)
}

@Test func refusalsGoToMachineErrorAndChangeNothing() {
    var w = open(FlareFixtures.buttonWithMachine)
    let doc = w.document
    w.addMachineState(fromLabel: "hover")
    #expect(w.machineError == "Select a machine first.")
    w.addMachine(named: "  ", firstStateLabel: "idle")
    #expect(w.machineError == "Type a name for the machine.")
    w.addMachine(named: "Other", firstStateLabel: "nope")
    #expect(w.machineError == "This scene has no frame label \u{201C}nope\u{201D}.")
    w.selectMachine("missing")
    #expect(w.machineID == nil)
    w.selectMachine("machine-1")
    #expect(w.machineError == nil && w.machine?.name == "Hover button")
    w.removeMachineInput(named: "hover")
    #expect(w.machineError == "hover is used by the transition idle → hover.")
    w.updateMachineInput(MachineInput(name: "hover", defaultValue: .number(1)))
    #expect(w.machineError == "hover is a true or false input.")
    w.removeMachineState("idle")
    #expect(w.machineError == "idle is used by the transition idle → hover.")
    #expect(w.document == doc && !w.canUndo && w.layerError == nil)
    w.removeMachineTransition(at: 2)
    #expect(w.machineError == nil && w.machine?.transitions.count == 2 && w.undoActionName == "Undo Remove Transition")
}

@Test func eachEditIsOneNamedUndoStep() {
    var w = open(FlareFixtures.buttonWithStates)
    w.selectMachine("machine-1")
    let edits: [(String, (inout FlareWorkspace) -> Void)] = [
        ("Add Input", { $0.addMachineInput(MachineInput(name: "hover", defaultValue: .bool(false))) }),
        ("Edit Input", { $0.updateMachineInput(MachineInput(name: "hover", defaultValue: .bool(true))) }),
        ("Add Transition", { $0.addMachineTransition(FlareTransition(from: "idle", to: "hover", trigger: "pointer")) }),
        ("Edit Transition", { $0.updateMachineTransition(at: 0, to: FlareTransition(from: "idle", to: "pressed", trigger: "click")) }),
        ("Set Initial State", { $0.setInitialMachineState("hover") }),
        ("Edit State", { w in
            if var s = w.machine?.states.last { s.name = "down"; w.updateMachineState(s) }
        }),
        ("Remove Transition", { $0.removeMachineTransition(at: 0) }),
        ("Remove Input", { $0.removeMachineInput(named: "hover") }),
        ("Remove Machine", { $0.removeMachine("machine-1") }),
    ]
    for (n, (label, edit)) in edits.enumerated() {
        edit(&w)
        #expect(w.machineError == nil && w.undoActionName == "Undo \(label)" && undoDepth(w) == n + 1, "\(label)")
    }
    #expect(w.machines.isEmpty && w.machineID == nil && w.machine == nil)
    w.undo()
    #expect(w.machine == nil && w.machines.first?.states.last?.name == "down" && w.machines.first?.initialState == "hover")
}

@Test func previewSwitchesOnTheInputAndShowsTheNextFrameOnTheNextTick() {
    var w = open(FlareFixtures.buttonWithMachine)
    w.startPreview()
    #expect(w.machinePreview == nil && w.machineError == "Select a machine first.")
    w.selectMachine("machine-1")
    w.startPreview()
    #expect(w.machinePreview?.stateID == "idle" && w.machinePreview?.inputs == ["hover": .bool(false)] && w.machineError == nil)
    w.setPreviewInput("hover", to: .bool(true))
    #expect(w.machinePreview?.stateID == "hover" && w.machinePreview?.frame == 24)
    w.advancePreview(frames: 1)
    #expect(w.machinePreview?.frame == 25)
    w.firePreview("click")
    #expect(w.machinePreview?.stateID == "pressed")
    let doc = w.document
    w.renameMachine("machine-1", to: "Renamed")
    #expect(w.machinePreview == nil && w.document != doc)
    w.advancePreview(frames: 1)
    #expect(w.machinePreview == nil)
}

@Test func anUnavailableServiceRefusesWithItsReason() {
    var w = FlareWorkspace(services: .live)
    w.load(FlareFixtures.buttonWithMachine)
    #expect(w.machines.isEmpty)
    w.addMachine(named: "Button", firstStateLabel: "idle")
    #expect(w.machineError == "Not connected yet (IN-6)." && w.document == FlareFixtures.buttonWithMachine)
}

@Test func machineEditsAndPreviewTicksStayWithinTheirModelBudgets() {
    var w = open(FlareFixtures.buttonWithMachine)
    w.selectMachine("machine-1")
    let clock = ContinuousClock()
    let edits = clock.measure {
        for i in 0..<100 { w.renameMachine("machine-1", to: "Name \(i)") }
    }
    #expect(edits / 100 < .milliseconds(10) && w.machine?.name == "Name 99")
    w.startPreview()
    let ticks = clock.measure {
        for i in 0..<1_000 {
            w.setPreviewInput("hover", to: .bool(i % 2 == 0))
            w.advancePreview(frames: 1)
        }
    }
    #expect(ticks / 1_000 < .milliseconds(1) && w.machinePreview != nil)
}
