// StrokeCommands.swift (stroke-style SS-1 specs with real ids, schemas and availability; SS-6 bodies but dash and
// trim; SS-7 those two): the nine stroke commands every app registers with one line,
// `+ StrokeCommands.specs(<X>Workspace.self)`, and the stroke editor's gestures as those commands.
import FlareCore

/// A document the stroke commands run on: it reads the selection's stroke and sets it back as one undo step.
public protocol StrokeTarget: Sendable {
    /// Why nothing can be stroked now, in the app's words; nil when it can.
    var strokeHelp: String? { get }
    /// Why trim can't run (Design: "Trim paths are for animation, in Flare and Halo."); nil when it can.
    var trimHelp: String? { get }
    /// The primary selected layer's stroke; nil when it has none.
    var selectedStroke: VectorStroke? { get }
    /// Sets (nil removes) the stroke of every selected unlocked layer; one undo step named `name`;
    /// steps under one `drag` token fold into one.
    mutating func setStroke(_ stroke: VectorStroke?, name: String, drag: String?) throws
}

/// One gesture of the stroke editor; the app runs its `command` through its catalog.
public enum StrokeIntent: Hashable, Sendable {
    case add, remove, color(FillColor, drag: String?), width(Double, drag: String?)
    case join(StrokeJoin), cap(StrokeCap), dash(DashPreset, pattern: [Double]?)
    case trim(start: Double, end: Double, offset: Double, drag: String?)

    /// The editor's gesture as the command it is: its id and params (a custom pattern sends `pattern`, else `preset`).
    public var command: (id: String, params: JSONValue) {
        switch self {
        case .add: ("stroke.add", .object([:]))
        case .remove: ("stroke.remove", .object([:]))
        case .color(let c, let drag): ("stroke.color", Self.params(["r": .number(c.r), "g": .number(c.g), "b": .number(c.b), "a": .number(c.a)], drag))
        case .width(let width, let drag): ("stroke.width", Self.params(["width": .number(width)], drag))
        case .join(let join): ("stroke.join", .object(["join": .string(join.rawValue)]))
        case .cap(let cap): ("stroke.cap", .object(["cap": .string(cap.rawValue)]))
        case .dash(let preset, let pattern):
            ("stroke.dash", .object(pattern.map { ["pattern": .array($0.map(JSONValue.number))] } ?? ["preset": .string(preset.rawValue)]))
        case .trim(let start, let end, let offset, let drag):
            ("stroke.trim", Self.params(["start": .number(start), "end": .number(end), "offset": .number(offset)], drag))
        }
    }
    /// `fields` as an object, with `drag` when there is one.
    private static func params(_ fields: [String: JSONValue], _ drag: String?) -> JSONValue {
        .object(fields.merging(drag.map { ["drag": .string($0)] } ?? [:]) { old, _ in old })
    }
}

public enum StrokeCommands {
    // Each command's params, named for it (`stroke.read`, `stroke.add` and `stroke.remove` take none).
    struct Empty: Codable, Sendable {}
    struct ColorParams: Codable, Sendable { var r, g, b, a: Double; var drag: String? }
    struct WidthParams: Codable, Sendable { var width: Double; var drag: String? }
    struct JoinParams: Codable, Sendable { var join: StrokeJoin }
    struct CapParams: Codable, Sendable { var cap: StrokeCap }
    struct DashParams: Codable, Sendable { var preset: DashPreset?; var pattern: [Double]?; var phase: Double? }
    struct TrimParams: Codable, Sendable { var start, end: Double; var offset: Double?; var drag: String? }

    /// Why `stroke.add` can't run on a stroked layer, and why the rest need a stroke.
    static let strokedHelp = "The layer already has a stroke.", noStrokeHelp = "Add a stroke first."
    /// Why `stroke.dash` refuses its params.
    static let dashHelp = "Give a dash preset, or a pattern of at most 64 lengths of 0 or more with a positive sum."

    static let unit = ParamSchema.number("0 to 1.", minimum: 0, maximum: 1)
    static let drag = ParamSchema.optional(.string("A drag's token; edits under one token are one undo step.", maxLength: 64))
    static let rgba: [String: ParamSchema] = ["r": unit, "g": unit, "b": unit, "a": unit]
    static let width = ParamSchema.number("Points.", minimum: StrokeRules.widths.lowerBound, maximum: StrokeRules.widths.upperBound)
    static let join = ParamSchema.string("The corner join.", oneOf: StrokeJoin.allCases.map(\.rawValue))
    static let cap = ParamSchema.string("The end cap.", oneOf: StrokeCap.allCases.map(\.rawValue))
    static let pattern = ParamSchema.array(of: .number("Points.", minimum: 0), maxItems: StrokeRules.maxDashEntries)
    static let trim = ParamSchema.object(["start": unit, "end": unit, "offset": .number("Turns.")], required: ["start", "end", "offset"])
    static let read = ParamSchema.object(rgba.merging(["width": width, "join": join, "cap": cap, "dash": pattern,
                                                       "dashPhase": .number("Points."), "trim": .optional(trim)]) { old, _ in old },
                                         required: ["r", "g", "b", "a", "width", "join", "cap", "dash", "dashPhase", "trim"])

    /// The nine stroke commands on `target`, in menu order: `stroke.read` a query (null when the layer has no stroke),
    /// the rest edits of one undo step each.
    public static func specs<T: StrokeTarget>(_ target: T.Type) -> [CommandSpec<T>] {
        [
            .typed("stroke.read", title: "Read Stroke", summary: "Reads the selection's stroke: colour, width, join, cap, dash and trim; null when it has none.",
                   kind: .query, params: Empty.self, schema: .none, result: read,
                   example: .object([:]), availability: { ready($0) }) { t, _ in t.selectedStroke.map(reading) ?? .null },
            .typed("stroke.add", title: "Add Stroke", summary: "Gives the selection a 1 pt black stroke with a miter join and a butt cap.",
                   kind: .edit, params: Empty.self, schema: .none,
                   example: .object([:]), availability: { unstroked($0) }) { t, _ in try add(&t) },
            .typed("stroke.remove", title: "Remove Stroke", summary: "Removes the selection's stroke.",
                   kind: .edit, params: Empty.self, schema: .none,
                   example: .object([:]), availability: { stroked($0) }) { t, _ in try remove(&t) },
            .typed("stroke.color", title: "Stroke Color", summary: "Sets the stroke's colour; changes under one drag token are one undo step.",
                   kind: .edit, params: ColorParams.self,
                   schema: .object(rgba.merging(["drag": drag]) { old, _ in old }, required: ["r", "g", "b", "a", "drag"]),
                   example: .object(["r": .number(1), "g": .number(0), "b": .number(0), "a": .number(1)]),
                   availability: { stroked($0) }) { t, p in
                       try edit(&t, "stroke.color", "Stroke Color", drag: p.drag) { $0.color = FillColor(r: p.r, g: p.g, b: p.b, a: p.a) }
                   },
            .typed("stroke.width", title: "Stroke Width", summary: "Sets the stroke's width in points, 0 to 1000; a scrub under one drag token is one undo step.",
                   kind: .edit, params: WidthParams.self, schema: .object(["width": width, "drag": drag], required: ["width", "drag"]),
                   example: .object(["width": .number(4)]), availability: { stroked($0) }) { t, p in
                       try edit(&t, "stroke.width", "Stroke Width", drag: p.drag) { $0.width = StrokeRules.clampedWidth(p.width) }
                   },
            .typed("stroke.join", title: "Stroke Join", summary: "Sets how the stroke's corners meet: miter, round or bevel.",
                   kind: .edit, params: JoinParams.self, schema: .object(["join": join], required: ["join"]),
                   example: .object(["join": .string("round")]), availability: { stroked($0) }) { t, p in
                       try edit(&t, "stroke.join", "Stroke Join") { $0.join = p.join }
                   },
            .typed("stroke.cap", title: "Stroke Cap", summary: "Sets how the stroke's open ends finish: butt, round or square.",
                   kind: .edit, params: CapParams.self, schema: .object(["cap": cap], required: ["cap"]),
                   example: .object(["cap": .string("round")]), availability: { stroked($0) }) { t, p in
                       try edit(&t, "stroke.cap", "Stroke Cap") { $0.cap = p.cap }
                   },
            .typed("stroke.dash", title: "Stroke Dash", summary: "Dashes the stroke with a preset scaled by its width, or a pattern and phase in points.",
                   kind: .edit, params: DashParams.self,
                   schema: .object(["preset": .optional(.string("The dash preset.", oneOf: DashPreset.allCases.map(\.rawValue))),
                                    "pattern": .optional(pattern), "phase": .optional(.number("Points."))],
                                   required: ["preset", "pattern", "phase"]),
                   example: .object(["preset": .string("dashed")]), availability: { stroked($0) }) { t, p in try dash(&t, p) },
            .typed("stroke.trim", title: "Trim Path", summary: "Trims the stroke to start and end fractions, turned by an offset in turns; a scrub under one drag token is one undo step.",
                   kind: .edit, params: TrimParams.self,
                   schema: .object(["start": unit, "end": unit, "offset": .optional(.number("Turns.")), "drag": drag],
                                   required: ["start", "end", "offset", "drag"]),
                   example: .object(["start": .number(0), "end": .number(0.5)]),
                   availability: { trimmable($0) }) { t, p in
                       try edit(&t, "stroke.trim", "Trim Path", drag: p.drag) { stroke in
                           let mode = stroke.trim?.mode ?? .together
                           stroke.trim = StrokeTrim(start: p.start, end: p.end, offset: p.offset ?? stroke.trim?.offset ?? 0, mode: mode)
                       }
                   },
        ]
    }

    /// Available when the target can be stroked; else its `strokeHelp`.
    static func ready<T: StrokeTarget>(_ target: T) -> Availability {
        target.strokeHelp.map { .unavailable($0) } ?? .available
    }
    /// `ready`, and the selection has no stroke yet.
    static func unstroked<T: StrokeTarget>(_ target: T) -> Availability {
        guard ready(target) == .available else { return ready(target) }
        return target.selectedStroke == nil ? .available : .unavailable(strokedHelp)
    }
    /// `ready`, and the selection has a stroke.
    static func stroked<T: StrokeTarget>(_ target: T) -> Availability {
        guard ready(target) == .available else { return ready(target) }
        return target.selectedStroke == nil ? .unavailable(noStrokeHelp) : .available
    }
    /// `ready`, no `trimHelp`, and the selection has a stroke.
    static func trimmable<T: StrokeTarget>(_ target: T) -> Availability {
        guard ready(target) == .available else { return ready(target) }
        if let why = target.trimHelp { return .unavailable(why) }
        return stroked(target)
    }
    /// `stroke.dash`: a pattern and phase in points as given, else the preset's pattern at the stroke's width (a dotted
    /// preset also rounds the cap, since a zero dash with a butt cap draws nothing), one step named "Stroke Dash". The
    /// phase stays unless given; a solid stroke drops it.
    static func dash<T: StrokeTarget>(_ target: inout T, _ p: DashParams) throws -> JSONValue {
        guard p.pattern != nil || (p.preset != nil && p.preset != .custom),
              StrokeRules.isValidPattern(p.pattern ?? []) else { throw CatalogError.failed(id: "stroke.dash", message: dashHelp) }
        return try edit(&target, "stroke.dash", "Stroke Dash") { stroke in
            let preset = p.preset ?? .custom
            stroke.dash = p.pattern ?? StrokeRules.pattern(preset, width: stroke.width)
            stroke.dashPhase = stroke.dash.isEmpty ? 0 : p.phase ?? stroke.dashPhase
            if p.pattern == nil, preset == .dotted { stroke.cap = .round }
        }
    }
    /// `stroke.add`: a 1 pt black stroke with a miter join and a butt cap, one step named "Add Stroke".
    static func add<T: StrokeTarget>(_ target: inout T) throws -> JSONValue {
        let stroke = VectorStroke()
        try target.setStroke(stroke, name: "Add Stroke", drag: nil)
        return reading(stroke)
    }
    /// `stroke.remove`: clears the selection's stroke, one step named "Remove Stroke".
    static func remove<T: StrokeTarget>(_ target: inout T) throws -> JSONValue {
        guard target.selectedStroke != nil else { throw CatalogError.failed(id: "stroke.remove", message: noStrokeHelp) }
        try target.setStroke(nil, name: "Remove Stroke", drag: nil)
        return .null
    }
    /// Reads the selection's stroke, applies `change` and hands it back once as one undo step named `name`, `drag`
    /// passed through so a scrub folds into one step; returns the new stroke as `stroke.read` reports it.
    static func edit<T: StrokeTarget>(_ target: inout T, _ id: String, _ name: String, drag: String? = nil,
                                      _ change: (inout VectorStroke) -> Void) throws -> JSONValue {
        guard var stroke = target.selectedStroke else { throw CatalogError.failed(id: id, message: noStrokeHelp) }
        change(&stroke)
        try target.setStroke(stroke, name: name, drag: drag)
        return reading(stroke)
    }
    /// `stroke` as `stroke.read` reports it: colour, width, join, cap, the dash and the trim (null when none).
    static func reading(_ stroke: VectorStroke) -> JSONValue {
        let (pattern, phase) = StrokeRules.dash(of: stroke)
        let trim = StrokeRules.trim(of: stroke).map {
            JSONValue.object(["start": .number($0.start), "end": .number($0.end), "offset": .number($0.offset)])
        }
        return .object(["r": .number(stroke.color.r), "g": .number(stroke.color.g), "b": .number(stroke.color.b),
                        "a": .number(stroke.color.a), "width": .number(stroke.width), "join": .string(stroke.join.rawValue),
                        "cap": .string(stroke.cap.rawValue), "dash": .array(pattern.map(JSONValue.number)),
                        "dashPhase": .number(phase), "trim": trim ?? .null])
    }
}
