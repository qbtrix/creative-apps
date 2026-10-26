// ToneCommands.swift (tone-controls TC-1 specs, TC-6 bodies): the four tone.* commands a ToneTarget
// registers and the intents views send. Ids, schemas and availability are the contract. Each edit
// reads `toneSettings`, applies one rule and calls `setTone` once, the drag token passed through, so
// the target's History folds a drag into one step. Linux-safe.
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

    /// The command id and its JSON params; a nil drag or group is omitted.
    public var command: (id: String, params: JSONValue) {
        switch self {
        case .set(let slider, let value, let drag):
            var params: [String: JSONValue] = ["slider": .string(slider.rawValue), "value": .number(value)]
            if let drag { params["drag"] = .string(drag) }
            return ("tone.set", .object(params))
        case .reset(let group): return ("tone.reset", .object(group.map { ["group": .string($0.rawValue)] } ?? [:]))
        case .auto: return ("tone.auto", .object([:]))
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

    /// Why Radius and Threshold can't be set: the unsharp pass is off.
    static let sharpenOff = "Sharpen is off at Amount 0."
    /// Why a target with no settings can't be adjusted, when it gives no `toneHelp` of its own.
    static let nothingToAdjust = "There is no picture to adjust."

    /// The target's settings, or `unavailable` for `id` when it has none.
    static func settings<T: ToneTarget>(_ t: T, _ id: String) throws -> ToneSettings {
        guard let s = t.toneSettings else { throw CatalogError.unavailable(id: id, why: nothingToAdjust) }
        return s
    }
    /// Why `slider` can't be set on `s`: a `waiting` slider's reason, or Radius and Threshold at Amount 0.
    static func whyNot(_ slider: ToneSlider, on s: ToneSettings) -> String? {
        if let why = ToneRules.waiting[slider] { return why }
        let needsAmount = slider == .sharpenRadius || slider == .sharpenThreshold
        return needsAmount && s.value(.sharpenAmount) == 0 ? sharpenOff : nil
    }
    /// Every slider off neutral, by its key: `tone.read`'s result and every edit's.
    static func reading(_ s: ToneSettings) -> JSONValue {
        .object(Dictionary(uniqueKeysWithValues: ToneSlider.allCases.compactMap { slider in
            s.value(slider) == slider.neutral ? nil : (slider.rawValue, JSONValue.number(s.value(slider)))
        }))
    }
    /// `reset`'s undo step: "Reset White Balance", or "Reset Tone" for every group.
    static func resetName(_ g: ToneGroup?) -> String { "Reset " + (g?.title ?? "Tone") }

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
                   availability: can) { (t: inout T, _: NoParams) throws -> JSONValue in reading(try settings(t, "tone.read")) },
            .typed("tone.set", title: "Tone",
                   summary: "Sets one tone or sharpen slider; the undo step is named for the slider (\"Temperature\").",
                   kind: .edit, params: SetParams.self,
                   schema: .object(["slider": .string("The slider's key.", oneOf: ToneSlider.allCases.map(\.rawValue)),
                                    "value": .number("The value, clamped to the slider's range."), "drag": dragSchema],
                                   required: ["slider", "value", "drag"]),
                   result: readingSchema, example: .object(["slider": .string("temperature"), "value": .number(30)]),
                   availability: can) { (t: inout T, p: SetParams) throws -> JSONValue in
                let s = try settings(t, "tone.set")
                if let why = whyNot(p.slider, on: s) { throw CatalogError.unavailable(id: "tone.set", why: why) }
                let next = s.setting(p.slider, to: p.value)
                try t.setTone(next, name: p.slider.title, drag: p.drag)
                return reading(next)
            },
            .typed("tone.reset", title: "Reset Tone", summary: "Sets one group's sliders, or every slider, back to neutral.",
                   kind: .edit, params: ResetParams.self,
                   schema: .object(["group": .optional(.string("The group; every group when omitted.",
                                                               oneOf: ToneGroup.allCases.map(\.rawValue)))], required: ["group"]),
                   result: readingSchema, example: .object([:]),
                   availability: canReset) { (t: inout T, p: ResetParams) throws -> JSONValue in
                let s = try settings(t, "tone.reset")
                let group = p.group.flatMap(ToneGroup.init(rawValue:))
                if p.group != nil && group == nil {
                    throw CatalogError.malformedParams(id: "tone.reset", [SchemaIssue(path: "/group", message: "is not a tone group")])
                }
                let next = s.reset(group)
                try t.setTone(next, name: resetName(group), drag: nil)
                return reading(next)
            },
            .typed("tone.auto", title: "Auto Tone", summary: "Sets white balance, exposure, whites and blacks from the picture.",
                   kind: .edit, params: NoParams.self, schema: ParamSchema.none, result: readingSchema, example: .object([:]),
                   availability: can) { (t: inout T, _: NoParams) throws -> JSONValue in
                let next = ToneRules.auto(try t.autoToneSuggestion(), keeping: try settings(t, "tone.auto"))
                try t.setTone(next, name: "Auto Tone", drag: nil)
                return reading(next)
            },
        ]
    }
}
