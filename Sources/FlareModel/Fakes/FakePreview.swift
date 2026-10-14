// FakePreview.swift: StateMachinePreviewing over FlareCore's real `StateMachine.next(from:trigger:inputs:)`
// (docs/blueprints/flare.md, 6.3). The preview starts in the initial state at its first frame with every input at
// its default, and loops each state's frame range. Firing a trigger takes the transition `next` picks; setting an
// input fires the triggers of the transitions out of the current state that test that input, in declaration order,
// so toggling `hover` on moves idle to hover. Entering a state starts at its first frame. No document edits. With
// `unavailable` set, `start` throws that reason.
import FlareCore

public struct FakePreview: StateMachinePreviewing {
    /// Why this member is off; nil when it works.
    public var unavailable: String?
    public init(unavailable: String? = nil) { self.unavailable = unavailable }

    public func start(_ document: Document, machineID: String) throws -> MachinePreview {
        if let unavailable { throw NotBuilt(reason: unavailable) }
        guard let m = document.stateMachines.first(where: { $0.id == machineID }) else { throw FakeMachines.noMachine(machineID) }
        var inputs: [String: InputValue] = [:]
        for input in m.inputs { inputs[input.name] = input.defaultValue }
        let first = m.states.first { $0.id == m.initialState }?.startFrame ?? 0
        return MachinePreview(machineID: m.id, stateID: m.initialState, frame: first, inputs: inputs)
    }

    public func set(_ input: String, to value: InputValue, _ preview: MachinePreview, in document: Document) -> MachinePreview {
        guard let m = machine(preview, document) else { return preview }
        var p = preview
        p.inputs[input] = value
        let triggers = m.transitions.filter { $0.from == p.stateID && $0.conditions.contains { $0.input == input } }.map(\.trigger)
        for trigger in triggers {
            let next = enter(m.next(from: p.stateID, trigger: trigger, inputs: p.inputs), p, m)
            if next.stateID != p.stateID { return next }
        }
        return p
    }

    public func fire(_ trigger: String, _ preview: MachinePreview, in document: Document) -> MachinePreview {
        guard let m = machine(preview, document) else { return preview }
        return enter(m.next(from: preview.stateID, trigger: trigger, inputs: preview.inputs), preview, m)
    }

    public func advance(_ preview: MachinePreview, frames: Int, in document: Document) -> MachinePreview {
        guard let s = machine(preview, document)?.states.first(where: { $0.id == preview.stateID }) else { return preview }
        let length = s.endFrame - s.startFrame + 1
        guard length > 0 else { return preview }
        var p = preview
        let offset = (p.frame - s.startFrame) % length + frames % length
        p.frame = s.startFrame + ((offset % length) + length) % length
        return p
    }

    private func machine(_ preview: MachinePreview, _ document: Document) -> StateMachine? {
        guard unavailable == nil else { return nil }
        return document.stateMachines.first { $0.id == preview.machineID }
    }

    /// The preview in `stateID` from its first frame; unchanged when it is already there.
    private func enter(_ stateID: String, _ preview: MachinePreview, _ m: StateMachine) -> MachinePreview {
        guard stateID != preview.stateID else { return preview }
        var p = preview
        p.stateID = stateID
        p.frame = m.states.first { $0.id == stateID }?.startFrame ?? 0
        return p
    }
}
