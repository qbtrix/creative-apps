// FlareMachineMessages.swift: the plain words `machineError` shows for a refused machine edit (#659). Each engine
// refusal gets a short reason; the engine's validation failures, which arrive as `invalidDocument` carrying the step
// label and the format error's debug text, are read back into the broken rule. A message the fake wrote for a person
// passes through, and anything else gets a generic line, so a raw debug description never reaches the Inspector.
import FlareCore

extension FlareWorkspace {
    static let machineRefused = "The machine could not be changed."
    static let framesOutsideScene = "The state\u{2019}s frames must be inside the scene."

    static func machineMessage(_ error: any Error) -> String {
        switch error {
        case let error as CommandError: machineMessage(error)
        case let error as NotBuilt: error.reason
        default: machineRefused
        }
    }

    private static func machineMessage(_ error: CommandError) -> String {
        switch error {
        case .invalidDocument(let message): validationMessage(message)
        case .sceneNotFound: "This scene is no longer in the document."
        case .layerNotFound: "This layer is no longer in the document."
        case .duplicateID(let id): "\(id) is already used."
        case .keyframeNotFound: "There\u{2019}s no keyframe on that frame."
        case .frameOccupied: "That frame already has a keyframe."
        case .invalidFrame: "That frame is outside the scene."
        case .labelNotFound(let label): noLabel(label)
        case .invalidFPS: "The frame rate must be more than 0."
        case .invalidDuration: "The scene\u{2019}s length can\u{2019}t be negative."
        case .shapeNotFound: "That shape is no longer there."
        case .layerLocked: "The layer is locked."
        case .symbolNotFound: "That symbol is no longer in the library."
        case .symbolInUse: "An instance still uses that symbol."
        case .invalidGuidePosition: "A guide needs a position on the canvas."
        case .swatchNotFound: "That swatch is no longer in the palette."
        case .emptySwatchName: "Type a name for the swatch."
        case .invalidColor: "Each color channel must be between 0 and 1."
        case .invalidIndex: "That item is no longer there."
        case .notExecuted, .nothingToUndo, .nothingToRedo, .groupInProgress, .unknownCommand, .malformedCommand:
            machineRefused
        }
    }

    /// The broken rule behind an engine validation failure, "Add State: invalid(\"state machine m: <rule>\")";
    /// a message without that shape was written for a person and passes through.
    private static func validationMessage(_ message: String) -> String {
        guard let open = message.firstRange(of: ": invalid(\""), message.hasSuffix("\")") else { return message }
        var rule = message[open.upperBound...].dropLast(2)
        guard rule.hasPrefix("state machine "), let colon = rule.firstRange(of: ": ") else { return machineRefused }
        rule = rule[colon.upperBound...]
        if let id = between(rule, "duplicate state id ", "") { return "\(id) is already a state." }
        if let id = between(rule, "unknown initial state ", "") { return "\(id) isn\u{2019}t a state of this machine." }
        if between(rule, "state ", " frame range outside scene") != nil {
            return framesOutsideScene
        }
        if let id = between(rule, "state ", " has unknown scene ", partial: true) {
            return "\(id)\u{2019}s scene is no longer in the document."
        }
        if let name = between(rule, "duplicate input ", "") { return "\(name) is already an input." }
        if let name = between(rule, "input ", " default is not finite") { return "\(name) needs a finite default." }
        if between(rule, "transition ", " names an unknown state") != nil {
            return "A transition must go between states of this machine."
        }
        if let name = between(rule, "condition names unknown input ", "") {
            return "\(name) isn\u{2019}t an input of this machine."
        }
        if let name = between(rule, "condition on ", " has the wrong value type") {
            return "The condition\u{2019}s value must be the same kind as \(name)."
        }
        if let name = between(rule, "condition compares bool input ", " with ", partial: true) {
            return "\(name) is a true or false input, so its condition can only test equal."
        }
        return machineRefused
    }

    /// The text of `rule` between `prefix` and `suffix`, or, when `partial`, between `prefix` and the first `suffix`.
    private static func between(_ rule: Substring, _ prefix: String, _ suffix: String,
                                partial: Bool = false) -> Substring? {
        guard rule.hasPrefix(prefix) else { return nil }
        let rest = rule.dropFirst(prefix.count)
        if partial { return rest.firstRange(of: suffix).map { rest[..<$0.lowerBound] } }
        return rest.hasSuffix(suffix) ? rest.dropLast(suffix.count) : nil
    }
}
