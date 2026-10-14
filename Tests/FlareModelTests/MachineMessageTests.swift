// MachineMessageTests.swift: every engine refusal a machine edit can raise reaches `machineError` in plain words,
// never as debug text with the machine's id and escaped quotes (#659).
import FlareCore
@testable import FlareModel
import Testing

/// True when `message` reads like debug output rather than a sentence for a person.
private func looksLikeDebugText(_ message: String, of error: any Error) -> Bool {
    message == String(describing: error) || message.contains("(") || message.contains("\"")
        || message.contains("machine-") || message.contains("state machine") || message.isEmpty
}

@Test func engineRefusalsOfMachineEditsReadAsPlainWords() {
    var w = FlareWorkspace(services: .fake())
    w.load(FlareFixtures.button)
    w.addMachine(named: "Button", firstStateLabel: "idle")
    let doc = w.document
    w.addMachineState(fromLabel: "idle")
    #expect(w.machineError == "idle is already a state.")
    w.setInitialMachineState("nope")
    #expect(w.machineError == "nope isn\u{2019}t a state of this machine.")
    w.updateMachineState(MachineState(id: "idle", name: "idle", sceneID: "scene-1", startFrame: 30, endFrame: 10))
    #expect(w.machineError == "The state\u{2019}s frames must be inside the scene.")
    w.updateMachineTransition(at: 5, to: FlareTransition(from: "idle", to: "idle", trigger: "t"))
    #expect(w.machineError == "That item is no longer there.")
    #expect(w.document == doc)
}

/// The engine's validation of a machine edit: the step's label, then the format error it caught.
private func validation(_ rule: String) -> CommandError {
    .invalidDocument("Add State: \(FormatError.invalid("state machine machine-1: \(rule)"))")
}

@Test func everyRefusalAMachineEditCanRaiseHasAPlainMessage() {
    let commandErrors: [CommandError] = [
        .sceneNotFound("scene-1"), .layerNotFound("layer-1"), .duplicateID("idle"),
        .keyframeNotFound(property: "x", frame: 3), .frameOccupied(property: "x", frame: 3), .invalidFrame(-1),
        .labelNotFound("idle"), .invalidFPS(0), .invalidDuration(-1), .shapeNotFound(2), .layerLocked("layer-1"),
        .symbolNotFound("sym-1"), .symbolInUse("sym-1"), .invalidGuidePosition, .swatchNotFound("Red"),
        .emptySwatchName, .invalidColor(Color(r: 2, g: 0, b: 0, a: 1)), .invalidIndex(5), .notExecuted,
        .nothingToUndo, .nothingToRedo, .groupInProgress, .unknownCommand("x.y"), .malformedCommand("bad json"),
        .invalidDocument("Add State: \(FormatError.invalid("scene scene-1: fps must be > 0"))"),
        validation("duplicate state id idle"), validation("state idle has unknown scene scene-9"),
        validation("state idle frame range outside scene"), validation("unknown initial state nope"),
        validation("duplicate input hover"), validation("input hover default is not finite"),
        validation("transition idle -> nope names an unknown state"),
        validation("condition names unknown input hover"), validation("condition on hover has the wrong value type"),
        validation("condition compares bool input hover with >"),
        .invalidDocument("Add Machine: \(FormatError.invalid("duplicate state machine id machine-1"))"),
    ]
    let errors: [any Error] = commandErrors + [FormatError.invalid("x"), ModelError.layerNotFound("layer-1")]
    for error in errors {
        let message = FlareWorkspace.machineMessage(error)
        #expect(!looksLikeDebugText(message, of: error), "\(error) gave \(message)")
    }
}

@Test func theFakesOwnRefusalsAndNotBuiltReasonsPassThrough() {
    #expect(FlareWorkspace.machineMessage(CommandError.invalidDocument("hover is the initial state."))
        == "hover is the initial state.")
    #expect(FlareWorkspace.machineMessage(NotBuilt(reason: "Not connected yet (IN-6).")) == "Not connected yet (IN-6).")
}
