// FakeMachines.swift: StateMachineEditing over `Document.stateMachines` (docs/blueprints/flare.md, 6.3). FlareCore has
// no machine commands yet (LC-11b–e), so every edit swaps in an edited copy through `FixtureEdit`, one named step,
// and the engine's own validation still refuses a dangling transition, an unknown scene or a bad range. The fake also
// refuses what those commands will, by name: removing a state a transition uses or the initial state, removing an
// input a condition uses, and changing an input's kind. Issues are the unreachable states, from `MachineLayout`. With
// `unavailable` set, reads are empty and every write throws that reason.
import FlareCore

public struct FakeMachines: StateMachineEditing {
    /// Why this member is off; nil when it works.
    public var unavailable: String?
    public init(unavailable: String? = nil) { self.unavailable = unavailable }
    private func available() throws { if let unavailable { throw NotBuilt(reason: unavailable) } }

    public func machines(_ document: Document) -> [StateMachine] { unavailable == nil ? document.stateMachines : [] }

    public func issues(_ document: Document, machineID: String) -> [MachineIssue] {
        guard let machine = machines(document).first(where: { $0.id == machineID }) else { return [] }
        let start = Self.name(machine.initialState, in: machine)
        return MachineLayout(machine).nodes.filter(\.isUnreachable).map {
            MachineIssue(message: "\(Self.name($0.stateID, in: machine)) can't be reached from \(start).",
                         stateID: $0.stateID, transitionIndex: nil)
        }
    }

    public func addMachine(named name: String, firstState: MachineState, in engine: inout CommandEngine) throws -> String {
        try available()
        // The smallest n that no machine uses as an id.
        var n = 1
        while engine.document.stateMachines.contains(where: { $0.id == "machine-\(n)" }) { n += 1 }
        let id = "machine-\(n)"
        try engine.perform(FixtureEdit("Add Machine", from: engine.document) {
            $0.stateMachines.append(StateMachine(id: id, name: name, states: [firstState], initialState: firstState.id))
        })
        return id
    }

    public func renameMachine(_ id: String, to name: String, in engine: inout CommandEngine) throws {
        try edit("Rename Machine", id, &engine) { $0.name = name }
    }

    public func removeMachine(_ id: String, in engine: inout CommandEngine) throws {
        try available()
        guard engine.document.stateMachines.contains(where: { $0.id == id }) else { throw Self.noMachine(id) }
        try engine.perform(FixtureEdit("Remove Machine", from: engine.document) { $0.stateMachines.removeAll { $0.id == id } })
    }

    public func addState(_ state: MachineState, to machineID: String, in engine: inout CommandEngine) throws {
        try edit("Add State", machineID, &engine) { $0.states.append(state) }
    }

    public func updateState(_ state: MachineState, in machineID: String, in engine: inout CommandEngine) throws {
        try edit("Edit State", machineID, &engine) { m in
            guard let i = m.states.firstIndex(where: { $0.id == state.id }) else { throw Self.noState(state.id) }
            m.states[i] = state
        }
    }

    public func removeState(_ stateID: String, from machineID: String, in engine: inout CommandEngine) throws {
        try edit("Remove State", machineID, &engine) { m in
            guard m.states.contains(where: { $0.id == stateID }) else { throw Self.noState(stateID) }
            let name = Self.name(stateID, in: m)
            if let t = m.transitions.first(where: { $0.from == stateID || $0.to == stateID }) {
                throw CommandError.invalidDocument("\(name) is used by the transition \(Self.arrow(t, in: m)).")
            }
            guard m.initialState != stateID else { throw CommandError.invalidDocument("\(name) is the initial state.") }
            m.states.removeAll { $0.id == stateID }
        }
    }

    public func addTransition(_ transition: FlareTransition, to machineID: String, in engine: inout CommandEngine) throws {
        try edit("Add Transition", machineID, &engine) { $0.transitions.append(transition) }
    }

    public func updateTransition(at index: Int, to transition: FlareTransition, in machineID: String,
                                 in engine: inout CommandEngine) throws {
        try edit("Edit Transition", machineID, &engine) { m in
            guard m.transitions.indices.contains(index) else { throw CommandError.invalidIndex(index) }
            m.transitions[index] = transition
        }
    }

    public func removeTransition(at index: Int, from machineID: String, in engine: inout CommandEngine) throws {
        try edit("Remove Transition", machineID, &engine) { m in
            guard m.transitions.indices.contains(index) else { throw CommandError.invalidIndex(index) }
            m.transitions.remove(at: index)
        }
    }

    public func addInput(_ input: MachineInput, to machineID: String, in engine: inout CommandEngine) throws {
        try edit("Add Input", machineID, &engine) { $0.inputs.append(input) }
    }

    public func updateInput(_ input: MachineInput, in machineID: String, in engine: inout CommandEngine) throws {
        try edit("Edit Input", machineID, &engine) { m in
            guard let i = m.inputs.firstIndex(where: { $0.name == input.name }) else { throw Self.noInput(input.name) }
            switch (m.inputs[i].defaultValue, input.defaultValue) {
            case (.bool, .bool), (.number, .number): m.inputs[i] = input
            case (.bool, _): throw CommandError.invalidDocument("\(input.name) is a true or false input.")
            case (.number, _): throw CommandError.invalidDocument("\(input.name) is a number input.")
            }
        }
    }

    public func removeInput(named name: String, from machineID: String, in engine: inout CommandEngine) throws {
        try edit("Remove Input", machineID, &engine) { m in
            guard m.inputs.contains(where: { $0.name == name }) else { throw Self.noInput(name) }
            if let t = m.transitions.first(where: { $0.conditions.contains { $0.input == name } }) {
                throw CommandError.invalidDocument("\(name) is used by the transition \(Self.arrow(t, in: m)).")
            }
            m.inputs.removeAll { $0.name == name }
        }
    }

    public func setInitialState(_ stateID: String, of machineID: String, in engine: inout CommandEngine) throws {
        try edit("Set Initial State", machineID, &engine) { $0.initialState = stateID }
    }

    /// Runs `body` on the machine `id` as one step named `label`; throws when the machine is missing.
    private func edit(_ label: String, _ id: String, _ engine: inout CommandEngine,
                      _ body: (inout StateMachine) throws -> Void) throws {
        try available()
        try engine.perform(FixtureEdit(label, from: engine.document) { doc in
            guard let i = doc.stateMachines.firstIndex(where: { $0.id == id }) else { throw Self.noMachine(id) }
            try body(&doc.stateMachines[i])
        })
    }

    static func name(_ stateID: String, in machine: StateMachine) -> String {
        machine.states.first { $0.id == stateID }?.name ?? stateID
    }

    /// "idle → hover", by state name.
    static func arrow(_ t: FlareTransition, in machine: StateMachine) -> String {
        "\(name(t.from, in: machine)) → \(name(t.to, in: machine))"
    }

    static func noMachine(_ id: String) -> CommandError { .invalidDocument("No machine \(id).") }
    private static func noState(_ id: String) -> CommandError { .invalidDocument("No state \(id).") }
    private static func noInput(_ name: String) -> CommandError { .invalidDocument("No input \(name).") }
}
