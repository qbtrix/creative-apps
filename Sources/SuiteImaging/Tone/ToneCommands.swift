// ToneCommands.swift (tone-controls TC-1 specs, TC-6 bodies): the four tone.*
// commands every app with a ToneTarget registers, and the intents ToneRows
// sends them as. Ids, titles, schemas and availability are the contract; TC-1
// runs throw `notBuilt` and `ToneIntent.command` is TC-6's. Each run reads
// `toneSettings`, applies one ToneRules rule and calls `setTone` once, the
// drag token passed through so a drag is one undo step. Linux-safe.
import CoreRaster
import SuiteKernel

/// What an app gives the tone commands: one picture's settings, why they can't run, the one edit
/// that records a named undo step, and Auto's suggestion.
public protocol ToneTarget: Sendable {
    /// The settings to adjust; nil when there is nothing to adjust (no image, no photo).
    var toneSettings: ToneSettings? { get }
    /// Why the tone commands can't run now, in the app's words; nil when they can.
    var toneHelp: String? { get }
    /// One undo step named `name`; steps under one `drag` token fold into one.
    mutating func setTone(_ s: ToneSettings, name: String, drag: String?) throws
    /// Auto's suggestion from the target's own histogram: one CPU read per click, never per slider step.
    func autoToneSuggestion() throws -> AutoTone
}

/// One tone change a view asks for; `command` is the catalog id and params that run it.
public enum ToneIntent: Hashable, Sendable {
    case set(ToneSlider, Double, drag: String?), reset(ToneGroup?), auto

    /// The command id and its JSON params. Stub: the id with empty params until TC-6.
    public var command: (id: String, params: JSONValue) {
        switch self {
        case .set: ("tone.set", .object([:]))
        case .reset: ("tone.reset", .object([:]))
        case .auto: ("tone.auto", .object([:]))
        }
    }
}

/// The tone.* specs for a ToneTarget, and their params.
public enum ToneCommands {
    /// `tone.set`: one slider to one value, under a drag token while dragging.
    public struct SetParams: Codable, Sendable { public var slider: ToneSlider; public var value: Double; public var drag: String? }
    /// `tone.reset`: one group, or every group when nil.
    public struct ResetParams: Codable, Sendable { public var group: String? }
    /// `tone.read` and `tone.auto` take nothing.
    public struct NoParams: Codable, Sendable {}

    /// The feature whose task fills the runs.
    static let notBuilt = CatalogError.notBuilt(id: "tone", feature: "tone-controls TC-6")

    static let dragSchema = ParamSchema.optional(.string("A drag's token; steps under one token are one undo step.", maxLength: 64))
    /// Every slider off neutral, by its key.
    static let readingSchema = ParamSchema.object(
        Dictionary(uniqueKeysWithValues: ToneSlider.allCases.map { ($0.rawValue, ParamSchema.optional(.number($0.title))) }),
        required: ToneSlider.allCases.map(\.rawValue), description: "Every slider off neutral; a neutral slider is omitted.")

    /// The four specs, in the packet's order.
    public static func specs<T: ToneTarget>(_ target: T.Type) -> [CommandSpec<T>] {
        let can: @Sendable (T) -> Availability = { $0.toneHelp.map(Availability.unavailable) ?? .available }
        let canReset: @Sendable (T) -> Availability = { t in
            if let help = t.toneHelp { return .unavailable(help) }
            return t.toneSettings?.isNeutral(nil) == false ? .available : .unavailable("Every slider is already at 0.")
        }
        return [
            .typed("tone.read", title: "Tone", summary: "Reads every tone and sharpen slider off neutral.", kind: .query,
                   params: NoParams.self, schema: ParamSchema.none, result: readingSchema, example: .object([:]),
                   availability: can) { (_: inout T, _: NoParams) throws -> JSONValue in throw notBuilt },
            .typed("tone.set", title: "Tone",
                   summary: "Sets one tone or sharpen slider; the undo step is named for the slider (\"Temperature\").",
                   kind: .edit, params: SetParams.self,
                   schema: .object(["slider": .string("The slider's key.", oneOf: ToneSlider.allCases.map(\.rawValue)),
                                    "value": .number("The value, clamped to the slider's range."), "drag": dragSchema],
                                   required: ["slider", "value", "drag"]),
                   result: readingSchema, example: .object(["slider": .string("temperature"), "value": .number(30)]),
                   availability: can) { (_: inout T, _: SetParams) throws -> JSONValue in throw notBuilt },
            .typed("tone.reset", title: "Reset Tone", summary: "Sets one group's sliders, or every slider, back to neutral.",
                   kind: .edit, params: ResetParams.self,
                   schema: .object(["group": .optional(.string("The group; every group when omitted.",
                                                               oneOf: ToneGroup.allCases.map(\.rawValue)))], required: ["group"]),
                   result: readingSchema, example: .object([:]),
                   availability: canReset) { (_: inout T, _: ResetParams) throws -> JSONValue in throw notBuilt },
            .typed("tone.auto", title: "Auto Tone", summary: "Sets white balance, exposure, whites and blacks from the picture.",
                   kind: .edit, params: NoParams.self, schema: ParamSchema.none, result: readingSchema, example: .object([:]),
                   availability: can) { (_: inout T, _: NoParams) throws -> JSONValue in throw notBuilt },
        ]
    }
}
