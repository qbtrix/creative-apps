// FlareMachines.swift: the Interactions editor's state on FlareWorkspace (docs/blueprints/flare.md, section 2 and
// 3.2): the edited machine, its issues and layout, states built from frame labels, and the live preview. Every edit
// goes through `services.machines` as one named undo step on the edited machine and stops the preview. A refusal
// leaves the document unchanged and puts its message in `machineError`, never in `layerError`.
import FlareCore

extension FlareWorkspace {
    /// The open document's machines; empty with none open.
    public var machines: [StateMachine] { document.map(services.machines.machines) ?? [] }

    /// The edited machine, while it exists (an undone Add Machine leaves `machineID` naming nothing).
    public var machine: StateMachine? { machines.first { $0.id == machineID } }

    /// The edited machine's warnings: states it can't reach and the like.
    public var machineIssues: [MachineIssue] {
        guard let document, let machine else { return [] }
        return services.machines.issues(document, machineID: machine.id)
    }

    /// Where the graph draws each state of the edited machine; nil with none.
    public var machineLayout: MachineLayout? { machine.map(MachineLayout.init) }

    /// A state named after frame label `label` of the selected scene, from its frame to the frame before the next
    /// label, or to the scene's last frame; nil when the scene has no such label.
    public func machineStateFromLabel(_ label: String) -> MachineState? {
        guard let scene = selectedScene, let start = scene.labels[label] else { return nil }
        let next = scene.labels.values.filter { $0 > start }.min()
        let end = next.map { $0 - 1 } ?? max(start, scene.durationFrames - 1)
        return MachineState(id: label, name: label, sceneID: scene.id, startFrame: start, endFrame: end)
    }

    /// Edits machine `id`; nil edits none. Switching machines stops the preview.
    public mutating func selectMachine(_ id: String?) {
        guard id != machineID else { return }
        guard id == nil || machines.contains(where: { $0.id == id }) else { return }
        (machineID, machineError) = (id, nil)
        stopPreview()
    }

    /// Adds a machine whose first, initial state comes from label `label`, and edits it.
    public mutating func addMachine(named name: String, firstStateLabel label: String) {
        guard let name = Self.machineName(name) else { return refuseMachine("Type a name for the machine.") }
        guard let state = machineStateFromLabel(label) else { return refuseMachine(Self.noLabel(label)) }
        var added: String?
        editMachines { added = try $0.addMachine(named: name, firstState: state, in: &$1) }
        if let added { (machineID, machineError) = (added, nil) }
    }

    /// Renames the edited machine. Surrounding whitespace is dropped; its current name adds no undo step.
    public mutating func renameMachine(to name: String) {
        guard let name = Self.machineName(name) else { return refuseMachine("Type a name for the machine.") }
        guard machine?.name != name else { return }
        editMachine { try $0.renameMachine($2, to: name, in: &$1) }
    }

    /// Removes the edited machine and edits the first one left, if any.
    public mutating func removeMachine() {
        editMachine { try $0.removeMachine($2, in: &$1) }
        if machineError == nil, machine == nil { machineID = machines.first?.id }
    }

    /// Adds a state from label `label` of the selected scene to the edited machine.
    public mutating func addState(fromLabel label: String) {
        guard let state = machineStateFromLabel(label) else { return refuseMachine(Self.noLabel(label)) }
        if let machine, machine.states.contains(where: { $0.id == state.id }) {
            return refuseMachine("\(machine.name) already has a state \(label).")
        }
        editMachine { try $0.addState(state, to: $2, in: &$1) }
    }

    public mutating func updateState(_ state: MachineState) {
        editMachine { try $0.updateState(state, in: $2, in: &$1) }
    }

    /// Refused while a transition uses the state or it is the initial state.
    public mutating func removeState(_ stateID: String) {
        editMachine { try $0.removeState(stateID, from: $2, in: &$1) }
    }

    public mutating func setInitialState(_ stateID: String) {
        editMachine { try $0.setInitialState(stateID, of: $2, in: &$1) }
    }

    public mutating func addTransition(_ transition: FlareTransition) {
        editMachine { try $0.addTransition(transition, to: $2, in: &$1) }
    }

    public mutating func updateTransition(at index: Int, to transition: FlareTransition) {
        editMachine { try $0.updateTransition(at: index, to: transition, in: $2, in: &$1) }
    }

    public mutating func removeTransition(at index: Int) {
        editMachine { try $0.removeTransition(at: index, from: $2, in: &$1) }
    }

    public mutating func addInput(_ input: MachineInput) {
        editMachine { try $0.addInput(input, to: $2, in: &$1) }
    }

    /// Replaces an input's default; a change of kind is refused.
    public mutating func updateInput(_ input: MachineInput) {
        editMachine { try $0.updateInput(input, in: $2, in: &$1) }
    }

    /// Refused while a condition uses the input.
    public mutating func removeInput(named name: String) {
        editMachine { try $0.removeInput(named: name, from: $2, in: &$1) }
    }

    /// Starts previewing the edited machine in its initial state with every input at its default.
    public mutating func startPreview() {
        guard let document, let id = machine?.id else { return refuseMachine(Self.noMachine) }
        do {
            machinePreview = try services.preview.start(document, machineID: id)
            machineError = nil
        } catch {
            refuseMachine(Self.message(error))
        }
    }

    public mutating func stopPreview() { machinePreview = nil }

    /// Sets a preview input, taking the transition it enables at once. No-op while not previewing.
    public mutating func setPreviewInput(_ name: String, to value: InputValue) {
        guard let document, let p = machinePreview else { return }
        machinePreview = services.preview.set(name, to: value, p, in: document)
    }

    public mutating func firePreview(_ trigger: String) {
        guard let document, let p = machinePreview else { return }
        machinePreview = services.preview.fire(trigger, p, in: document)
    }

    /// Moves the preview `frames` ticks through its state's range, looping.
    public mutating func advancePreview(frames: Int) {
        guard let document, let p = machinePreview else { return }
        machinePreview = services.preview.advance(p, frames: frames, in: document)
    }

    /// Runs `body` on the edited machine (its id is the third argument) as one step.
    private mutating func editMachine(_ body: (any StateMachineEditing, inout CommandEngine, String) throws -> Void) {
        guard let id = machine?.id else { return refuseMachine(engine == nil ? FlareLayerError.noDocument.message : Self.noMachine) }
        editMachines { try body($0, &$1, id) }
    }

    /// Runs `body` on a copy of the engine and commits it only if it succeeds; a commit stops the preview.
    private mutating func editMachines(_ body: (any StateMachineEditing, inout CommandEngine) throws -> Void) {
        guard var next = engine else { return refuseMachine(FlareLayerError.noDocument.message) }
        do { try body(services.machines, &next) } catch { return refuseMachine(Self.message(error)) }
        engine = next
        machineError = nil
        stopPreview()
    }

    private mutating func refuseMachine(_ message: String) { machineError = message }

    private static let noMachine = "Add or select a machine first."
    private static func noLabel(_ label: String) -> String { "The scene has no label \u{201C}\(label)\u{201D}." }

    private static func machineName(_ name: String) -> String? {
        let trimmed = String(name.drop(while: \.isWhitespace).reversed().drop(while: \.isWhitespace).reversed())
        return trimmed.isEmpty ? nil : trimmed
    }

    /// The sentence a refusal shows: the rule the fake or engine named, never debug text (#571).
    private static func message(_ error: any Error) -> String {
        switch error {
        case CommandError.invalidDocument(let reason): reason
        case let error as NotBuilt: error.reason
        default: "The machine could not be changed."
        }
    }
}
