// MachineFakesTests.swift: the LM-0c2 fake machines and preview on `button` (docs/blueprints/flare.md, 7.1). The
// acceptance test: `addMachine` makes the first state initial; removing a state a transition uses throws a message
// naming the transition and changes nothing; an unreachable state is a warning on that state; preview goes idle to
// hover on `hover = true`. The quality rows: one named undo step per edit (QB-F3), a refusal that names its rule and
// changes nothing (QB-F2), the switch returned by the same `set` call (so the next tick draws it), and model budgets.
import FlareCore
@testable import FlareModel
import Testing

private let services = FlareServices.fake()
private let machines = services.machines
private let preview = services.preview

private func state(_ id: String, _ start: Int, _ end: Int) -> MachineState {
    MachineState(id: id, name: id, sceneID: "scene-1", startFrame: start, endFrame: end)
}

@Test func buttonHasThreeLabelsAndNoMachineAndTheMachineVariantIsJ19sResult() throws {
    let button = FlareFixtures.button, wired = FlareFixtures.buttonWithMachine
    try FlareFormat.validate(button)
    try FlareFormat.validate(wired)
    #expect(FlareFixtures.named("button") == button && FlareFixtures.named("button with machine") == wired)
    #expect(button.scenes.first?.labels == ["idle": 0, "hover": 24, "pressed": 48] && button.stateMachines.isEmpty)
    let machine = try #require(wired.stateMachines.first)
    #expect(machine.name == "Hover button" && machine.initialState == "idle")
    #expect(machine.states.map(\.id) == ["idle", "hover", "pressed"] && machines.issues(wired, machineID: machine.id).isEmpty)
}

@Test func addMachineMakesTheFirstStateInitialInOneNamedStep() throws {
    var e = CommandEngine(document: FlareFixtures.button)
    let id = try machines.addMachine(named: "Button", firstState: state("idle", 0, 23), in: &e)
    #expect(machines.machines(e.document).map(\.initialState) == ["idle"] && e.undoActionName == "Undo Add Machine")
    let second = try machines.addMachine(named: "Other", firstState: state("hover", 24, 47), in: &e)
    #expect(id == "machine-1" && second == "machine-2")
    try machines.renameMachine(id, to: "Hover button", in: &e)
    #expect(e.document.stateMachines.first?.name == "Hover button" && e.undoActionName == "Undo Rename Machine")
    try machines.removeMachine(second, in: &e)
    #expect(e.document.stateMachines.map(\.id) == [id])
    while e.canUndo { try e.undo() }
    #expect(e.document == FlareFixtures.button)
    // A state outside the scene is the engine's refusal; nothing is added.
    #expect(throws: CommandError.self) { try machines.addMachine(named: "Bad", firstState: state("x", 0, 500), in: &e) }
    #expect(e.document == FlareFixtures.button && !e.canUndo)
}

@Test func removingAStateATransitionUsesIsRefusedNamingItAndChangesNothing() throws {
    var e = CommandEngine(document: FlareFixtures.buttonWithMachine)
    let before = e.document
    #expect(throws: CommandError.invalidDocument("hover is used by the transition idle → hover.")) {
        try machines.removeState("hover", from: "machine-1", in: &e)
    }
    #expect(throws: CommandError.invalidDocument("hover is used by the transition idle → hover.")) {
        try machines.removeInput(named: "hover", from: "machine-1", in: &e)
    }
    #expect(e.document == before && !e.canUndo)
    // Once its transition goes, pressed is unused: removing it is one step. The initial state is refused even unused.
    try machines.removeTransition(at: 2, from: "machine-1", in: &e)
    try machines.removeState("pressed", from: "machine-1", in: &e)
    #expect(e.document.stateMachines.first?.states.map(\.id) == ["idle", "hover"] && e.undoActionName == "Undo Remove State")
    let lone = try machines.addMachine(named: "Lone", firstState: state("idle", 0, 23), in: &e)
    #expect(throws: CommandError.invalidDocument("idle is the initial state.")) {
        try machines.removeState("idle", from: lone, in: &e)
    }
}

@Test func anUnreachableStateIsAWarningOnThatState() throws {
    var e = CommandEngine(document: FlareFixtures.button)
    let id = try machines.addMachine(named: "Button", firstState: state("idle", 0, 23), in: &e)
    try machines.addState(state("hover", 24, 47), to: id, in: &e)
    try machines.addState(state("pressed", 48, 71), to: id, in: &e)
    try machines.addTransition(FlareTransition(from: "idle", to: "hover", trigger: "pointer"), to: id, in: &e)
    #expect(machines.issues(e.document, machineID: id)
        == [MachineIssue(message: "pressed can't be reached from idle.", stateID: "pressed", transitionIndex: nil)])
    try machines.addTransition(FlareTransition(from: "hover", to: "pressed", trigger: "click"), to: id, in: &e)
    #expect(machines.issues(e.document, machineID: id).isEmpty && machines.issues(e.document, machineID: "nope").isEmpty)
}

@Test func transitionsInputsAndInitialStateEditInOneStepEachAndUndoExactly() throws {
    var e = CommandEngine(document: FlareFixtures.buttonWithMachine)
    let m = "machine-1"
    let cond = Condition(input: "hover", op: .equal, value: .bool(false))
    try machines.updateTransition(at: 0, to: FlareTransition(from: "idle", to: "hover", trigger: "pointer", conditions: [cond]),
                                  in: m, in: &e)
    #expect(e.document.stateMachines.first?.transitions.first?.conditions == [cond] && e.undoActionName == "Undo Edit Transition")
    try machines.updateInput(MachineInput(name: "hover", defaultValue: .bool(true)), in: m, in: &e)
    #expect(e.document.stateMachines.first?.inputs.first?.defaultValue == .bool(true))
    try machines.addInput(MachineInput(name: "speed", defaultValue: .number(1)), to: m, in: &e)
    try machines.removeInput(named: "speed", from: m, in: &e)
    try machines.setInitialState("pressed", of: m, in: &e)
    #expect(e.document.stateMachines.first?.initialState == "pressed" && e.undoActionName == "Undo Set Initial State")
    try machines.updateState(MachineState(id: "pressed", name: "Pressed", sceneID: "scene-1", startFrame: 48, endFrame: 60), in: m, in: &e)
    try machines.removeTransition(at: 1, from: m, in: &e)
    let before = e.document
    // A kind change, a missing index and an unknown state are refused with nothing changed.
    #expect(throws: CommandError.self) { try machines.updateInput(MachineInput(name: "hover", defaultValue: .number(1)), in: m, in: &e) }
    #expect(throws: CommandError.invalidIndex(9)) { try machines.removeTransition(at: 9, from: m, in: &e) }
    #expect(throws: CommandError.self) { try machines.addTransition(FlareTransition(from: "idle", to: "nope", trigger: "x"), to: m, in: &e) }
    #expect(e.document == before)
    while e.canUndo { try e.undo() }
    #expect(e.document == FlareFixtures.buttonWithMachine)
}

@Test func previewGoesIdleToHoverOnHoverTrueAndBackAndLoopsEachRange() throws {
    let doc = FlareFixtures.buttonWithMachine
    var p = try preview.start(doc, machineID: "machine-1")
    #expect(p == MachinePreview(machineID: "machine-1", stateID: "idle", frame: 0, inputs: ["hover": .bool(false)]))
    p = preview.advance(p, frames: 30, in: doc)
    #expect(p.stateID == "idle" && p.frame == 6)
    p = preview.set("hover", to: .bool(true), p, in: doc)
    #expect(p.stateID == "hover" && p.frame == 24 && p.inputs["hover"] == .bool(true))
    p = preview.fire("click", p, in: doc)
    #expect(p.stateID == "pressed" && p.frame == 48)
    p = preview.advance(p, frames: -1, in: doc)
    #expect(p.frame == 71)
    p = preview.fire("nothing", p, in: doc)
    #expect(p.stateID == "pressed")
    p = preview.set("hover", to: .bool(false), try preview.start(doc, machineID: "machine-1"), in: doc)
    #expect(p.stateID == "idle")
    #expect(throws: CommandError.self) { try preview.start(doc, machineID: "nope") }
}

@Test func unavailableFakesAreEmptyAndThrowTheirReason() throws {
    let off = FakeMachines(unavailable: "Off."), offPreview = FakePreview(unavailable: "Off.")
    var e = CommandEngine(document: FlareFixtures.buttonWithMachine)
    #expect(off.machines(e.document).isEmpty && off.issues(e.document, machineID: "machine-1").isEmpty)
    #expect(throws: NotBuilt(reason: "Off.")) { try off.addMachine(named: "B", firstState: state("idle", 0, 23), in: &e) }
    #expect(throws: NotBuilt(reason: "Off.")) { try offPreview.start(e.document, machineID: "machine-1") }
    #expect(e.document == FlareFixtures.buttonWithMachine)
}

@Test func editsAndPreviewStepsStayWithinTheirModelBudgets() throws {
    // QB-L7's debug bound for a step through the engine (≤ 10 ms), and the preview's tick, which must fit a frame.
    var e = CommandEngine(document: FlareFixtures.buttonWithMachine)
    let clock = ContinuousClock()
    let edit = clock.measure {
        for i in 0..<100 { try? machines.renameMachine("machine-1", to: "Name \(i)", in: &e) }
    }
    #expect(edit / 100 < .milliseconds(10))
    let doc = FlareFixtures.buttonWithMachine
    var p = try preview.start(doc, machineID: "machine-1")
    let ticks = clock.measure {
        for i in 0..<1_000 {
            p = preview.set("hover", to: .bool(i % 2 == 0), p, in: doc)
            p = preview.advance(p, frames: 1, in: doc)
        }
    }
    #expect(ticks / 1_000 < .milliseconds(1))
}
