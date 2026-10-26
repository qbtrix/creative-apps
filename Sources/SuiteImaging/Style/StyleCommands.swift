// StyleCommands.swift (layer-styles LS-1 specs, LS-6 bodies): the eleven style.* commands a
// LayerStyleTarget registers and the intents views send. Each edit reads `styleSelection`, applies one
// `StyleRules` rule and calls `setStyle` once with its title, passing a drag token through so the target's
// `History` folds a scrub into one step; `style.panel` only calls `showStylePanel`. Linux-safe.
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

    /// The command id and its JSON params: `set`'s patch fields sit beside `kind`, and a nil drag or kind is left out
    /// (`show(nil)` closes an open panel).
    public var command: (id: String, params: JSONValue) {
        switch self {
        case .toggle(let kind, let on): return ("style.enable", .object(["kind": .string(kind.rawValue), "on": .bool(on)]))
        case .set(let kind, let patch, let drag):
            var fields: [String: JSONValue] = [:]
            if case .object(let patched) = patch { fields = patched }
            fields["kind"] = .string(kind.rawValue)
            return ("style.set", Self.params(fields, drag))
        case .preset(let name): return ("style.preset", .object(["name": .string(name)]))
        case .fillOpacity(let value, let drag): return ("style.fill-opacity", Self.params(["value": .number(value)], drag))
        case .show(let kind): return ("style.panel", .object(kind.map { ["kind": .string($0.rawValue)] } ?? [:]))
        }
    }
    /// `fields` as an object, with `drag` when there is one.
    private static func params(_ fields: [String: JSONValue], _ drag: String?) -> JSONValue {
        .object(fields.merging(drag.map { ["drag": .string($0)] } ?? [:]) { _, new in new })
    }
}

/// The style.* specs for a LayerStyleTarget, and their params (`style.set`'s patch is the schema's other fields).
public enum StyleCommands {
    public struct KindParams: Codable, Sendable { public var kind: StyleKind }
    public struct PanelParams: Codable, Sendable { public var kind: StyleKind? }
    public struct EnableParams: Codable, Sendable { public var kind: StyleKind; public var on: Bool }
    /// The kind, the drag token, and the whole params object as the patch `StyleRules.setting` reads.
    public struct SetParams: Codable, Sendable {
        public var kind: StyleKind; public var drag: String?; public var patch: JSONValue
        enum Keys: String, CodingKey { case kind, drag }
        public init(from decoder: any Decoder) throws {
            let keyed = try decoder.container(keyedBy: Keys.self)
            (kind, drag) = (try keyed.decode(StyleKind.self, forKey: .kind), try keyed.decodeIfPresent(String.self, forKey: .drag))
            patch = try JSONValue(from: decoder)
        }
        public func encode(to encoder: any Encoder) throws { try patch.encode(to: encoder) }
    }
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

    /// One spec: a `view` returns nothing, the rest return the layer's style after the run.
    static func spec<T: LayerStyleTarget, P: Decodable & Sendable>(
        _ id: String, _ title: String, _ summary: String, _ kind: CommandKind, _ params: P.Type, _ schema: ParamSchema,
        _ example: JSONValue, _ availability: @escaping @Sendable (T) -> Availability,
        _ run: @escaping @Sendable (inout T, P) throws -> JSONValue) -> CommandSpec<T> {
        .typed(id, title: title, summary: summary, kind: kind, params: params, schema: schema,
               result: kind == .view ? ParamSchema.none : styleSchema, example: example, availability: availability, run: run)
    }

    /// The selection's style after `change`, set once as the step `title` under `drag`; returns the new style's JSON.
    static func edit<T: LayerStyleTarget>(_ t: inout T, _ title: String, drag: String? = nil,
                                         _ change: (LayerStyle) throws -> LayerStyle) throws -> JSONValue {
        guard let style = t.styleSelection else { throw CatalogError.unavailable(id: "style", why: t.styleHelp ?? StyleRules.noLayerHelp) }
        let new = try change(style)
        try t.setStyle(new, name: title, drag: drag)
        return StyleRules.json(new)
    }

    /// `style` when it has `kind`, else refused in `id`'s name.
    static func having(_ kind: StyleKind, _ style: LayerStyle, _ id: String) throws -> LayerStyle {
        guard style.effect(kind) != nil else { throw CatalogError.unavailable(id: id, why: "This layer has no \(kind.rawValue).") }
        return style
    }

    /// `style` with `kind`'s effect changed by `change`.
    static func changing(_ kind: StyleKind, in style: LayerStyle, _ change: (inout StyleEffect) -> Void) -> LayerStyle {
        var result = style
        result.effects = style.effects.map { effect in var e = effect; if e.kind == kind { change(&e) }; return e }
        return result
    }

    /// The pasted style, refused with `check`'s reason when its JSON holds two of a kind or a value out of shape.
    static func pasted(_ json: JSONValue) throws -> LayerStyle {
        let style = try StyleRules.style(json: json)
        guard case .object(let root) = json, case .array(let list)? = root["effects"] else { return style }
        let every = try list.flatMap { try StyleRules.style(json: .object(["effects": .array([$0])])).effects }
        if let why = StyleRules.check(LayerStyle(effects: every, fillOpacity: style.fillOpacity)) {
            throw CatalogError.unavailable(id: "style.paste", why: why)
        }
        return style
    }

    /// The section `style.panel` with no kind opens: the first enabled effect's, else the drop shadow's.
    static func defaultSection(_ style: LayerStyle?) -> StyleKind {
        style?.effects.first(where: \.isEnabled)?.kind ?? .dropShadow
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
        let read: @Sendable (inout T, NoParams) throws -> JSONValue = { t, _ in StyleRules.json(t.styleSelection ?? .none) }
        return [
            spec("style.read", "Read Layer Style", "Reads the selected layer's style.", .query, NoParams.self, .none, .object([:]), can, read),
            spec("style.add", "Add Layer Style", "Adds one style at its defaults; refused when the layer has it, on or off.",
                 .edit, KindParams.self, kindOnly, shadow, can) { t, p in
                try edit(&t, "Add Layer Style") { style in
                    guard style.effect(p.kind) == nil else {
                        throw CatalogError.unavailable(id: "style.add", why: "This layer already has a \(p.kind.rawValue); use style.enable to turn it on or off.")
                    }
                    return StyleRules.adding(p.kind, to: style)
                }
            },
            spec("style.remove", "Remove Layer Style", "Removes one style from the layer.", .edit, KindParams.self, kindOnly, shadow, can) { t, p in
                try edit(&t, "Remove Layer Style") { style in
                    var result = try having(p.kind, style, "style.remove"); result.effects.removeAll { $0.kind == p.kind }; return result
                }
            },
            spec("style.enable", "Turn Layer Style On or Off", "Turns one style on or off, keeping its settings.", .edit, EnableParams.self,
                 .object(["kind": kindSchema, "on": .boolean], required: ["kind", "on"]),
                 .object(["kind": .string("dropShadow"), "on": .bool(false)]), can) { t, p in
                try edit(&t, "Turn Layer Style On or Off") { changing(p.kind, in: try having(p.kind, $0, "style.enable")) { $0.isEnabled = p.on } }
            },
            spec("style.set", "Change Layer Style", "Changes one style's fields; one undo step per drag.", .edit, SetParams.self,
                 setSchema, .object(["kind": .string("dropShadow"), "distance": .number(8)]), can) { t, p in
                try edit(&t, "Change Layer Style", drag: p.drag) { try StyleRules.setting(p.patch, on: p.kind, in: try having(p.kind, $0, "style.set")) }
            },
            spec("style.fill-opacity", "Fill Opacity", "Sets the layer's own pixels' opacity; effects keep theirs.", .edit,
                 FillOpacityParams.self, .object(["value": .number("Fill opacity.", minimum: 0, maximum: 1), "drag": dragSchema],
                                                 required: ["value", "drag"]), .object(["value": .number(0.5)]), can) { t, p in
                try edit(&t, "Fill Opacity", drag: p.drag) { style in
                    var result = style; result.fillOpacity = p.value; return StyleRules.clamped(result)
                }
            },
            spec("style.preset", "Apply Style Preset", "Replaces the layer's style with a built-in preset.", .edit, PresetParams.self,
                 .object(["name": .string("The preset's name.", maxLength: 64)], required: ["name"]), .object(["name": .string("Lifted")]), can) { t, p in
                try edit(&t, "Apply Style Preset") { _ in
                    guard let preset = StyleRules.presets.first(where: { $0.name == p.name }) else {
                        throw CatalogError.unavailable(id: "style.preset", why: "There is no style preset named \(p.name).")
                    }
                    return preset.style
                }
            },
            spec("style.copy", "Copy Layer Style", "Returns the layer's style as JSON for style.paste.", .query, NoParams.self, .none,
                 .object([:]), needsStyle("This layer has no style to copy."), read),
            spec("style.paste", "Paste Layer Style", "Replaces the layer's style with a copied one; refuses a malformed one.", .edit,
                 PasteParams.self, .object(["style": styleSchema], required: ["style"]),
                 .object(["style": .object(["effects": .array([]), "fillOpacity": .number(1)])]), can) { t, p in
                try edit(&t, "Paste Layer Style") { _ in try pasted(p.style) }
            },
            spec("style.clear", "Clear Layer Style", "Removes every style and sets fill opacity back to 1.", .edit, NoParams.self, .none,
                 .object([:]), needsStyle("This layer has no style to clear.")) { t, _ in try edit(&t, "Clear Layer Style") { _ in .none } },
            spec("style.panel", "Layer Style…", "Opens the style panel at one section; with no kind, closes it or opens it at the first enabled style.",
                 .view, PanelParams.self, .object(["kind": .optional(kindSchema)], required: ["kind"]), .object([:]), can) { t, p in
                t.showStylePanel(p.kind ?? (t.stylePanel == nil ? defaultSection(t.styleSelection) : nil))
                return .object([:])
            },
        ]
    }
}
