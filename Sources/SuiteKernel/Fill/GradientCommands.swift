// GradientCommands.swift (gradient-fill GF-1 specs with real ids, schemas and availability, runs throwing
// `GradientRules.notBuilt`; GF-6 bodies): the eight fill commands every app registers with one line,
// `+ GradientCommands.specs(<X>Workspace.self)`, and the editor's gestures as those commands.

/// One gesture of the gradient editor; the app runs its `command` through its catalog.
public enum GradientIntent: Hashable, Sendable {
    case type(FillType), add(offset: Double), move(index: Int, offset: Double, drag: String)
    case remove(index: Int), color(index: Int, FillColor, drag: String?), angle(Double, drag: String?)

    /// The editor's gesture as the command it is: its id and params.
    public var command: (id: String, params: JSONValue) {
        switch self {
        case .type(let type): ("fill.type", .object(["type": .string(type.rawValue)]))
        case .add(let offset): ("fill.stop-add", .object(["offset": .number(offset)]))
        case .move(let index, let offset, let drag): ("fill.stop-move", Self.params(["index": .number(Double(index)), "offset": .number(offset)], drag))
        case .remove(let index): ("fill.stop-remove", .object(["index": .number(Double(index))]))
        case .color(let index, let c, let drag):
            ("fill.stop-color", Self.params(["index": .number(Double(index)), "r": .number(c.r), "g": .number(c.g), "b": .number(c.b), "a": .number(c.a)], drag))
        case .angle(let degrees, let drag): ("fill.angle", Self.params(["degrees": .number(degrees)], drag))
        }
    }
    /// `fields` as an object, with `drag` when there is one.
    private static func params(_ fields: [String: JSONValue], _ drag: String?) -> JSONValue {
        .object(fields.merging(drag.map { ["drag": .string($0)] } ?? [:]) { old, _ in old })
    }
}

public enum GradientCommands {
    // Each command's params, named for it (`fill.read` takes none; `Stop` is one of `fill.gradient`'s stops).
    struct Empty: Codable, Sendable {}
    struct TypeParams: Codable, Sendable { var type: FillType }
    struct Stop: Codable, Sendable { var offset, r, g, b, a: Double }
    struct GradientParams: Codable, Sendable { var type: FillType; var stops: [Stop]; var angle: Double? }
    struct AddParams: Codable, Sendable { var offset: Double }
    struct MoveParams: Codable, Sendable { var index: Int; var offset: Double; var drag: String? }
    struct RemoveParams: Codable, Sendable { var index: Int }
    struct ColorParams: Codable, Sendable { var index: Int; var r, g, b, a: Double; var drag: String? }
    struct AngleParams: Codable, Sendable { var degrees: Double; var drag: String? }

    /// Why the stop commands can't run on a solid fill, the 64-stop cap, and why the angle needs a linear fill.
    static let solidHelp = "Switch the fill to a gradient first.", fullHelp = "A gradient holds at most 64 stops."
    static let angleHelp = "Angle is for a linear gradient."

    static let type = ParamSchema.string("The fill type.", oneOf: FillType.allCases.map(\.rawValue))
    static let unit = ParamSchema.number("0 to 1.", minimum: 0, maximum: 1)
    static let index = ParamSchema.integer("The stop's index, from 0.", minimum: 0, maximum: GradientRules.maxStops - 1)
    static let drag = ParamSchema.optional(.string("A drag's token; edits under one token are one undo step.", maxLength: 64))
    static let rgba: [String: ParamSchema] = ["r": unit, "g": unit, "b": unit, "a": unit]
    static let stop = ParamSchema.object(rgba.merging(["offset": unit]) { old, _ in old }, required: ["offset", "r", "g", "b", "a"])
    static let angle = ParamSchema.optional(.number("Degrees, 0 left to right, 90 top to bottom."))

    /// The eight fill commands on `target`, in menu order: `fill.read` a query, the rest edits of one undo step each.
    public static func specs<T: GradientFillTarget>(_ target: T.Type) -> [CommandSpec<T>] {
        [
            .typed("fill.read", title: "Read Fill", summary: "Reads the selection's fill: its type, stops and a linear fill's angle.",
                   kind: .query, params: Empty.self, schema: .none,
                   result: .object(["type": type, "stops": .array(of: stop), "angle": angle], required: ["type", "stops", "angle"]),
                   example: .object([:]), availability: { ready($0) }) { _, _ in try stub() },
            .typed("fill.type", title: "Fill Type", summary: "Makes the selection's fill solid, linear or radial.", kind: .edit,
                   params: TypeParams.self, schema: .object(["type": type], required: ["type"]),
                   example: .object(["type": .string("linear")]), availability: { ready($0) }) { _, _ in try stub() },
            .typed("fill.gradient", title: "Set Gradient", summary: "Sets the selection's gradient: its type, 2 to 64 stops and a linear fill's angle.",
                   kind: .edit, params: GradientParams.self,
                   schema: .object(["type": .string("linear or radial.", oneOf: ["linear", "radial"]),
                                    "stops": .array(of: stop, minItems: 2, maxItems: GradientRules.maxStops), "angle": angle],
                                   required: ["type", "stops", "angle"]),
                   example: .object(["type": .string("linear"), "angle": .number(45), "stops": .array([
                       .object(["offset": .number(0), "r": .number(0), "g": .number(0), "b": .number(1), "a": .number(1)]),
                       .object(["offset": .number(1), "r": .number(1), "g": .number(1), "b": .number(1), "a": .number(1)])])]),
                   availability: { ready($0) }) { _, _ in try stub() },
            .typed("fill.stop-add", title: "Add Gradient Stop", summary: "Adds a stop at an offset in the colour the gradient shows there.",
                   kind: .edit, params: AddParams.self, schema: .object(["offset": unit], required: ["offset"]),
                   example: .object(["offset": .number(0.5)]), availability: { stops($0, adding: true) }) { _, _ in try stub() },
            .typed("fill.stop-move", title: "Move Gradient Stop", summary: "Moves a stop to an offset; moves under one drag token are one undo step.",
                   kind: .edit, params: MoveParams.self, schema: .object(["index": index, "offset": unit, "drag": drag], required: ["index", "offset", "drag"]),
                   example: .object(["index": .number(0), "offset": .number(0.25)]), availability: { stops($0) }) { _, _ in try stub() },
            .typed("fill.stop-remove", title: "Remove Gradient Stop", summary: "Removes a stop; a gradient keeps at least two.",
                   kind: .edit, params: RemoveParams.self, schema: .object(["index": index], required: ["index"]),
                   example: .object(["index": .number(0)]), availability: { stops($0, removing: true) }) { _, _ in try stub() },
            .typed("fill.stop-color", title: "Gradient Stop Color", summary: "Sets a stop's colour; changes under one drag token are one undo step.",
                   kind: .edit, params: ColorParams.self,
                   schema: .object(rgba.merging(["index": index, "drag": drag]) { old, _ in old }, required: ["index", "r", "g", "b", "a", "drag"]),
                   example: .object(["index": .number(0), "r": .number(1), "g": .number(0), "b": .number(0), "a": .number(1)]),
                   availability: { stops($0) }) { _, _ in try stub() },
            .typed("fill.angle", title: "Gradient Angle", summary: "Turns a linear gradient to an angle in degrees about its box's centre.",
                   kind: .edit, params: AngleParams.self,
                   schema: .object(["degrees": .number("Degrees, 0 left to right, 90 top to bottom."), "drag": drag], required: ["degrees", "drag"]),
                   example: .object(["degrees": .number(45)]), availability: { linear($0) }) { _, _ in try stub() },
        ]
    }

    /// Available when the target has a fill to edit; else its `fillHelp`.
    static func ready<T: GradientFillTarget>(_ target: T) -> Availability {
        if let why = target.fillHelp { return .unavailable(why) }
        return target.fillSelection == nil ? .unavailable("Select something with a fill first.") : .available
    }
    /// `ready`, and a gradient: not full when `adding`, more than two stops when `removing`.
    static func stops<T: GradientFillTarget>(_ target: T, adding: Bool = false, removing: Bool = false) -> Availability {
        guard ready(target) == .available, let fill = target.fillSelection?.fill else { return ready(target) }
        if GradientRules.type(of: fill) == .solid { return .unavailable(solidHelp) }
        if adding, fill.stops.count >= GradientRules.maxStops { return .unavailable(fullHelp) }
        if removing, fill.stops.count <= 2 { return .unavailable(GradientRules.stopHelp) }
        return .available
    }
    /// `ready`, and a linear fill.
    static func linear<T: GradientFillTarget>(_ target: T) -> Availability {
        guard ready(target) == .available, let fill = target.fillSelection?.fill else { return ready(target) }
        return GradientRules.type(of: fill) == .linear ? .available : .unavailable(angleHelp)
    }
    /// Every run until GF-6: refuses with `GradientRules.notBuilt`.
    static func stub() throws -> JSONValue { throw GradientRules.notBuilt }
}
