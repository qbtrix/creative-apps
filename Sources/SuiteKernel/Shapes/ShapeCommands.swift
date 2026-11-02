// ShapeCommands.swift (shape-tools SH-1 specs, SH-6 bodies):
// the target an app adopts, the panel's option changes, and shape.draw and tool.shape.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FlareCore

/// A document the shape tool draws on: why it can't now ("Open a document first."), the tool's options,
/// picking them (view state), and adding one selected shape layer as one undo step named `name`.
public protocol ShapeTarget: Sendable {
    var shapeHelp: String? { get }
    var shapeTool: ShapeSpec { get }
    mutating func pickShapeTool(_ spec: ShapeSpec)
    mutating func addShape(_ spec: ShapeSpec, in box: Rect, name: String) throws -> String
}

/// One change the tool's options panel asks for.
public enum ShapeIntent: Hashable, Sendable {
    case kind(ShapeKind), sides(Int), points(Int), innerRatio(Double), cornerRadius(Double), head(Double)
    /// The options after the intent: the one option it names changed, the rest kept.
    public func applied(to spec: ShapeSpec) -> ShapeSpec {
        var spec = spec
        switch self {
        case .kind(let kind): spec.kind = kind
        case .sides(let sides): spec.sides = sides
        case .points(let points): spec.points = points
        case .innerRatio(let ratio): spec.innerRatio = ratio
        case .cornerRadius(let radius): spec.cornerRadius = radius
        case .head(let head): spec.head = head
        }
        return spec
    }

    /// tool.shape with the new option, naming the kind that owns it (a polygon's sides, a star's points and ratio,
    /// a rectangle's corner radius, an arrow's head), so the tool keeps every other option.
    public var command: (id: String, params: JSONValue) {
        let (kind, option): (ShapeKind, (String, JSONValue)?) = switch self {
        case .kind(let kind): (kind, nil)
        case .sides(let sides): (.polygon, ("sides", .number(Double(sides))))
        case .points(let points): (.star, ("points", .number(Double(points))))
        case .innerRatio(let ratio): (.star, ("innerRatio", .number(ratio)))
        case .cornerRadius(let radius): (.rectangle, ("cornerRadius", .number(radius)))
        case .head(let head): (.arrow, ("head", .number(head)))
        }
        var params: [String: JSONValue] = ["kind": .string(kind.rawValue)]
        if let option { params[option.0] = option.1 }
        return ("tool.shape", .object(params))
    }
}

public enum ShapeCommands {
    /// tool.shape's params, and with the box and line ends (fractions of the box) shape.draw's.
    struct Tool: Decodable, Sendable {
        var kind: ShapeKind, sides: Int?, points: Int?, innerRatio: Double?, cornerRadius: Double?, head: Double?
        /// `spec` with this kind and every option given here; the rest kept.
        func applied(to spec: ShapeSpec) -> ShapeSpec {
            var spec = spec
            spec.kind = kind
            (spec.sides, spec.points, spec.innerRatio) = (sides ?? spec.sides, points ?? spec.points, innerRatio ?? spec.innerRatio)
            (spec.cornerRadius, spec.head) = (cornerRadius ?? spec.cornerRadius, head ?? spec.head)
            return spec
        }
    }
    struct Draw: Decodable, Sendable {
        var kind: ShapeKind, x: Double, y: Double, w: Double, h: Double
        var sides: Int?, points: Int?, innerRatio: Double?, cornerRadius: Double?, head: Double?
        var x1: Double?, y1: Double?, x2: Double?, y2: Double?
        /// The kind's defaults with the given options and line ends, in the box from x, y, w and h.
        var spec: ShapeSpec {
            var spec = Tool(kind: kind, sides: sides, points: points, innerRatio: innerRatio, cornerRadius: cornerRadius, head: head)
                .applied(to: .defaults(kind))
            (spec.start, spec.end) = (Point(x: x1 ?? spec.start.x, y: y1 ?? spec.start.y), Point(x: x2 ?? spec.end.x, y: y2 ?? spec.end.y))
            return spec
        }
        var box: Rect { Rect(minX: x, minY: y, maxX: x + w, maxY: y + h) }
    }
    struct Drawn: Encodable { var id: String }

    static let options: [String: ParamSchema] = [
        "kind": .string("The shape.", oneOf: ShapeKind.allCases.map(\.rawValue)),
        "sides": .optional(.integer("A polygon's sides.")), "points": .optional(.integer("A star's points.")),
        "innerRatio": .optional(.number("A star's inner radius over its outer one.")),
        "cornerRadius": .optional(.number("A rectangle's corner radius, points.")),
        "head": .optional(.number("An arrow's head length, points.")),
    ]
    static let drawSchema = ParamSchema.object(options.merging([
        "x": .number(), "y": .number(), "w": .number(minimum: 0), "h": .number(minimum: 0),
        "x1": end("start's x"), "y1": end("start's y"), "x2": end("end's x"), "y2": end("end's y"),
    ]) { old, _ in old }, required: ["kind", "x", "y", "w", "h"])
    /// A line end on one axis: a fraction of the box, 0 at its left or top and 1 at its right or bottom, never pixels.
    static func end(_ what: String) -> ParamSchema {
        .optional(.number("A line's \(what), as a fraction of the box from 0 to 1.", minimum: 0, maximum: 1))
    }

    /// shape.draw (an edit, one undo step) and tool.shape (view state), both unavailable while `shapeHelp` is set.
    public static func specs<T: ShapeTarget>(_ target: T.Type) -> [CommandSpec<T>] {
        let open: @Sendable (T) -> Availability = { $0.shapeHelp.map(Availability.unavailable) ?? .available }
        return [
            .typed("shape.draw", title: "Draw Shape", summary: "Draws one shape of the given kind and options in a box, as one undo step.",
                   kind: .edit, params: Draw.self, schema: drawSchema, result: .object(["id": .string()], required: ["id"]),
                   example: .object(["kind": .string("star"), "x": .number(0), "y": .number(0), "w": .number(100), "h": .number(100)]),
                   availability: open) { (target: inout T, p: Draw) throws -> Drawn in
                let spec = p.spec
                if let help = ShapeRules.help(spec) { throw ShapeRefusal.invalid(help) }
                guard p.w > 0 || p.h > 0 else { throw ShapeRefusal.invalid("Draw a shape larger than nothing.") }
                return Drawn(id: try target.addShape(spec, in: p.box, name: "Draw \(spec.kind.rawValue.capitalized)"))
            },
            .typed("tool.shape", title: "Shape Tool", summary: "Picks the shape tool with the given kind and options.",
                   kind: .view, params: Tool.self, schema: .object(options, required: ["kind"]),
                   example: .object(["kind": .string("star"), "points": .number(5)]),
                   availability: open) { (target: inout T, p: Tool) throws -> JSONValue in
                let spec = p.applied(to: target.shapeTool)
                if let help = ShapeRules.help(spec) { throw ShapeRefusal.invalid(help) }
                target.pickShapeTool(spec)
                return .object([:])
            },
        ]
    }
}
