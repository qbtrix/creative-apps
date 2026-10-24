// StyleCommands.swift (layer-styles LS-1 specs, LS-6 bodies): the eleven style.* commands a
// LayerStyleTarget registers and the intents views send. Ids, schemas and availability are the
// contract; LS-1 runs throw `StyleRules.notBuilt`. Each edit calls `setStyle` once. Linux-safe.
import CoreRaster
import SuiteKernel

/// What an app gives the style commands: the selected layer's style, why they can't run, the one
/// edit that records a named undo step, and the panel it shows.
public protocol LayerStyleTarget: Sendable {
    /// The selected layer's style; nil when nothing stylable is selected.
    var styleSelection: LayerStyle? { get }
    /// Why the style commands can't run now, in the app's words; nil when they can.
    var styleHelp: String? { get }
    /// The style section the panel shows; nil when it is closed.
    var stylePanel: StyleKind? { get }
    /// Opens the panel at `kind`'s section, or closes it when nil. Not an undo step.
    mutating func showStylePanel(_ kind: StyleKind?)
    /// One undo step named `name` on the selected layer; steps under one `drag` token fold into one.
    mutating func setStyle(_ style: LayerStyle, name: String, drag: String?) throws
}

/// One style change a view asks for; `command` is the catalog id and params that run it.
public enum StyleIntent: Hashable, Sendable {
    case toggle(StyleKind, Bool), set(StyleKind, JSONValue, drag: String?), preset(String)
    case fillOpacity(Double, drag: String?), show(StyleKind?)

    /// The command id and its JSON params. Stub: the id with empty params until LS-6.
    public var command: (id: String, params: JSONValue) {
        switch self {
        case .toggle: ("style.enable", .object([:])); case .set: ("style.set", .object([:])); case .preset: ("style.preset", .object([:]))
        case .fillOpacity: ("style.fill-opacity", .object([:])); case .show: ("style.panel", .object([:]))
        }
    }
}

/// The style.* specs for a LayerStyleTarget, and their params (`style.set`'s patch is the schema's other fields).
public enum StyleCommands {
    public struct KindParams: Codable, Sendable { public var kind: StyleKind }
    public struct PanelParams: Codable, Sendable { public var kind: StyleKind? }
    public struct EnableParams: Codable, Sendable { public var kind: StyleKind; public var on: Bool }
    public struct SetParams: Codable, Sendable { public var kind: StyleKind; public var drag: String? }
    public struct FillOpacityParams: Codable, Sendable { public var value: Double; public var drag: String? }
    public struct PresetParams: Codable, Sendable { public var name: String }
    public struct PasteParams: Codable, Sendable { public var style: JSONValue }
    public struct NoParams: Codable, Sendable {}

    static let kinds = StyleKind.allCases.map(\.rawValue)
    static let blends = BlendMode.allCases.map(\.rawValue)
    static let kindSchema = ParamSchema.string("The style's kind.", oneOf: kinds)
    static let dragSchema = ParamSchema.optional(.string("A drag's token; steps under one token are one undo step.", maxLength: 64))
    /// Any JSON object: a colour {r,g,b,a}, a fill, or a whole style; LS-5's rules check it.
    static func anyObject(_ description: String) -> ParamSchema {
        var schema = ParamSchema.none; schema.json = .object(["type": .string("object"), "description": .string(description)]); return schema
    }
    static let styleSchema = anyObject("A layer style: effects and fillOpacity, as style.copy returns it.")
    static let setSchema: ParamSchema = {
        var fields: [String: ParamSchema] = ["kind": kindSchema, "drag": dragSchema,
                                             "blend": .optional(.string("The effect's blend mode.", oneOf: blends)),
                                             "position": .optional(.string("The stroke's position.", oneOf: StrokePosition.allCases.map(\.rawValue))),
                                             "shape": .optional(.string("The bevel's shape.", oneOf: BevelShape.allCases.map(\.rawValue))),
                                             "technique": .optional(.string("The bevel's technique.", oneOf: BevelTechnique.allCases.map(\.rawValue))),
                                             "up": .optional(.boolean), "fill": .optional(anyObject("A solid or gradient fill."))]
        for key in ["opacity", "angle", "distance", "spread", "size", "depth", "soften", "altitude", "highlightOpacity", "shadowOpacity"] {
            fields[key] = .optional(.number("The effect's \(key); clamped to its range."))
        }
        for key in ["color", "highlight", "shadow"] { fields[key] = .optional(anyObject("A colour {r, g, b, a}, sRGB 0...1.")) }
        for key in ["highlightBlend", "shadowBlend"] { fields[key] = .optional(.string("A bevel layer's blend mode.", oneOf: blends)) }
        return .object(fields, required: fields.keys.sorted(), description: "One effect's changed fields.")
    }()

    /// One spec whose run throws `StyleRules.notBuilt` until LS-6, returning the style.
    static func stub<T: LayerStyleTarget, P: Decodable & Sendable>(
        _ id: String, _ title: String, _ summary: String, _ kind: CommandKind, _ params: P.Type, _ schema: ParamSchema,
        _ example: JSONValue, _ availability: @escaping @Sendable (T) -> Availability) -> CommandSpec<T> {
        .typed(id, title: title, summary: summary, kind: kind, params: params, schema: schema,
               result: kind == .view ? ParamSchema.none : styleSchema, example: example,
               availability: availability) { (_: inout T, _: P) throws -> JSONValue in throw StyleRules.notBuilt }
    }

    /// The eleven specs, in the packet's order.
    public static func specs<T: LayerStyleTarget>(_ target: T.Type) -> [CommandSpec<T>] {
        let blocked: @Sendable (T) -> String? = { $0.styleHelp ?? ($0.styleSelection == nil ? StyleRules.noLayerHelp : nil) }
        let can: @Sendable (T) -> Availability = { blocked($0).map(Availability.unavailable) ?? .available }
        let needsStyle: @Sendable (String) -> @Sendable (T) -> Availability = { why in
            { t in blocked(t).map(Availability.unavailable) ?? (t.styleSelection == LayerStyle.none ? .unavailable(why) : .available) }
        }
        let kindOnly = ParamSchema.object(["kind": kindSchema], required: ["kind"])
        let shadow = JSONValue.object(["kind": .string("dropShadow")])
        return [
            stub("style.read", "Layer Style", "Reads the selected layer's style.", .query, NoParams.self, .none, .object([:]), can),
            stub("style.add", "Add Layer Style", "Adds one style at its defaults; refused when the layer has it.",
                 .edit, KindParams.self, kindOnly, shadow, can),
            stub("style.remove", "Remove Layer Style", "Removes one style from the layer.", .edit, KindParams.self, kindOnly, shadow, can),
            stub("style.enable", "Toggle Layer Style", "Turns one style on or off, keeping its settings.", .edit, EnableParams.self,
                 .object(["kind": kindSchema, "on": .boolean], required: ["kind", "on"]),
                 .object(["kind": .string("dropShadow"), "on": .bool(false)]), can),
            stub("style.set", "Change Layer Style", "Changes one style's fields; one undo step per drag.", .edit, SetParams.self,
                 setSchema, .object(["kind": .string("dropShadow"), "distance": .number(8)]), can),
            stub("style.fill-opacity", "Fill Opacity", "Sets the layer's own pixels' opacity; effects keep theirs.", .edit,
                 FillOpacityParams.self, .object(["value": .number("Fill opacity.", minimum: 0, maximum: 1), "drag": dragSchema],
                                                 required: ["value", "drag"]), .object(["value": .number(0.5)]), can),
            stub("style.preset", "Apply Style Preset", "Replaces the layer's style with a built-in preset.", .edit, PresetParams.self,
                 .object(["name": .string("The preset's name.", maxLength: 64)], required: ["name"]), .object(["name": .string("Lifted")]), can),
            stub("style.copy", "Copy Layer Style", "Returns the layer's style as JSON for style.paste.", .query, NoParams.self, .none,
                 .object([:]), needsStyle("This layer has no style to copy.")),
            stub("style.paste", "Paste Layer Style", "Replaces the layer's style with a copied one; refuses a malformed one.", .edit,
                 PasteParams.self, .object(["style": styleSchema], required: ["style"]),
                 .object(["style": .object(["effects": .array([]), "fillOpacity": .number(1)])]), can),
            stub("style.clear", "Clear Layer Style", "Removes every style and sets fill opacity back to 1.", .edit, NoParams.self, .none,
                 .object([:]), needsStyle("This layer has no style to clear.")),
            stub("style.panel", "Layer Style Panel", "Opens the style panel at one section, or closes it.", .view, PanelParams.self,
                 .object(["kind": .optional(kindSchema)], required: ["kind"]), .object([:]), can),
        ]
    }
}
