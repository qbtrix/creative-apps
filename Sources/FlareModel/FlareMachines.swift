// FlareMachines.swift: the Interactions editor's state on FlareWorkspace (docs/blueprints/flare.md, section 2, LM-0c2):
// the machine being edited, its states from frame labels, transitions and inputs, and the live preview. Every edit
// goes through `services.machines` as one named undo step and stops the preview. A refusal changes nothing and puts
// its message in `machineError`, never in `layerError`; the next edit that succeeds clears it.
import FlareCore

extension FlareWorkspace {
    /// The open document's machines; empty with no document.
    public var machines: [StateMachine] { document.map(services.machines.machines) ?? [] }

    /// The machine being edited, while the document still has it.
    public var machine: StateMachine? { machines.first { $0.id == machineID } }

    /// The edited machine's warnings, for the graph.
    public var machineIssues: [MachineIssue] {
        guard let document, let id = machine?.id else { return [] }
        return services.machines.issues(document, machineID: id)
    }

    /// Where the graph draws the edited machine's states; nil with none edited.
    public var machineLayout: MachineLayout? { machine.map(MachineLayout.init) }

    /// A state named after `label` on the selected scene, from the label's frame up to the frame before the next
    /// label, or the scene's last frame; nil when the scene has no such label.
    public func machineStateFromLabel(_ label: String) -> MachineState? {
        guard let scene = selectedScene, let start = scene.labels[label] else { return nil }
        let next = scene.labels.values.filter { $0 > start }.min()
        let end = max(start, next.map { $0 - 1 } ?? scene.durationFrames - 1)
        return MachineState(id: label, name: label, sceneID: scene.id, startFrame: start, endFrame: end)
    }

    /// Edits machine `id`; an id the document doesn't have is ignored. Stops the preview.
    public mutating func selectMachine(_ id: String) {
        guard machines.contains(where: { $0.id == id }) else { return }
        stopPreview()
        (machineID, machineError) = (id, nil)
    }

    /// Adds a machine whose first state, the initial one, comes from `firstStateLabel`, and edits it.
    public mutating func addMachine(named name: String, firstStateLabel: String) {
        guard let name = Self.machineName(name) else { return refuseMachine(Self.emptyMachineName) }
        guard let first = machineStateFromLabel(firstStateLabel) else { return refuseMachine(Self.noLabel(firstStateLabel)) }
        var added: String?
        machineStep { added = try $0.addMachine(named: name, firstState: first, in: &$1) }
        if let added { machineID = added }
    }

    /// Renames machine `id`. Surrounding whitespace is dropped; a blank name is refused.
    public mutating func renameMachine(_ id: String, to name: String) {
        guard let name = Self.machineName(name) else { return refuseMachine(Self.emptyMachineName) }
        machineStep { try $0.renameMachine(id, to: name, in: &$1) }
    }

    /// Removes machine `id`; removing the edited one leaves nothing edited.
    public mutating func removeMachine(_ id: String) {
        machineStep { try $0.removeMachine(id, in: &$1) }
        if machineError == nil, machineID == id { machineID = nil }
    }

    /// Adds a state from the selected scene's frame label `label` to the edited machine.
    public mutating func addMachineState(fromLabel label: String) {
        guard let state = machineStateFromLabel(label) else { return refuseMachine(Self.noLabel(label)) }
        editMachine { try $0.addState(state, to: $1, in: &$2) }
    }

    public mutating func updateMachineState(_ state: MachineState) {
        editMachine { try $0.updateState(state, in: $1, in: &$2) }
    }

    /// Refused while a transition uses the state or it is the initial state.
    public mutating func removeMachineState(_ stateID: String) {
        editMachine { try $0.removeState(stateID, from: $1, in: &$2) }
    }

    public mutating func setInitialMachineState(_ stateID: String) {
        editMachine { try $0.setInitialState(stateID, of: $1, in: &$2) }
    }

    public mutating func addMachineTransition(_ transition: FlareTransition) {
        editMachine { try $0.addTransition(transition, to: $1, in: &$2) }
    }

    public mutating func updateMachineTransition(at index: Int, to transition: FlareTransition) {
        editMachine { try $0.updateTransition(at: index, to: transition, in: $1, in: &$2) }
    }

    public mutating func removeMachineTransition(at index: Int) {
        editMachine { try $0.removeTransition(at: index, from: $1, in: &$2) }
    }

    public mutating func addMachineInput(_ input: MachineInput) {
        editMachine { try $0.addInput(input, to: $1, in: &$2) }
    }

    /// Sets an input's default; refused when the kind changes.
    public mutating func updateMachineInput(_ input: MachineInput) {
        editMachine { try $0.updateInput(input, in: $1, in: &$2) }
    }

    /// Refused while a condition uses the input.
    public mutating func removeMachineInput(named name: String) {
        editMachine { try $0.removeInput(named: name, from: $1, in: &$2) }
    }

    /// Starts the preview of the edited machine in its initial state with every input at its default.
    public mutating func startPreview() {
        guard let document, let id = machine?.id else { return refuseMachine(Self.noMachineSelected) }
        do {
            machinePreview = try services.preview.start(document, machineID: id)
            machineError = nil
        } catch {
            refuseMachine(Self.machineMessage(error))
        }
    }

    public mutating func stopPreview() { machinePreview = nil }

    /// Sets a preview input; a transition it enables switches state in the same call. No-op with no preview.
    public mutating func setPreviewInput(_ name: String, to value: InputValue) {
        guard let p = machinePreview, let document else { return }
        machinePreview = services.preview.set(name, to: value, p, in: document)
    }

    public mutating func firePreview(_ trigger: String) {
        guard let p = machinePreview, let document else { return }
        machinePreview = services.preview.fire(trigger, p, in: document)
    }

    /// Moves the preview `frames` ahead, looping the active state's range.
    public mutating func advancePreview(frames: Int) {
        guard let p = machinePreview, let document else { return }
        machinePreview = services.preview.advance(p, frames: frames, in: document)
    }

    /// Runs an edit of the edited machine; refused when none is edited.
    private mutating func editMachine(_ body: (any StateMachineEditing, String, inout CommandEngine) throws -> Void) {
        guard let id = machine?.id else { return refuseMachine(Self.noMachineSelected) }
        machineStep { try body($0, id, &$1) }
    }

    /// Stops the preview and runs `body` on a copy of the engine, committing it only if it succeeds.
    private mutating func machineStep(_ body: (any StateMachineEditing, inout CommandEngine) throws -> Void) {
        stopPreview()
        guard var next = engine else { return refuseMachine(FlareLayerError.noDocument.message) }
        do {
            try body(services.machines, &next)
        } catch {
            return refuseMachine(Self.machineMessage(error))
        }
        engine = next
        machineError = nil
    }

    private mutating func refuseMachine(_ message: String) { machineError = message }

    static func machineMessage(_ error: any Error) -> String {
        switch error {
        case CommandError.invalidDocument(let message): message
        case let error as NotBuilt: error.reason
        default: "The machine could not be changed (\(error))."
        }
    }

    private static func machineName(_ name: String) -> String? {
        let trimmed = String(name.drop(while: \.isWhitespace).reversed().drop(while: \.isWhitespace).reversed())
        return trimmed.isEmpty ? nil : trimmed
    }

    static let emptyMachineName = "Type a name for the machine."
    static let noMachineSelected = "Select a machine first."
    static func noLabel(_ label: String) -> String { "This scene has no frame label \u{201C}\(label)\u{201D}." }
}
