// InteractContracts.swift: state machine editing and preview (docs/blueprints/flare.md, 6.2). The engine
// refuses a bad edit (the throw names the rule); issues are only the warnings a valid machine can have.
import FlareCore

public struct MachineIssue: Hashable, Sendable {
    public var message: String              // "pressed can't be reached from idle."
    public var stateID: String?
    public var transitionIndex: Int?
    public init(message: String, stateID: String?, transitionIndex: Int?) {
        self.message = message; self.stateID = stateID; self.transitionIndex = transitionIndex
    }
}

public protocol StateMachineEditing: Sendable {
    func machines(_ document: Document) -> [StateMachine]
    /// From FlareCore's public `StateMachine.issues(in:)` (LC-11a).
    func issues(_ document: Document, machineID: String) -> [MachineIssue]
    /// Single. A machine is born with its first state, which becomes the initial state.
    func addMachine(named name: String, firstState: MachineState,
                    in engine: inout CommandEngine) throws -> String
    /// Single.
    func renameMachine(_ id: String, to name: String, in engine: inout CommandEngine) throws
    /// Single.
    func removeMachine(_ id: String, in engine: inout CommandEngine) throws
    /// Single.
    func addState(_ state: MachineState, to machineID: String, in engine: inout CommandEngine) throws
    /// Single.
    func updateState(_ state: MachineState, in machineID: String, in engine: inout CommandEngine) throws
    /// Single. Throws while a transition uses the state or it is the initial state.
    func removeState(_ stateID: String, from machineID: String, in engine: inout CommandEngine) throws
    /// Single.
    func addTransition(_ transition: FlareTransition, to machineID: String,
                       in engine: inout CommandEngine) throws
    /// Single. Replaces from, to, trigger and conditions.
    func updateTransition(at index: Int, to transition: FlareTransition, in machineID: String,
                          in engine: inout CommandEngine) throws
    /// Single.
    func removeTransition(at index: Int, from machineID: String, in engine: inout CommandEngine) throws
    /// Single.
    func addInput(_ input: MachineInput, to machineID: String, in engine: inout CommandEngine) throws
    /// Single. Replaces the input's default value (same name and kind).
    func updateInput(_ input: MachineInput, in machineID: String, in engine: inout CommandEngine) throws
    /// Single. Throws while a condition uses the input.
    func removeInput(named name: String, from machineID: String, in engine: inout CommandEngine) throws
    /// Single.
    func setInitialState(_ stateID: String, of machineID: String, in engine: inout CommandEngine) throws
}

/// The live preview's position in a machine (no document edits).
public struct MachinePreview: Equatable, Sendable {
    public var machineID: String
    public var stateID: String
    public var frame: Int                        // within the state's range
    public var inputs: [String: InputValue]
    public init(machineID: String, stateID: String, frame: Int, inputs: [String: InputValue]) {
        self.machineID = machineID; self.stateID = stateID; self.frame = frame; self.inputs = inputs
    }
}

public protocol StateMachinePreviewing: Sendable {
    func start(_ document: Document, machineID: String) throws -> MachinePreview
    func set(_ input: String, to value: InputValue, _ preview: MachinePreview,
             in document: Document) -> MachinePreview
    func fire(_ trigger: String, _ preview: MachinePreview, in document: Document) -> MachinePreview
    func advance(_ preview: MachinePreview, frames: Int, in document: Document) -> MachinePreview
}
